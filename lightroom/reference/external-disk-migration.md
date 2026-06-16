# Consolidating photos/video from a legacy/external disk

The repeatable pipeline for pulling keepers off an old computer / external RAID / legacy backup into the Lightroom catalog (photos) + Plex (video), and clearing the source. Proven on the 2012 Aperture Mac's Promise RAID (2026-06; ~515k media files / 4.7 TB). Project state lives in repo `HANDOFF.md`; this is the *how*.

## Per-folder pipeline (6 steps — Doug's spec)
1. **Inspect** for pictures **AND movies** (not just images).
2. **Determine new vs catalog** — name-overlap → content-hash → capture-moment → cross-ref removed-rejects.
3. **Stage keepers** → `Data/Pictures/<folder>_new/` (photos) ; clips → Lightroom, finished films → Plex.
4. **Move the rest** (redundant + junk) → a **reversible delete pile** (paths preserved), after verifying **0 catalog refs** point into the source.
5. **Non-importable files** (CAD/SketchUp/PSD/Office/`.key`) → a **`Content/` folder beside the source** (Doug's instruction — preserve, don't delete).
6. **Delete junk** (`@eaDir`/`.ini`/`.db`/`.DS_Store`/`._*`) and **remove the emptied source skeleton** — leftover skeletons masquerade as unprocessed folders (see memory [[doug-remove-skeleton-dirs]]).

## Multi-machine reality (source on a remote/old Mac)
- The source disk is often a **local volume on an old Mac** reachable only by flaky **SMB1** from Doug's Mac. **Don't depend on the SMB mount — SSH to the source Mac** and work against its local disk (`find`/`md5`/`mv` run there, fast).
- Example: 2012 Aperture Mac = `192.168.20.219`, SSH needs `-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa`. Promise RAID at `/Volumes/Promise RAID/`. It **can SSH to the NAS** (`192.168.20.16`).
- **Old-Mac tooling is primitive:** BSD `find` has **no `-printf`** (use `find … -print0 | xargs -0 stat -f "%z|%N"`); `md5` not `md5sum` (`md5 -r` → "hash file", or `xargs -0 md5 -r` batched for speed); **no `python3`** (python2 only) and **no `exiftool`**. Do the analysis on Doug's Mac (.150, has python3 + catalog); run hashing/moves on the source via SSH.
- **RAID root may not be doug-writable** — put the local delete pile in a writable subdir (e.g. `…/Temp Store/Pics4Delete/`), *outside* the areas being processed so it isn't re-scanned.

## Dedup methods (in order; each cheaper than the next is skipped)
1. **Name-overlap** vs catalog basenames (on .150). Eliminates the bulk.
2. **Content-hash (md5)** for the not-in-catalog-by-name residual: md5 candidates on the source Mac; md5 the **size-collision** subset of catalog files on the NAS (stat catalog paths, hash only those whose size matches a candidate). Compare hashes → byte-dups. (Cross-machine is fine — md5 is md5; normalize BSD vs Linux output.)
3. **Capture-moment** vs catalog `captureTime` — the key filter that separates "genuinely new" from "already-cataloged-different-rendition." Two ways:
   - **exiftool over the mount** (header reads, SMB1-tolerable) — but the mount **drops under load**, so prefer:
   - **Path-date for Aperture/iPhoto bundle masters** — `Masters/YYYY/MM/DD/timestamp/` encodes the shoot. Build the catalog **shoot-folder set** (regex `/(\d{4}/\d{2}/\d{2}/\d{8}-\d{6})/` over catalog paths) and match. No mount/exiftool needed. This is what saved the run when SMB dropped.
   - **Loose photos** (no date path, no exiftool) → name+content-hash+reject-xref only, then **conservative-stage** (over-include; safe direction since keepers are reviewed before import). Note time normalization: catalog uses `T` (`2011-05-19T…`), EXIF uses space — normalize or everything false-flags as new.
4. **Cross-ref removed-reject names** (the PhotoSweeper `reject_paths_pass*.csv`) — catches dups already culled.
   - **Google Photos / Takeout exports are a special case** (proven on `Data/Google Photos`, 2026-06-14: 2,145 media → only **120 genuinely new**). Google **rewrites EXIF `DateTimeOriginal`** on its "High quality" re-encodes, so exiftool-date vs catalog-`captureTime` **under-catches dups badly** (looked like 1,225 "new"; really 120). The reliable key is the **`<media>.supplemental-metadata.json` sidecar's `photoTakenTime.timestamp`** (the TRUE original moment, **unix UTC**) matched **tz-tolerantly** against the catalog (catalog `captureTime` is naive *local* time — test the instant shifted by every −12h…+14h offset in 30-min steps; same absolute instant at some tz = same photo). Also content-hash for byte-identical originals. gifs aren't LR-importable; pngs are often screenshots — stage jpg/png, drop gif. Doug's eyeball is the backstop ("almost all are worse versions" = the date filter missed re-encodes).
5. **Dedup keepers vs what's already staged on the NAS** (basenames of `Data/Pictures/*_new/`) — a re-processed copy of an already-done backup mustn't re-stage the same files.

