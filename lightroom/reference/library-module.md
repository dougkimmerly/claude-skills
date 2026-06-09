# Lightroom Classic — Library Module & Organizing

Mac keys primary (Win: Ctrl=Cmd, Alt=Opt). **[LRQ]** = from the Lightroom Queen / John R. Ellis shortcut PDF (matches the app's shortcut help; secondary to Adobe). **[inferred]** = standard but unconfirmed this session.

## Modules & Module Picker (upper-right)
Library · Develop · Map · Book · Slideshow · Print · Web.
Switch: **Cmd+Opt+1…7** (Library=1 … Web=7); **D**=Develop; from Library, **G/E/C/N** jump to its views. Module history: **Cmd+Opt+↑** previous; **Cmd+Opt+←/→** back/forward. **[LRQ for 3–7 & history]**

## Library view modes
| View | What | Key |
|---|---|---|
| **Grid** | thumbnails | `G` |
| **Loupe** | single photo, zoom | `E` |
| **Compare** | two side-by-side: **Select** (active) vs **Candidate** | `C` |
| **Survey** | several tiled to narrow down (active = white border; X to drop) | `N` |
Return to Grid: `Esc`. People/Faces: `O`. Reference: `Shift+R`. **[LRQ]**
Grid: thumb size `=`/`-`; cycle cell style `J`; View Options `Cmd+J`. Loupe: toggle zoom `Z`/`Space`; 100% `Cmd+Opt+0`; cycle info `I`.

## Panels
**Left** (sources): Navigator, Catalog, Folders, Collections, Publish Services. **Right** (metadata/adjust): Histogram, Quick Develop, Keywording, Keyword List, Metadata, Comments.
Toggle side panels **Tab**; everything **Shift+Tab**; Filmstrip **F6**; left/right panels **F7/F8**. Open/close all in a group: **Cmd-click** header. Solo mode: **Opt-click** header. **[LRQ for F-keys]**
Toolbar show/hide: **T** (contents customizable via the pop-up at its right).

## Flags, ratings, labels (three independent systems — combine freely)
**Flags** (quick cull): Pick `P` · Reject `X` · Unflag `U` · toggle `` ` ``. Rejected = dimmed. Hold **Shift** (or Caps Lock) to auto-advance. **Flags saved to XMP since 13.2.** *Library > Refine Photos* (`Cmd+Opt+R`): unflagged→Reject, Picks→Unflag.
**Star ratings 0–5:** keys `0`–`5`; decrease `[` / increase `]`.
**Color labels:** Red `6` · Yellow `7` · Green `8` · Blue `9` · **Purple = no default key**. Name via *Metadata > Color Label Set > Edit*.
Distinction: flag = keep/reject binary; rating = 0–5 quality scale; label = arbitrary category (nameable). Orthogonal — e.g. Smart Collection "5 stars AND Red".

## ⭐ Folders vs Collections (the crucial concept)
- **Folders = physical/on disk.** One folder per photo. Moving/renaming a folder, or dragging a photo between folders, **changes it on disk** (you cannot copy, only move).
- **Collections = virtual groupings**, listed in every module. **A photo can be in many collections.** Removing a photo from a collection (or deleting the whole collection) removes **nothing** from the catalog or disk. Photos in a collection show a "Photo Is In Collection" badge.
- **Collection Set** = container holding collections (no photos directly). Can't be a Target Collection.
- **Smart Collection** = rule-based, auto-populated (you never add/remove manually); Match all/any; settings = `.lrsmcol`. Defaults: Colored Red, Five Stars, Past Month, Recently Modified, Without Keywords.
- **Quick Collection** (`B` to add/remove; one exists at a time; in the Catalog panel). **Target Collection** = right-click any regular collection > **Set As Target Collection** (white + badge) → then `B` adds to *that* collection.

> PhotoSweeper drops marked duplicates into a collection named **`Trash (PhotoSweeper)`** and sets the **Reject** flag — both are catalog-side markers you then act on.

Collection shortcuts: New Collection `Cmd+N`; New Collection Set/Folder `Cmd+Shift+N`; Show/Save/Clear Quick Collection `Cmd+B` / `Cmd+Opt+B` / `Cmd+Shift+B`. **[LRQ]**

## Library Filter bar (`\` to toggle, top of Grid)
Three modes, combinable (results match ALL active):
- **Text** — searches indexed metadata (filename, caption, keywords, EXIF/IPTC). Select with `Cmd+F`. Operators: `+word` = starts-with, `word+` = ends-with, `!word` = doesn't-contain. **[LRQ]**
- **Attribute** — flag status, edit status, star rating, color label, copy status (master/virtual/video).
- **Metadata** — up to 8 columns (date, camera, lens, keyword, location…).
Enable/disable filters `Cmd+L`. Filters are **not sticky** by default (cleared on source change) unless *File > Library Filters > Lock Filters*. Also filter by clicking the arrow beside a keyword (Keyword List) or selecting a folder/collection.

## Selecting photos — active ("most-selected") photo
- Many can be selected; **only one is active** (lightest cell / brighter frame). Click a selected photo to make it active without losing the selection; click outside the selection to reset.
- **Where edits land:** in **Grid**, changes apply to **all selected**; in **Loupe/Compare/Survey**, only to the **active** photo.
| Action | Mac |
|---|---|
| Noncontiguous / range select | `Cmd`-click / `Shift`-click |
| Select All / None / Only Active | `Cmd+A` / `Cmd+D` / `Cmd+Shift+D` |
| Deselect active (next becomes active) | `/` |
| Select Flagged / Deselect Unflagged | `Cmd+Opt+A` / `Cmd+Opt+Shift+D` |
| Prev/Next *selected* photo | `Cmd+←` / `Cmd+→` |

## Stacking
Group `Cmd+G` · Unstack `Cmd+Shift+G` · collapse/expand `S`. Only within one folder or one collection, never across.

## Screen / Lights Out
Cycle screen modes **F**; Normal `Cmd+Opt+F`; Full-screen-hide-panels `Cmd+Shift+F`. **Lights Out** cycle **L** (On→Dim→Out).

## Other useful shortcuts
Rotate L/R `Cmd+[` / `Cmd+]`. Copy/Paste Metadata `Cmd+Opt+Shift+C/V`. Save Metadata to File `Cmd+S`. Add Keywords field `Cmd+K`. Create Virtual Copy `Cmd+'`. Rename `F2`. Show in Finder `Cmd+R`. Import `Cmd+Shift+I`. Export `Cmd+Shift+E`. Edit in Photoshop `Cmd+E`. Catalog Settings `Cmd+Opt+,` / Preferences `Cmd+,`. Current-module shortcut help **`Cmd+/`**. Undo `Cmd+Z`.

## Sources
helpx.adobe.com/lightroom-classic: workspace-basics, flag-label-rate-photos, photo-collections, browse-compare-photos, finding-photos-catalog, create-folders, photos; Lightroom Queen / John R. Ellis "Lightroom Classic Keyboard Shortcuts" PDF (17 Jun 2025).
