---
name: lightroom
description: Lightroom Classic catalog analysis, gap detection, import workflow, and NAS photo library management for Doug's photo collection
metadata:
  type: skill
---

# Lightroom Classic — Photo Library Management

## How Lightroom Classic actually works — reference (READ BEFORE GUIDING)

Doug is new to Lightroom Classic — give exact menu paths and dialog wording, never guess at UI options. These files are Adobe-User-Guide-grounded (with sources + `[inferred]` flags). Load the relevant one before answering a "where/how do I…" question:

| File | Covers |
|---|---|
| [reference/catalog-and-import.md](reference/catalog-and-import.md) | What the `.lrcat` is, helper files, backups; the Import window (Add/Copy/Move, Include Subfolders, Build Previews, **Don't Import Suspected Duplicates** = filename+capture-time+size); how LR skips already-cataloged files; NAS import caveats |
| [reference/folders-and-disk.md](reference/folders-and-disk.md) | Folders panel ↔ disk; **moving/renaming folders & dragging photos MOVE files on disk**; Remove vs Delete; Synchronize Folder; Find Missing Folder/Photos & relinking; volume status LED |
| [reference/remove-delete-duplicates.md](reference/remove-delete-duplicates.md) | **Remove (catalog only) vs Delete from Disk**; the delete dialog by context; collection-delete = un-collect; **NAS "Delete from Disk" is an Adobe-acknowledged failure** (→ remove in LR, delete on NAS via SSH); no built-in dup finder; Teekesselchen |
| [reference/library-module.md](reference/library-module.md) | Modules/views; flags/ratings/labels; **Folders vs Collections**; Smart/Quick/Target collections; Library Filter bar; active-photo selection model; full keyboard-shortcut tables |
| [reference/metadata-keywords-map.md](reference/metadata-keywords-map.md) | Metadata panel; Edit Capture Time; Save/Read Metadata; XMP sidecar vs embedded; hierarchical keywords stored as **`lr:hierarchicalSubject` with `\|` separator**; keyword list import/export; Map module GPS & tracklog |
| [reference/photosweeper-dedup.md](reference/photosweeper-dedup.md) | PhotoSweeper 5.5.3 ↔ LR: **LR must be CLOSED**; Similar Photos→Bitmaps catches same-image-different-name; Auto Mark keep-highest-res; marks return as **Reject flag + `Trash (PhotoSweeper)` collection**; safe Remove-from-catalog-only workflow |

## Key Facts

- **Catalog:** `~/Pictures/Lightroom/Lightroom Catalog.lrcat` (SQLite). Photo count is **live state — query it, don't trust a hard-coded number** (was 68,879; ~102,686 after the 2026-06 big import; will shrink again after PhotoSweeper dedup). **Current project status lives in the repo `infrastructure/photos/HANDOFF.md`** — read it at session start.
- **NAS share:** `192.168.20.16` — Mac mount `/Volumes/Home Files/`, SSH path `/volume1/Home Files/`
- **Pictures root on NAS:** `/volume1/Home Files/Data/Pictures/`
- **exiftool:** `/usr/local/bin/exiftool`
- **Metadata tool:** `/Users/doug/photo_tools/photo_date_fixer.py`

## NAS Folder Structure

The roots under `Pictures/`: `Family/`, `DSN/`, `XTL/`, `TBG/`, `KBL/`, `KBLP/`, `ApplePhotos-export/`, `DSII/`, `RAID-rescue/` (recovered-from-failed-RAID, multiple sub-roots incl. rescue `.aplibrary` bundles), `Exported Pictures/`, `LightroomImport/` (symlink bridge — see below), `Libraries/` (the original `.aplibrary`/`.photolibrary` archive bundles), plus `Data/PhotoReorg/` as a sibling of `Pictures/` (scratch/reorg area, incl. `not imported to lightroom/`).

> Per-folder catalog counts change with every import/dedup — they're **live state**, query the catalog (or see repo `HANDOFF.md`) rather than trusting numbers here.

## LightroomImport/ — symlink bridge into the bundles (NOT copies)

As of 2026-06, `LightroomImport/`'s big subfolders are **symlinks** pointing into each archive bundle's `Masters/` dir, e.g. `LightroomImport/Aperture Library 1 → Libraries/Aperture/Aperture Library 1.aplibrary/Masters`. They exist so Lightroom can import the bundle originals (macOS treats `.aplibrary` as an opaque package; the symlink exposes just the Masters). Real (non-symlink) contents: `iPhotoOld/`, `iPhotoOld-videos-unreadable/`, `recovered-videos/`.

**Operational rules this implies:**
- **Any disk scan of `LightroomImport/` or the bundles must follow symlinks** (`os.walk(..., followlinks=True)`, `find -L`) or it misses ~54k files.
- **Compare paths case-insensitively** — the catalog stores ~24k bundle paths with different case than disk (`.CR2` vs `.cr2`); exact-string matching false-flags them all as "missing".
- **Never point Lightroom Import at `Libraries/` directly** (~800k preview/thumbnail internals) **or at any folder containing `.aplibrary` bundles** (e.g. `RAID-rescue/`) — over SMB, macOS often fails to treat the package as opaque, so LR crawls the internals and stalls on "indexing". Import bundle content **only via the `LightroomImport/` symlinks-to-`Masters`**.
- The historical "deduped orphan copies" model is obsolete — the duplicates now live inside the bundles, reached via symlink, and are handled by the import-all → PhotoSweeper-dedup workflow (see repo `HANDOFF.md`).

## Catalog SQLite Schema

```sql
-- Full path query
SELECT rf.absolutePath || fold.pathFromRoot || lf.baseName || '.' || lf.extension AS full_path
FROM Adobe_images img
JOIN AgLibraryFile lf ON lf.id_local = img.rootFile
JOIN AgLibraryFolder fold ON fold.id_local = lf.folder
JOIN AgLibraryRootFolder rf ON rf.id_local = fold.rootFolder

-- With EXIF and GPS
SELECT img.id_local, img.captureTime,
       exif.hasGPS, exif.gpsLatitude, exif.gpsLongitude,
       cam.value AS camera,
       rf.absolutePath || fold.pathFromRoot || lf.baseName || '.' || lf.extension AS full_path
FROM Adobe_images img
JOIN AgHarvestedExifMetadata exif ON exif.image = img.id_local
JOIN AgLibraryFile lf ON lf.id_local = img.rootFile
JOIN AgLibraryFolder fold ON fold.id_local = lf.folder
JOIN AgLibraryRootFolder rf ON rf.id_local = fold.rootFolder
LEFT JOIN AgInternedExifCameraModel cam ON cam.id_local = exif.cameraModelRef
```

Open catalog read-only: `sqlite3.connect("file:path?mode=ro", uri=True)`

## Gap Detection Pattern

To find disk files not in catalog (or deduped to different path):

```python
import sqlite3
from collections import defaultdict

conn = sqlite3.connect(f"file:{catalog}?mode=ro", uri=True)
rows = conn.execute("SELECT lf.baseName||'.'||lf.extension, rf.absolutePath||fold.pathFromRoot||lf.baseName||'.'||lf.extension FROM AgLibraryFile lf JOIN AgLibraryFolder fold ON fold.id_local=lf.folder JOIN AgLibraryRootFolder rf ON rf.id_local=fold.rootFolder").fetchall()

# by_name: lowercase filename → [catalog paths]
by_name = defaultdict(list)
for fname, path in rows:
    by_name[fname.lower()].append(path)

# For each disk file:
#   fname not in by_name → never imported
#   fname in by_name but no path contains this folder → deduped elsewhere
#   fname in by_name and path contains this folder → correctly cataloged
```

## .aplibrary Bundle Structure

Aperture libraries store originals at `Masters/YYYY/MM/DD/YYYYMMDD-HHMMSS/filename`. The timestamp folder is Aperture-internal, not meaningful. Reach a bundle's Masters via its `LightroomImport/` **symlink** (the catalog references these symlink paths), not the `Libraries/` path directly.

| Bundle (under `Libraries/Aperture/`) | `LightroomImport/` symlink |
|---|---|
| Aperture Library 1.aplibrary | LightroomImport/Aperture Library 1/ |
| Aperture Library.aplibrary | LightroomImport/Aperture Library/ |
| 30YearTrip.aplibrary | LightroomImport/30YearTrip/ |
| KBLPhotography.aplibrary | LightroomImport/KBLPhotography/ |

**Key:** macOS treats `.aplibrary`/`.photolibrary` as opaque packages — access contents via SSH to the NAS (with `followlinks`/`find -L`), not via the SMB mount from the Mac.

## Import Workflow

**Always use Add (not Copy or Move)** — keeps files in place, creates catalog entries mirroring disk structure.

File → Import → navigate to folder → select Add → check Include Subfolders → Import

LR skips files already in catalog automatically. Safe to re-run on a folder.

After import: Metadata → Read Metadata from Files to pick up any EXIF written externally.

For the bulk Phase-1 import specifics (dup-detection OFF, Build Previews Minimal, only via `LightroomImport/` symlinks, never `Libraries/`), see the Phase 1 strategy below and `reference/catalog-and-import.md`.

## Phase 1 strategy — import everything, then dedup in the catalog

⚠️ The old "generate a disk-orphan delete list and delete orphans first" plan is **obsolete** — it predated the symlink restructure and relied on Lightroom's unreliable NAS Delete-from-Disk. **Current approach (full sequence + status in repo `HANDOFF.md`):**

1. **Import everything uncataloged** — Add, Include Subfolders, **dup-detection OFF**, **Build Previews: Minimal**; bundles via the `LightroomImport/` symlinks + the organized roots; **never `Libraries/`** or any `.aplibrary` folder (see operational rules above).
2. **PhotoSweeper** content-dedup *in the catalog* (LR closed), keep highest-res; it marks rejects as the **Reject flag + `Trash (PhotoSweeper)` collection** (`reference/photosweeper-dedup.md`).
3. In LR, **Remove from Catalog only**, selecting from **All Photographs** — **never Delete from Disk** on NAS files (Adobe-acknowledged failure; `reference/remove-delete-duplicates.md`).
4. **Reorganize into year/month via the Folders panel** (moves files on disk + keeps the catalog linked; `reference/folders-and-disk.md`), then **one bulk disk cleanup at the very end via SSH on the NAS** — never per-file from Lightroom.

Reusable tooling lives in the repo: `orphan_audit.py` (disk→catalog), `missing_photo_audit.py` (catalog→disk), `pull_not_imported.py`, `triage.py`. Always compare paths **case-insensitively** and **follow symlinks**.

## Collection Hierarchy (planned keywords)

Target `lr:HierarchicalSubject` structure using `|` separator in XMP:

```
Family|Curran
Family|Kimmerly
Family|Frith
Family|Greg&Deb
Family|Doug&Maggie|Trips
Family|Doug&Maggie|Anniversary
XTL|Events / Office / Staff / Trucks / Facilities
DSN|Events / Office / Staff / Warehouse / No Limits
TBG|Events / Jobs
KBL|Ideas / Marketing / Products
KBLP|Events
```

## Path Mapping

| Context | Path prefix |
|---|---|
| Mac SMB mount | `/Volumes/Home Files/Data/Pictures/` |
| NAS SSH | `/volume1/Home Files/Data/Pictures/` |
| Lightroom catalog | `/Volumes/Home Files/Data/Pictures/` |

SMB mount can drop — run heavy file operations via SSH on NAS to avoid connection kills.

## Performance: LrC background tasks pin the NAS over SMB

LrC's background jobs — **preview/Smart-Preview builds and face detection (People)** — read the NAS-referenced *masters* over SMB in a read-batch → local-compute cycle. During a big run (e.g. after the 2026-06 Aperture import) this keeps **one NAS `smbd` worker churning for hours/days** and presents to everyone else as **"the whole NAS is slow"** — not as an LR stall. Confirmed culprit of the 2026-06-08 NAS-slowness incident; LrC was at 600%+ CPU locally while a single boat-side smbd worker accumulated 22 h of CPU.

- Diagnose from the **Mac**: `ps aux | grep -i lightroom` (one proc at several-hundred-%), `lsof -p <pid> | grep /Volumes` (dips in/out of the share).
- Diagnose from the **NAS / operator side**: see the `homelab-synology` skill → *"Troubleshooting: the NAS is slow"* (the `netstat :445` → `/proc/PID/fd` → client-IP → Mac `lsof` chain).
- **Don't** kill the NAS smbd worker for relief — it wedges the Mac's smbfs mount (Finder won't start). Instead pause the LrC task, or `umount -f` + remount on the Mac if already wedged.
- Reduce impact: let the task finish, pause it via the activity indicator (top-left in LrC), or turn off auto face-detection (Catalog Settings → Metadata). Smart Previews are local once built, so culling/editing then won't hit the NAS.
