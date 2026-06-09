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

## Sources
overmacs.com (homepage, manual PDF, ?p=releasenotes); Mac App Store id463362050 / id506150103; cisdem.com & northlight-images.co.uk & macworld reviews; lightroomqueen.com (undo Trash (PhotoSweeper)); jkost.com (Remove vs Delete).
