# Lightroom Classic — Folders Panel & Disk Operations

Library module, left panel group. UI strings quoted from Adobe's User Guide; items not in official docs marked **[not in official docs]**.

## Folders panel ↔ disk
- The Folders panel **reflects the actual on-disk folder structure** under each volume. **"Changes you make to folders in Lightroom Classic are applied to the folders themselves on the volume."**
- Disclosure triangle: **solid** = has subfolders; **faint/dotted** = none.
- Each photo lives in **exactly one folder** (its physical location).

## ⚠️ What changes ON DISK (the load-bearing rules)
- **Renaming a folder in LR renames it on disk.**
- **Moving a folder in LR moves it on disk.** ("You cannot *copy* folders in Lightroom Classic" — drag into another folder to move.)
- **Dragging photos between folders MOVES the files on disk** (drag from the **center** of the thumbnail). "You cannot copy photos in Lightroom Classic." For external/NAS drives, make sure the drive is online first.
- **This is how Phase 3 reorg works:** moving photos/folders via the Folders panel keeps catalog and disk in sync automatically.
- **NOT moved/deleted on disk:** **Remove** (folder or photo) is catalog-only — "the original folder and photos are not deleted from the hard drive." Only **Delete from Disk** sends files to Trash/Recycle Bin.

## Volume header & status LED
Right-click the volume name to choose displayed info: **Disk Space / Photo Count / Status / None**; **Show In Finder/Explorer**; **Get Info/Properties**.
LED (Show Status And Free Space): **Green** ≥10 GB free · **Yellow** <10 GB · **Orange** <5 GB · **Red** <1 GB (tooltip "nearly full") · **Gray** = volume offline (previews only).
Root-folder display (+ icon > Root Folder Display): *Folder Name Only* / *Path From Volume* / *Folder And Path*.

## Adding folders
- **+ icon > Add Folder** → (Mac) "Choose Or Create New Folder" dialog → navigate, **Choose** (or **New Folder**). Specify import options if prompted.
- **+ > Add Subfolder** → "Create Folder" dialog (type name; optionally copy selected photos in). Appears in Finder too.
- **Add Parent Folder** — right-click a top-level folder.

## Folder right-click context menu (documented items)
| Label | Effect |
|---|---|
| **Add Subfolder** | new subfolder (current guide's term; older docs say "Create Folder Inside") |
| **Add Parent Folder** | adds a parent above a top-level folder |
| **Rename…** | **renames the folder on disk** |
| **Remove** | removes folder+photos from catalog & panel; **originals stay on disk** |
| **Synchronize Folder…** | reconcile catalog vs disk (see below) |
| **Update Folder Location** | re-point the catalog folder to a different on-disk copy (multiple copies) |
| **Find Missing Folder…** | relink a moved/renamed (grayed, "?") folder |
| **Show In Finder/Explorer** | open in OS file browser |
| **Get Info / Properties** | OS info window |
| **Export this Folder as a Catalog** | export photos+metadata to a new standalone catalog |
| **Create Collection / Collection Set "[name]"** | make collection(s)/set(s) from folder(s) |
| **Add Color Label** | color strip by the folder count |
| **Mark Favorite** | star on the folder |

**[Not in official docs]** (exist in app, don't cite as official labels): "Import to this Folder…", folder-level "Save Metadata", literal "Go to Folder in Library" (the official command is **Photo > Show In Folder In Library**).

## Synchronize Folder… (Library > Synchronize Folder)
Reconciles a catalog folder with its disk contents. Three options:
1. **Import New Photos** — import files on disk not yet in catalog (with **Show Import Dialog Before Importing** to pick which; that dialog has Don't Import Suspected Duplicates).
2. **Remove Missing Photos From Catalog** — remove catalog entries for files deleted from disk (**dimmed if none missing**; **Show Missing Photos** to view). Removes catalog rows only, not disk files.
3. **Scan For Metadata Updates** — pick up external metadata changes.
Note: "The Synchronize Folder command **does not detect duplicate photos in a catalog.**" Tip: a missing+empty folder can be removed via Synchronize.

## Missing photos & folders — badges & relinking
- Trigger: adding/moving/renaming/deleting files or folders in Finder/Explorer breaks the catalog↔file link.
- Badges: photo-level **"!" (Photo is missing)** on the thumbnail and at the bottom of the **Histogram**; Develop shows "file could not be found"; a missing **folder** is **grayed-out with a "?" icon**.
- **Library > Find All Missing Photos** — show all missing in Grid.
- **Relink one photo:** click the **!** badge → dialog shows last known location → **Locate** → navigate → **Select**. Check **Find nearby missing photos** to auto-reconnect other missing photos in that same recovered folder.
- **Relink a whole folder:** right-click the grayed folder > **Find Missing Folder** → navigate → **Choose** (relinks all its photos at once).
- **Update Folder Location** — re-point to a different copy of a folder.
- Offline drive: bring it online / restore the expected drive letter so paths match.

## Show on disk
- Photo: **Photo > Show In Finder** (Mac) / **Show In Explorer** (Win), shortcut **Cmd+R**.
- **Photo > Show In Folder In Library** — selects the photo in Grid and its folder in the panel.

## Sources
helpx.adobe.com/lightroom-classic: create-folders, photos, locate-missing-photos, kb/catalog-faq-lightroom.
