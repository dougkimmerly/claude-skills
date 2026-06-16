# PhotoSweeper × Lightroom Classic — Catalog Dedup

PhotoSweeper by Overmacs (overmacs.com) — the macOS duplicate finder this project uses to dedup the Lightroom catalog **without deleting files from disk**. Use ACTUAL feature names; documentation gaps flagged.

## Version & product family
- **Current: PhotoSweeper 5.5.3** (Mac App Store, updated May 2026; macOS **10.15+**; ~$14.99). Universal/Apple-Silicon native, ready for macOS Tahoe 26.
- **PhotoSweeper** (full app — the one to use; App Store id463362050 or direct from overmacs.com) finds exact dups **and** visually similar photos; integrates with Apple Photos, **Lightroom Classic**, Capture One.
- **PhotoSweeper Lite** (id506150103) = exact duplicates only, no similar-photo detection — not enough here.
- "PhotoSweeper X" = old branding (same lineage). "PhotoSweep" (no -er) = unrelated/legacy.
- Recent Lightroom-relevant changes: **5.3** enhanced LR Classic integration + NAS perf; **5.4** AI Quality Score + smarter Auto Mark ("keep one per group" / "mark only worse"); **5.5** reads XMP sidecars, better LR preview handling, **option to ignore already-rejected photos on import** (useful for re-runs).

## How it reads the catalog
- Add the Lightroom catalog as a source: open the **Media Browser** (toolbar) → **+** → select the Lightroom library/catalog → **drag** the photos/folders to compare into the comparison area. You can scope to specific LR folders.
- ⚠️ **Lightroom must be CLOSED** during the run — PhotoSweeper reads/writes the catalog's SQLite DB directly and LR locks it while open ("Lightroom application must be closed until removal is finished"). **Back up the `.lrcat` first** (it edits in place).
- ⚠️ **A re-run can silently exclude a previous run's marked photos.** PhotoSweeper 5.5 has a documented **"ignore rejected Adobe Lightroom photos" import option** that keys on the **Reject flag**; there is no *documented* collection-based exclusion. Observed 2026-06: a fresh full re-import came in at `catalog_count − trash_collection_count`, and **un-flagging alone did not re-include them** (whether the lever is the flag, the collection, or import-timing is ambiguous). **Reliable reset for a clean re-run: un-flag the rejects AND empty the `Trash (PhotoSweeper)` collection, then re-import with Lightroom closed.** Note re-import is the *whole* catalog again (can take hours over a NAS).
- It analyzes actual image **bitmaps** (reads originals / LR previews), not just file attributes.
- NAS note: Overmacs docs don't specifically cover network-hosted *catalogs*; Doug's `.lrcat` is **local** (fine). Ensure the **NAS is mounted** so originals are readable during the scan.

## Comparison modes
| Mode | Finds |
|---|---|
| **Duplicate Files** | byte-identical files only (exact/checksum) |
| **Similar Photos** | visually similar via **Bitmaps** (pixel) or **Histograms** (tone) methods — **the mode that catches same image as RAW-vs-JPEG, renamed, or different resolution** |
| **Series of Shots / Time Interval** | burst grouping by capture-time gaps |
- Combine with **Time** (Time+Bitmap, Time+Histogram).
- **Matching Level** slider tunes strictness and **regroups on the fly** (no re-scan). Advanced: bitmap size (16×16 coarse → 128×128 fine), RGB/Grayscale, preprocessing (none/blur), color sensitivity.
- **For this project use Similar Photos → Bitmaps** to catch the Aperture-migration copies that differ by path/format/resolution.
- Review modes (not matching engines): "One by One", "Face to Face", "All in One".

## Marking — choosing the keeper
- Each duplicate group keeps one photo and **Marks** the rest. **Auto Mark** marks all-but-one per group using an **ordered, checkbox rule list in Preferences/Settings → Auto Mark** (drag to reorder, uncheck to skip).
- Confirmed prioritizable criteria: **resolution / image dimensions, file size, RAW vs non-RAW, star rating, creation date (earlier/later), DPI/density, source-library precedence**, and (5.4+) **AI Quality Score**. 5.4+ modes: "keep one per group" vs "mark only worse photos".
- **To keep highest resolution / prefer RAW:** drag the resolution/image-size (and format-preference) rule to the **top** of the Auto Mark list so the largest-dimension RAW master is the keeper and smaller JPEGs get marked.
- ⚠️ **Doc gap:** Overmacs doesn't publish the verbatim Auto Mark rule labels — **confirm the exact "keep highest resolution / prefer RAW" wording in the app's Preferences → Auto Mark** before relying on it.

## ⭐ What it sends back to Lightroom (the load-bearing part)
When the source is Lightroom and you press **Trash Marked**, PhotoSweeper does **NOT delete files**. It edits the catalog so marked photos are easy to find:
1. Sets the **Reject flag** (the `X` flag) on every marked photo, and
2. Gathers them into a new Lightroom collection named **`Trash (PhotoSweeper)`**.
(Manual: marked photos are "moved to the collection named 'Trash (PhotoSweeper)' and are also marked as Rejected.") It does **not** use a color label or keyword (those are undocumented — confirm in-app if needed). Changes appear when you reopen LR.
- **Undo:** select the `Trash (PhotoSweeper)` collection, press **U** to unflag, delete the collection.