### ⚠️ Capture-moment matching is NOT enough on its own — two failure modes that hid ~95% of dups (2026-06: Google Photos + local Downloads sweep)
- **The catalog stores many `captureTime`s timezone-shifted or bogus.** Aperture/iPhoto/scan imports landed times at **UTC (e.g. local +4h)**; some imports stamped **regular-interval import timestamps** (e.g. `DSN_###` all at `2008-08-16T00:37/00:39/00:41…`, 2-min apart) or even a **future date** (`2026-06-07`). Exact-second moment-match misses all of these. **ALWAYS match tz-tolerantly** — test the file's moment shifted by every −12h…+14h offset in 30-min steps against the catalog moment set. (This alone turned "1,030 new" into "82" on the local sweep; tz-tolerance caught 949.)
- **Bogus/regular-interval/date-only catalog times defeat moment-match entirely** → fall back to **name-match for NON-recycled names.** `DSN_###`, `image####`, `mom####`, descriptive names are unique series → basename-in-catalog = dup. Only `IMG_####`/`DSC###`/`PICT###`/`DSCN###`/`P\d…`/`GOPR`/`DJI_` recycle, so for those name-match is inconclusive (keep as candidate). (Name-match caught 58 more dups the bogus dates hid → 82 down to ~24.)
- **Order the ladder:** byte-hash → tz-tolerant moment → name-match(non-recycled) → residual is the true candidate set. Then the human eyeballs it — Doug's "I'm seeing the same pictures imported several times" is the signal the date filter is leaking; look harder, don't just stage-and-let-PhotoSweeper-sort (that re-bloats).
- A local Downloads/whole-drive sweep is **mostly junk**: exclude `Music` (album art), `Programming`/`.vscode`/`.platformio` (dev assets), `Library`, sub-100 KB icons, gif/bmp/webp; filter to files **with camera EXIF (`DateTimeOriginal`+`Model`)** to isolate real photos from screenshots/web/doc-exports — but even then expect the genuine-unique residual to be tiny (1,031 camera-EXIF files → 24 candidates → a handful of real photos; rest were screenshots + project diagrams).

## Move architecture — only keepers cross the network
- **Keepers** → stage locally on the source (`…/KEEPERS/{photos,video}` preserving rel path), then **one batched transfer to the NAS**. **scp/sftp are disabled on Synology and the old rsync fails auth** → use **tar-over-ssh**: `tar -C src -cf - . | ssh NAS 'tar -C dest -xf -'` (ignore the harmless `SCHILY.*`/`LIBARCHIVE.*` header warnings).
- **Redundant + junk** → a **LOCAL delete pile on the source disk** (instant rename, **never** copied across the network). Never transfer 3 TB of redundant data to the NAS. The delete pile is **reversible and never purged** until Doug confirms imports.
- **Bulk-move library bundles wholesale** — after extracting keeper masters, `mv` the whole `.aplibrary`/`.photolibrary` (315k+ thumbnail internals + cataloged masters) to the delete pile in one rename rather than per-file.

## Video handling
- **Type model (Doug's spec):** finished films / sailing / slideshows → **Plex** ; short camera clips (<~250 MB) → **Lightroom** (live with photos, findable for future montages).
- **Dedup vs the Plex/Media library** (`find Media -iname '*.mov' … -printf '%s\t%f'` → name+size index). iTunes/Arr renaming means **name-match against Plex is unreliable** — classify commercial-vs-personal by **path** (`iTunes Media/TV Shows|Movies`, scene-release filename tags) instead.
- **ToPlex must MIRROR the Plex folder structure**, not preserve source paths. Plex layout: `Movies/`, `TV Shows/`, `Other Shows/{Home Movies, Sailing, Instructional, …}`. **Commercial content is fine if filed where Plex would put it** (Doug's correction). Flatten out of `.photoslibrary/Masters/…` and `.rcproject/` nesting; dedup exact copies **by size**; rename generic exports (`large.m4v`) by their `.rcproject` name.
- **Drop iMovie internals:** exclude `iMovie Cache` / `iMovie Thumbnails` / `Cache.mov` / `render.mov` — they're not real videos. The `.rcproject/Movies/large.m4v` IS the finished render (keep, rename by project).

## What to LEAVE alone (exclusions)
- **Final Cut** — `.fcpbundle`, `Final Cut*`, `Render Files`/`Proxy Media`/`Transcoded Media`/`Capture Scratch`, `Motion Templates` (if Doug wants FCP left).
- **Time Machine** — `Backups.backupdb` (hardlinked snapshots; moving corrupts them).
- **Apps/system** — `Applications`, `Library`, `.app`, browser cache (`Temporary Internet Files`/`Local Settings`/`AppData`), `Program Files`, screensaver/editor sample media (`Reef Series`, Pinnacle backgrounds).
- **iWork internals** — `.key`/`.pages`/`.numbers` store images internally; exclude.
- **Bundle-internal thumbnails** — anything in a `.aplibrary`/`.photolibrary` NOT under `Masters/`/`Originals/` is preview/db junk (can be ~6× the master count).

## Gotchas
- Inventory finds must **prune** the exclusions above or counts balloon (515k "media" → 193k real → 81k new-by-name → a few thousand real keepers).
- **Empty skeletons are common** — a source "Pictures" folder may be 0 bytes because its content was already extracted to the NAS (matching bundle names like `recoveredAperture`/`iPhotoRecover`). Treat empty → already-done → remove.
- `cp` loops occasionally drop 1 file silently — verify staged counts and re-copy the straggler.
