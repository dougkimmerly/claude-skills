# Lightroom Classic — Catalogs & Importing

Adobe Lightroom Classic (desktop catalog app, NOT Lightroom CC/cloud). Sourced from Adobe's official User Guide (helpx.adobe.com). Items not verbatim from Adobe are marked **[inferred]**.

## The catalog (.lrcat)

- A catalog is a **SQLite database** of records, one per photo. Importing **links** a file to its catalog record. All work (keywords, edits, ratings, collections, GPS) is stored as metadata in the catalog — **originals are never stored in or modified by the catalog** (editing is non-destructive).
- **Previews persist offline:** because the catalog stores previews, you can browse photos whose source files are currently unreachable (offline drive / dropped NAS mount). Only low-res previews show until the volume returns.
- Deleting the catalog erases catalog-only work and previews but does **not** delete originals.
- Default location: macOS `/Users/[user]/Pictures/Lightroom`. **Keep the .lrcat on fast LOCAL storage** — Adobe discourages hosting the working catalog on a network volume (and the `.lrcat.lock` prevents concurrent access). Originals on a NAS are fine; the catalog itself should be local. (Doug's catalog is local at `~/Pictures/Lightroom/` — correct.)

### Catalog helper files (move together if relocating a catalog)
| File | Purpose |
|---|---|
| `[name].lrcat` | the database |
| `[name].lrcat-data` | companion data (newer versions) |
| `[name] Previews.lrdata` | standard preview cache |
| `[name] Smart Previews.lrdata` | smart preview cache (if built) |
| `[name].lrcat.lock` | in-use lock ("already opened" error) |
| `[name].lrcat-journal` | journal for incomplete records |
| `[name].lrcat-wal` | SQLite write-ahead log **[inferred — not named in Adobe's file-locations doc]** |

### Catalog menu paths
- Open another catalog: **File > Open Catalog…** (LR closes current and relaunches). Recent: **File > Open Recent**. New: **File > New Catalog…**
- Backups: **Lightroom Classic > Catalog Settings > Backups** (Mac) / **Edit > Catalog Settings > Backups** (Win). Schedule options: *Once a day/week/month when exiting*, *Next time exits* (then reverts to Never), *Every time exits*, *Never (Not recommended)*. Backups run **on exit** and back up the **catalog only, not originals**.

## The Import window

Open via the **Import** button (Library module) or **File > Import Photos and Video…** (shortcut **Cmd+Shift+I** **[inferred — verify in-app; menu shows the binding]**). Work left → right: **Source** (left) → **import method** (top center) → **destination & options** (right panels: File Handling, File Renaming, Apply During Import).

### Import method (top center) — exact behavior
| Method | Behavior | Files moved/copied? |
|---|---|---|
| **Add** | Keeps files in their current location; creates a catalog reference only | **Leaves files in place** |
| **Copy** | Copies files (incl. sidecars) to a chosen folder | Copies; originals remain |
| **Move** | Moves files (incl. sidecars) to a chosen folder; removes from source | Moves; source deleted |
| **Copy as DNG** | Copies to a chosen folder, converting raw → DNG | Copies; originals remain |

- **Add and Move are unavailable when importing from a camera/card** (must Copy or Copy as DNG).
- **This project uses Add** — it never moves or copies on disk.

### Source panel
- **Include Subfolders** — brings in photos from nested subfolders.
- Only **checked** photos import; selected photos show a light-gray border.
- Network/NAS source: **Select A Source > Other Source…**; on Windows, **+ > Add Network Volume**.

### File Handling panel
- **Build Previews:** *Minimal* (camera embedded JPEGs — fastest import, slow later) / *Embedded & Sidecar* (larger embedded previews — fast, replaced later) / *Standard* (Adobe RGB, the "Fit" view — slower import) / *1:1* (100% pixels — slowest import, biggest cache, also builds minimal+standard).
- **Build Smart Previews** — lossy-DNG-based; lets you edit when originals are offline.
- **Don't Import Suspected Duplicates** — flags a file as already-in-catalog only if it matches an existing photo on **ALL THREE**: same **original filename** + same **EXIF capture date/time** + same **file size**. Will NOT catch the same image under a different filename, re-exported/re-compressed copies, or edited-capture-time files. *(For the import-all strategy this is turned OFF.)*
- **Make a Second Copy To** — backup copy of imports.
- **Add to Collection** — add imports to an existing/new collection.

### Apply During Import
- **Develop Settings** (preset), **Metadata** (preset, e.g. copyright), **Keywords** (comma-separated, applied to all imports).

### File Renaming
- Only for Copy/Move/Copy as DNG (renames files written to the destination). Not for Add. **[partially inferred]**

## How LR decides a file is "already in the catalog"
1. **On Add: by path.** A file at a path already having a catalog record is skipped. Re-running **Add** over the same folder is safe — already-cataloged files skip automatically.
2. **"Don't Import Suspected Duplicates"** is a separate content check (filename + capture time + size) for the same image arriving from a different path.

## NAS / network import caveats
- Importing from a networked drive is supported. **Offline volume = previews only** (no editing).
- Links break if the volume goes offline or its mount/drive-letter changes. A missing folder shows **grayed-out with a "?" icon** → right-click > **Find Missing Folder**. Single missing photos show a **"!" badge**. If the mount path is identical on reconnect, no relink needed (SMB drops self-heal).

## Sources
helpx.adobe.com/lightroom-classic: lightroom-catalog-basics, kb/catalog-faq-lightroom, create-catalogs, back-catalog, kb/preference-file-and-other-file-locations, photo-video-import-options, importing-photos-lightroom-basic-workflow, import-photos-video-catalog, lightroom-smart-previews, locate-missing-photos, kb/optimize-performance-lightroom.
