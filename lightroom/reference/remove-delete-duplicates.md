# Lightroom Classic — Removing/Deleting Photos & Duplicates

Mac shortcuts primary (Win: Ctrl=Cmd, Alt=Opt). Items not verbatim from a primary source marked **[inferred]**.

## Remove vs Delete from Disk — the core distinction
| Action | Catalog entry | File on disk |
|---|---|---|
| **Remove** (from Catalog) | deleted (with collections/history/smart previews) | **stays on disk, untouched** |
| **Delete from Disk** | deleted | **moved to Trash/Recycle Bin** |

LR can't infer which you want, so it shows a dialog — except where a shortcut forces one behavior.

> **This project always uses Remove (catalog only).** Disk cleanup is done separately on the NAS via SSH. See the NAS gotcha below.

## The delete dialog, by context
**In a FOLDER / All Photographs** — select + **Delete/Backspace** raises:
> "Delete the selected master photo from disk, or just remove it from Lightroom (Classic)?"
Buttons: **Delete from Disk** · **Remove** · **Cancel**.

**In a COLLECTION** — plain **Delete/Backspace** only **removes the photo from that collection** (no catalog/disk change, usually no dialog). Smart Collections behave similarly. To actually delete: right-click > go to the folder (or **Photo > Show In Folder In Library**) and delete there, or use the forcing shortcut below.

## Delete/Remove keyboard shortcuts
| Intent | Mac | Windows |
|---|---|---|
| Raise delete dialog (Grid) | `Delete` | `Backspace` |
| Raise dialog for selected in Loupe | `Shift+Delete` | `Shift+Backspace` |
| **Remove from catalog, keep file** (no dialog) | `Opt+Delete` | `Alt+Backspace` |
| **Remove + send file to Trash** ("super delete", no dialog, **not undoable**) | `Cmd+Opt+Shift+Delete` | `Ctrl+Alt+Shift+Backspace` |
| Delete Rejected Photos (raises dialog) | `Cmd+Delete` | `Ctrl+Backspace` |
| Set Reject flag | `X` | `X` |
| Remove from current collection | `Delete` (source = collection) | `Backspace` |

## Already-missing / offline files
If the master file is unreachable (the **!** missing badge, or offline volume), the dialog's **"Delete from Disk" button is grayed out** — you can only **Remove**. (Same for virtual copies.) → **Orphaned/missing catalog entries can only be Removed in LR; disk deletion of those must be done at the filesystem level (SSH/Finder).** This is exactly why the 1,876 ApplePhotos missing rows could only be Removed.

## ⚠️ NAS / network volume reliability (root cause of this project's orphan mess)
"Delete from Disk" is **known-unreliable on network/NAS volumes** — an **Adobe-acknowledged issue still open in 2026** (Synology especially; worsened by recent macOS security updates). Typical failures:
- "The files are on a volume that does not support Trash. Would you like to permanently delete them?" → permanent delete bypasses Trash (unrecoverable).
- "This file cannot be moved to the trash. Please try deleting directly from the disk."
Cause: NAS appliances lack a macOS `.Trash`, and/or LR's Full Disk Access breaks after macOS updates. Notably **Finder and Adobe Bridge can often delete from the same NAS when Lightroom can't.**
**Correct workflow for NAS:** **Remove from catalog in Lightroom, then delete the actual files on the NAS via SSH.** (This is the project's Phase 1/3 approach.)

## Rejected flag & Delete Rejected
- Set Rejected: **X**, or **Photo > Set Flag > Rejected**. Rejected photos show dimmed with a black flag.
- **Photo > Delete Rejected Photos…** (`Cmd+Delete`) — gathers all Reject-flagged photos in the current view and raises the same **Delete from Disk / Remove / Cancel** dialog. Rejects are NOT auto-trashed; you still choose. **[dialog reuse inferred]**

## Duplicates
**Lightroom Classic has NO built-in duplicate finder** (true through 13.x/14.x, 2026).

**Only native dup avoidance:** Import > File Handling > **Don't Import Suspected Duplicates** — matches filename + EXIF capture time + file size; won't catch same-image-different-name. Import-time only; does nothing about dups already in the catalog.

**Third-party tools:**
- **Teekesselchen** (free LR plugin) — *Library > Plug-in Extras > Find Duplicates*. Compares by **EXIF metadata** (not pixels). Adds keyword `Duplicate`, sets Reject flags, builds a Smart Collection "Duplicates". Never deletes.
- **PhotoSweeper** (paid standalone — **the tool this project uses**) — compares by **pixel content**, so it catches same-image-different-name/format/resolution. See `photosweeper-dedup.md`.

## Sources
jkost.com (Julieanne Kost, Adobe) "Removing and Deleting Photographs"; helpx keyboard-shortcuts; Adobe Community & Lightroom Queen threads on NAS "volume does not support trash" / Synology delete failures; github.com/fuxs/teekesselchen.