## ✅ Safe catalog-dedup workflow (keep all files on disk)
1. **Quit Lightroom Classic.**
2. **Back up the `.lrcat`.**
3. PhotoSweeper: **Media Browser → + → add the Lightroom catalog → drag photos in.**
4. Scan mode **Similar Photos → Bitmaps** (tight Matching Level; loosen only to catch edits). Optionally also **Duplicate Files** for byte-identical.
5. **Preferences → Auto Mark:** move **resolution/image-size** (and RAW-preference) to the top → click **Auto Mark** → review groups, adjust marks by hand.
6. **Trash Marked** → PhotoSweeper sets **Reject** + adds to **`Trash (PhotoSweeper)`**. No files deleted.
7. **Reopen Lightroom.** Open the `Trash (PhotoSweeper)` collection; verify each keeper still exists.
8. **Remove from catalog only:** select the photos **from All Photographs** (NOT from inside the collection — deleting inside a collection just un-collects them), then **Photo > Remove Photos** / Delete Rejected → choose **Remove** (NOT "Delete from Disk").
9. Optionally delete the empty `Trash (PhotoSweeper)` collection.

This dedups the **catalog**; disk copies remain and are reconciled separately (Phase 3 bulk cleanup on the NAS).

## Reading PhotoSweeper's session / recovering pairs (advanced)

PhotoSweeper (App Store build) is **sandboxed** — its working data lives in its container:

- **Session library:** `~/Library/Containers/com.overmacs.photosweeper/Data/Library/Application Support/PhotoSweeper/Session/Library.pslib` — a **SQLite database** (copy it first, query read-only). Tables:
  - `PSFile` — `fileID`, **`filePath`** (full path), `fileName`, `fileType`, `fileSize`, `fileLabel` (=color label), `fileFlags`, `parentLibraryItemID` (**unique per file → maps to the LR item, NOT a group**), `aestheticScore`.
  - `PSFileInfo` — rich per-file: `width`/`height`, `dateTimeOriginal`, `rating`, **`keywords`**, **`GPSLatitude`/`GPSLongitude`/`…Ref`**, camera fields, `duration`/`frameRate` (video).
  - `PSFolder`, `PSLibrary`, `PSAdminData` (just a schema `version`).
- **Run history:** `…/Application Support/PhotoSweeper/Statistics.plist` → `PSSessions` array, each with `Freed<Source>ImageCount`/`Size` (e.g. `FreedLightroomImageCount`) + start/end dates — use to see how many each run trashed (e.g. a filename run vs a like-pics run).
- `folderBookmark`/`libraryBookmark` are security-scoped-bookmark BLOBs (sandbox), not plain paths.

⚠️ **The duplicate GROUPS are NEVER persisted to disk — at ANY stage — and cannot be extracted from PhotoSweeper.** Verified via the manual + Mach-O symbol inspection of `/Applications/PhotoSweeper.app`: grouping is a purely in-memory runtime model (`MCCompareGroup`/`MCGroup`/`MCGroupItem`); marks are in-memory too (`isMarked`/`markedItems`/`numberOfKeptItems`). The Session `Library.pslib` stores only the **file list + security-scoped bookmarks + cached reduced bitmaps** — **no group/cluster/match column, no join table, no blob**; `fileFlags`/`fileLabel` carry no documented mark-group semantics. "Restore Last Session" **re-derives** groups from the cached bitmaps, it does not read stored groups. There is **no saveable document, no export/report/CSV, no AppleScript dictionary (no `.sdef`, no `NSAppleScriptEnabled`), no CLI.** Conclusion: you cannot read keeper↔reject pairings out of PhotoSweeper — not even from a live, post-compare, pre-trash session. (Don't waste a run trying.)
- **The only durable artifact of a run is the Lightroom side:** the `Trash (PhotoSweeper)` collection + Reject flag = the **to-delete SET**, NOT the group-by-group pairing.
- **To pair reject→keeper (e.g. for metadata transfer), reconstruct from the LR catalog** by `captureTime` + filename stem (+ dimensions / content hash). Division of labour: **PhotoSweeper does the perceptual dedup; the catalog gives the pairs.** The LR `Trash (PhotoSweeper)` collection = the latest run's rejects.

**Transferring a reject's metadata to its keeper** (e.g. GPS the keeper lacks because a higher-res raw was kept over a GPS-tagged JPEG): write to the keeper's XMP sidecar with exiftool, then LR **Metadata → Read Metadata from File**. **GPS gotcha:** use plain `-GPSLatitude=<abs> -GPSLatitudeRef=N|S -GPSLongitude=<abs> -GPSLongitudeRef=E|W` — **NOT** `-XMP-exif:GPSLatitudeRef=…` (that Ref sub-tag doesn't exist in XMP → exiftool silently drops the hemisphere and writes the wrong sign).

## Sources
overmacs.com (homepage, manual PDF, ?p=releasenotes); Mac App Store id463362050 / id506150103; cisdem.com & northlight-images.co.uk & macworld reviews; lightroomqueen.com (undo Trash (PhotoSweeper)); jkost.com (Remove vs Delete).
