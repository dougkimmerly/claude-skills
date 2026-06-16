# Editing the Lightroom catalog directly (SQLite) + dedup execution

The `.lrcat` is plain SQLite. PhotoSweeper and our metadata-rescue work edit it directly. Direct writes bypass Lightroom's processing, so **some things display and some don't** — know which.

## Safety rules (ALWAYS)
- **Lightroom MUST be fully quit** before any write — it locks the catalog / uses WAL, and an open LR will overwrite your edits. Verify: `pgrep -il lightroom`.
- **Back up first**, consistent copy (handles the WAL): `sqlite3 "$LRCAT" ".backup '/Users/doug/photo_tools/LightroomCatalog.bak-<ts>.lrcat'"`.
- After writing: `con.commit()` then `PRAGMA wal_checkpoint(TRUNCATE)`. Verify counts before/after.
- Queries are read-only and safe with LR open: `sqlite3.connect("file:...lrcat?mode=ro", uri=True)`.

## What WORKS via direct write
| Thing | Table.column | Notes |
|---|---|---|
| Color label | `Adobe_images.colorLabels` = `'Green'`/`'Purple'`… | Displays + filterable (Attribute → that swatch). Unlabeled = `''`. **Best tool for marking a subset to review in LR.** |
| Flag | `Adobe_images.pick` | `-1` Rejected · `0` none · `1` Pick. Displays. |
| Rating | `Adobe_images.rating` | 0–5; stored as float (`4.0`) — use `int(float(x))` from CSV. |
| GPS | `AgHarvestedExifMetadata`: `hasGPS=1, gpsLatitude=<signed dec>, gpsLongitude=<signed dec>, gpsSequence=1.0` | ⚠️ **`gpsSequence=1.0` is REQUIRED** or the Map ignores the point. **Caveat:** even correct, a direct write shows on the **Map** but leaves the **Metadata-panel GPS *text* field blank** (the panel reads a display cache the DB write doesn't refresh). The geotag is real — Map + export use lat/lon. For the panel field too, use the file route. |

## What you must NOT do
- **Never `DELETE FROM Adobe_images`** to remove photos — LR's foreign keys are off, so you'd orphan rows across `AgLibraryFile`, exif, collections, keywords, stacks → corruption. **Remove photos only via Lightroom** (it cascades correctly).
- Titles/captions are cache-sensitive — prefer LR or the file route. **Keywords, collections, and capture-times, however, DO write cleanly at scale** — see the next section (proven 2026-06: 25k keywords + a 314-collection set + 15k capture-time edits, no corruption).

## Creating keywords, collections & capture-times directly (proven at scale, 2026-06)
**Global id allocator.** Every new row needs a unique `id_local` from `Adobe_variablesTable` row **`Adobe_entityIDCounter`**: read it once, hand out `counter+1, +2, …` for all new keywords/collections/memberships, write the final value back before commit.

**Genealogy = length-prefixed id path** (keywords AND collections). `seg(n) = str(len(str(n))) + str(n)`. Keyword root tag id is `Adobe_variablesTable['AgLibraryKeyword_rootTagID']` (16345 here). Top-level node genealogy = `/seg(root)/seg(id)` (keywords) or `/seg(id)` (collections); a child = `parentGenealogy + '/' + seg(id)` (e.g. keyword id 353658 under root 16345 → `/516345/6353658`).

**Keywords** — `AgLibraryKeyword`: needs `id_global` (UUID, `str(uuid.uuid4()).upper()`), `dateCreated`+`lastApplied` (Cocoa epoch = `unix − 978307200`), `genealogy`, `lc_name` (lowercased), `name`, `parent`, `includeOnExport/Parents/Synonyms=1`, `keywordType=NULL`, `imageCountCache` (count or `-1`). **`UNIQUE(parent, lc_name)`** — dedupe case-variant names under one parent (`Las Palmas`/`las Palmas`) or the insert fails. Apply via `AgLibraryKeywordImage(id_local, image, tag)`. Aux tables (`…KeywordPopularity/Cooccurrence/Synonym/Face`) are caches LR rebuilds — skip. **Tip:** parent every batch under one review keyword (`Places`, `FolderHint`) so the whole set is cull-able/reversible in one place.

**Collections & sets** — `AgLibraryCollection`: collection `creationId='com.adobe.ag.library.collection'`, set/group `='com.adobe.ag.library.group'`; `parent=NULL` top-level else parent id; `systemOnly=0.0`; `imageCount`=member count. **A group holds mixed children** (sub-groups + collections) → nested `By Date → year groups → month collections` works. Membership: `AgLibraryCollectionImage(id_local, collection, image, pick=0, positionInCollection)` — `positionInCollection` a sortable string (`"%06d"%i`) for custom order. **To move a collection's photos into a folder on disk, do it in LR** (select-all → drag to Folders panel); a catalog write moves nothing on disk.

**Capture time / Edit Capture Time** — authoritative is `Adobe_images.captureTime` (`YYYY-MM-DDTHH:MM:SS`), but LR's **date filter/browse reads `AgHarvestedExifMetadata.{dateYear,dateMonth,dateDay}`** (floats, month 1–12) — **UPDATE BOTH** or the date index goes stale (every image has exactly one harvested row). `originalCaptureTime` keeps the pre-edit value — leave it. **Trick:** stamp an unmistakable **sentinel** (`2021-06-15T03:04:00`) on a set to mark + cluster it out of the real month buckets; dump originals to CSV first for reversibility.

**Untrustworthy-date detection (catalog-only).** A `captureTime` is likely the scan/import/file date — not capture — when **no camera-model EXIF AND on a single-day mega-spike** (>250 photos that day = batch stamp: scans dated the scan day, imports the file-mod day), OR the basename is a scan series (`image####`), OR time is exactly `00:00:00`. Separates batch stamps from real busy days (a 1,162-photo Canon-7D shoot is real; 5,699 no-camera scans dated 2010-09-16 are not). ~15k of 67k flagged here.

## File route (full fidelity, when panel/keyword display must update)
Write to the photo's XMP, then in LR **Metadata → Read Metadata from File**:
- **GPS via exiftool: use SIGNED decimals**, NOT separate Ref tags (the `-GPSLatitudeRef`/`-GPSLongitudeRef` tags are silently ignored when writing XMP → wrong hemisphere). Correct: `exiftool -GPSLatitude=17.104 -GPSLongitude=-25.066 -o file.xmp src` → `25,..W` ✓.
- Raw → `.xmp` sidecar; JPEG/DNG/TIFF embed (rewriting a JPEG over SMB risks corruption on a mount drop).
- Read-Metadata **overwrites** catalog fields from the file — to avoid clobbering catalog edits, **Save Metadata to File first**, add tags, then Read.

## Dedup execution gotchas (PhotoSweeper → Lightroom)
- **Stacks hide rejected photos.** `Photo → Delete Rejected Photos` acts on *visible* rejected — photos buried as non-top members of **collapsed stacks** are missed (a run here: 953 hidden, ~447 left after the first delete). The grid's "X of Y photos" count being below the catalog total = collapsed stacks. **Fix:** `Photo → Stacking → Expand All Stacks` first, then Delete Rejected; or accept stragglers and re-run. Verify by the post-delete catalog total. (Stacks here came from the Aperture/iPhoto migration.)
- **Remove ≠ Delete-from-Disk:** always **Remove** (catalog only); delete disk files separately on the NAS (deferred Phase-3 bulk pass). **Capture reject paths *before* removing.**
- **Over-grouping review:** the marked set can contain a different photo wrongly grouped. Flag = rejects with **no same-capture-time keeper**. ⚠️ Noisy here — capture times are unreliable (bogus 2022/2026 import stamps), so most flagged are time-mismatched *true* dups, not real over-grouping. Narrow by **also no same-*name* keeper**. The catalog can't perceptually tell a burst frame from a dup — **color-label the suspects and review by eye in LR.**
- **Metadata rescue reject→keeper:** PhotoSweeper's groups aren't extractable (see `photosweeper-dedup.md`), so reconstruct pairs from the catalog by `(captureTime, baseName)`. The higher-res keeper PhotoSweeper keeps often lacks GPS its JPEG twin had → transfer it.
- **Multi-run:** delete/empty the `Trash (PhotoSweeper)` collection before re-running so PhotoSweeper re-includes everything; loosen the Matching Level to catch what a tight pass missed (review harder — looser over-groups more).
