# Visual review-pairings workflow (Doug + Claude review dup decisions together)

A repeatable way to **review uncertain duplicate pairings by eye** when auto-matching (PhotoSweeper marks + reject→keeper reconstruction) isn't confident. Claude builds a Lightroom collection that puts each suspected-dup next to its candidate keeper(s); Doug flags keep/delete in LR; Claude reads the flags back and executes. Proven 2026-06-14 (37 rated-uncertain rejects from a PhotoSweeper pass). Doug's words: *"this is a good way for you and i to do a visual review of shots together."*

## When to use it
After a PhotoSweeper pass, for the rejects where the reject→keeper pairing is **ambiguous or missing** — especially **rated** rejects (losing them loses a rating / maybe a unique photo). Confident pairings (unique name+time or time+camera match) get their rating auto-moved and are left in the trash pile; only the uncertain ones go into the review collection.

Pairing reconstruction tiers (PhotoSweeper hides its groupings — rebuild them): exact `basename+captureTime` (HIGH) → `captureTime+camera` unique (MED) → multi-candidate (AMBIG) → loose normalized-name (strip `(N)`/`-O`) → none. **AMBIG + none = the review set.**

## Build the collection (catalog direct write — LR CLOSED, backup first)
Script: `/Users/doug/photo_tools/build_review_pairings.py`. Structure:
- **One collection** `Review Pairings <date>` holding each uncertain reject + its candidate keepers.
- **Color = role:** `colorLabels='Red'` = the reject (delete-candidate), `'Green'` = candidate keeper(s). (LR tints the grid cell.)
- **Custom order = set grouping:** `AgLibraryCollectionImage.positionInCollection` (a sortable string — zero-padded `"%05d"` works) ordered so each Red sits immediately before its Green(s). Doug sets **Sort → Custom Order** and each `red→green(s)` cluster is one decision.
- **Caption = set id:** `AgLibraryIPTC.caption = "REV-01".."REV-NN"` (one IPTC row already exists per image — just UPDATE).
- **Quarantine:** DELETE the review rejects from the `Trash (PhotoSweeper)` collection and set `pick=0`, so a later bulk-remove of the trash pile can't take them.
- **Lone red** (no green) = PhotoSweeper found no twin → likely **over-grouping → keep**, not delete.

### Catalog-write specifics learned here (all in `catalog-direct-writes.md` family)
- New ids: read+increment `Adobe_variablesTable` row `Adobe_entityIDCounter` (the global id_local allocator); use values above it, write it back.
- Collection row `AgLibraryCollection(id_local, creationId='com.adobe.ag.library.collection', genealogy, imageCount, name, parent=NULL, systemOnly=0)`.
- **genealogy format** = parentGenealogy + `'/' + str(len(str(id))) + str(id)` (length-prefixed id path). Top-level: `'/'+len+id` (e.g. id 11 → `/211`, id 5051574 → `/75051574`).
- `colorLabels` canonical strings: `Red/Yellow/Green/Blue/Purple`; unset = `''`.

## Doug reviews in Lightroom
1. Collections panel → `Review Pairings <date>` → **Sort: Custom Order**.
2. See set ids: **⌘J → Grid View → Cell Extras → Caption** (the `REV-##`). **The big grey grid numbers are NOT the set numbers** — they're cell slots; ignore them.
3. Read it: 🔴 = proposed delete, 🟢 = proposed keeper, **both are proposals — Doug is the judge.**
4. **Flag decisions** (flags override the colors):
   - **X** (reject) on any photo = **delete it** (red *or* green — Doug often keeps the rated red original and culls redundant green format-copies `.tif/.psd/.CR2`).
   - **P** (pick) on a **keeper** = "true twin — **move the deleted red's rating/GPS/keywords onto this one**." Only fires when that set's red is also X'd.
   - **unflagged** = keep, **move no metadata** (this is the "not the same / don't move it" default).
   - Select-multi (⌘/Shift-click) then X/P to batch (e.g. P all lone reds at once).

## Process the decisions back (LR CLOSED, fresh backup)
Script: `/Users/doug/photo_tools/execute_review_decisions.py`. Reads `Adobe_images.pick` of the collection members:
- For each set with an **X'd red + P'd green(s)** → move rating (only if recipient unrated); GPS/keywords if present (rating is the safe one — GPS/keyword writes are cache-sensitive, prefer the file/exiftool route or note they're in the capture CSV).
- All **X'd** photos → add to `Trash (PhotoSweeper)` (+`pick=-1`) for the one final removal.
- **Restore** original `colorLabels` + `caption` on the kept photos from the pre-build backup (the build overwrote a handful of real ones).
- **Delete** the `Review Pairings` collection (rows in `AgLibraryCollectionImage` + the `AgLibraryCollection` row).
Then Doug does **Remove from Catalog** on `Trash (PhotoSweeper)` (never Delete-from-Disk on NAS).

## Safety / gotchas
- **Capture reject metadata to CSV first** (`reject_metadata_capture_<date>.csv`) so a rating/GPS/keyword is never truly lost regardless of flagging.
- **Two fresh `.lrcat` backups** bracket the two writes (`BACKUP-reviewpairings-*`, `BACKUP-reviewexec-*`) — full revert is `cp` the backup.
- Recycled Canon filenames (`IMG_1393` ×5–7) defeat name-based pairing and **also defeat LR's "Don't Import Suspected Duplicates"** — content/bitmap (PhotoSweeper) or capture-time is the real signal.
- Lone reds skew the cell-vs-set alignment — that's why captions, not cell numbers, mark sets.
- Both write scripts **abort if Lightroom is running** (`lsof` the catalog + `ps` the app) — quit LR fully (a lingering `Adobe Crash Processor` helper is harmless; the `.app/Contents/MacOS/Adobe Lightroom Classic` process is the real one).
