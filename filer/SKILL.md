---
name: filer
description: The Filing Contract authority — the ONE canonical taxonomy + naming + placement rules for where every file lives across Doug's entire digital life (DSN/XTL, health, personal, Google Drive migration, both Macs). Assisted filing of any collection into canonical homes. Use for "file this drive", "where should this go", "dedup/clean up this folder", "what structure should we use here". Covers the survey→recognize→name→file loop, entity structures, dedup ladder, and the propose→approve→move→reindex→log workflow. Owns the Contract (drive-auditor/SUBJECT-TAXONOMY.md + NAS-ORGANIZATION.md + rules.json); other filing engines READ it (workshop ADR 0040). Lives in ~/Programming/filer.
triggers:
  - file this drive
  - where should this go
  - is it already on the nas
  - dedup folder
  - newHole / DriveRescue filing
  - what structure should we use
---

# Filer

**Mindset: survey first, propose second, Doug decides.** Never design a structure in advance.
Never move or delete anything without approval. The structure emerges from what's actually there.

---

## ⚠️ Cardinal rule: NEVER DELETE. MOVE ONLY.

Learned the hard way, 2026-07-02, mid-`_DriveRescue` drain: filer deleted ~350+ files it judged
"junk" (installers, app caches, a Google Drive export zip never opened first) before Doug corrected
this. One deleted zip held 4 real medical records; fixer was able to restore it, but most of what
was deleted is gone for good. **"Confirmed junk" is still a judgment call, and judgment calls are
wrong often enough that deletion must never be the tool.**

- **Nothing gets `rm`'d or `unlink()`'d. Ever. Not junk, not exact-hash duplicates, not an empty
  zip shell after its contents are safely extracted and filed.** Every file object gets *moved*
  somewhere.
- Anything that looks like junk (installers, app caches, empty library-database shells, stock
  software samples) goes to **`_to-sort/Quarantine/<drive-rescue-folder>/`** — Doug reviews and
  clears it himself. This is a peer of `_to-sort/` and `_duplicates/` as a third standing staging
  folder for every filing project.
- Confirmed exact-hash duplicates of content already filed still go through `_duplicates/` (staged,
  logged in `DUPLICATES-LOG.csv`), never straight deletion — that convention already existed and is
  unaffected by this rule; what changed is that *unrecognized/junk* files now also get a landing
  spot instead of being destroored.
- **Any helper script that calls `.unlink()` or `rm` on a "junk" branch is a bug.** Route it to a
  `QUAR_ROOT` / Quarantine destination instead — see the standard helpers below.
- **Every zip/archive gets opened and its contents inspected before any decision is made about it**
  — `unzip -l` at minimum, extract-and-look if the name doesn't make the contents obvious. A zip
  named after a generic download can hold anything; judge by content, never by filename alone.
  **A `.zip` extension doesn't guarantee `unzip` will work** — old Mac archives are sometimes
  StuffIt (`.sit`/`.sitx`) mislabeled with a `.zip` extension; `file <path>` reveals the true format
  when `unzip -l` fails with "cannot find zipfile directory." For StuffIt specifically:
  `brew install unar` (an actively-maintained, local, open-source tool — no need to upload a
  business/personal file to some web converter), then `unar -o <destdir> <archive>`. Don't quarantine
  an unopenable archive without at least trying `file` + the matching extraction tool first.

---

## ⚠️ The cardinal failure mode: box-relocation ≠ content-filing

The single biggest way a filing pass goes wrong is **moving a folder whole instead of filing its
contents.** A migration mapping (`DSN HR Files/` → `Management/HR/`) is only safe when the box is
**already homogeneous** — one content type, content-named, no embedded junk/media/mailboxes.

Audited 2026-06-29: a prior DSN pass relocated ~26 source-dumps intact. It met the *letter* of the
migration table while violating its *intent* — of 142k "filed" files, the bulk were someone's old
C: drive moved whole, complete with `$RECYCLE.BIN`, Lotus Notes program trees (7,576 files),
installers (4,996), an audiobook library (5,787 mp3s in `Strategy/`), and **365 buried `.nsf`
mailboxes**. "Filed" by box, never filed by content.

**Before moving ANY folder, classify it:**

| Folder kind | Signals | Action |
|---|---|---|
| **Homogeneous** | one content type, content-named, no junk/media/mailboxes inside | relocate whole — safe |
| **Heterogeneous dump** | provenance name (`X Archive`, `… from Shared`, `NO NAME`, `from <person>`); an employee home dir; a server/volume image; a recycle bin; embedded program dirs (`W32/`, `jdbc/`, `IBM_TECHNICAL_SUPPORT/`, `SmartUpgrade/`) | **never relocate intact** — send to `_to-sort/` and explode file-by-file through the full pre-sort + dedup ladder |

If you can see a person's name, a source label, or a recycle bin in the folder you're about to move,
**stop — explode it.** A dump must never appear at a department top level.

### Provenance-token ban on destination names
Destination folder names describe **content only**. These tokens mean you carried the *source* into
the name — strip/rename them:
`from <x>`, `(from <x>)`, `<name> Archive`, `<name> Shared`, `NO NAME`, `Novell`, `from APPS`,
`MaggieDSN`, `google management`, person-source prefixes (`BYK from Drew`).
When two folders hold the same content from different sources (`Carrier Rates/from NO NAME` +
`/from Novell`; 3× `Hockey Pool`), **merge to the one content home and run the dedup ladder** — never
keep parallel source-named copies.

### Staging folders are never children of a department
`_DelSyncFiles/`, `_to-sort/`, `_duplicates/` are **sources/holding areas**, not content. If one is
nested under a department (audited: `Management/HR/_DelSyncFiles`, `Sale Documents/_DelSyncFiles`,
`Operations/Admin Documents/_DelSyncFiles`), it was mis-filed — pull it back to the share root and
reconcile it as a source (see `_DelSyncFiles` pattern below). These often mirror real trees, so they
are mass-duplication risks, not new content.

### Pre-sort runs at file granularity — even deep inside a dump
Junk-drop and managed-library handoff fire on the **exploded files**, never skipped because a box was
moved: `.nsf`→extract queue, `.id`→id vault, audiobooks→`Books/`, videos/event-photos→`PhotoReorg/`,
music→`_MusicToImport/` — wherever they are found.

---

## The primary loop — survey → recognize → name → file

### 1. Survey
Before touching anything, look at the whole collection:
- Count by file type and extension
- List the top folder names and file name patterns
- Note volume clusters (200 files named `Invoice*` is a signal; 3 insurance PDFs is not)
- Note date ranges
- Open ambiguous files — never classify on name or extension alone

The content reveals its own shape. Don't impose a structure; read the one that's there.

### 2. Recognize patterns
Look for natural groupings:
- Same topic / same system that produced them
- Same time period (a year-end, a project, an event)
- Same audience or department
- Same document type (invoices, statements, contracts)

A folder is warranted when a grouping has **enough similar files that a flat listing would be hard to navigate** — rough threshold ~10+, but use judgment. 3 insurance docs stay flat. 50 invoices get a folder.

### 3. Name the pattern
Name at the right level of abstraction:
- Specific enough to be meaningful (`Accounts Receivable`, not `Financial`)
- Generic enough to accept future similar files (not `2013 Invoices to XTL`)
- Use the vocabulary the entity actually used (department names, not generic bureaucratic labels)

### 4. File
Execute the approved structure. Then capture any new rule so the next session doesn't re-derive it.

---

## Universal pre-sort: questions that apply to every collection

Before asking what department or subject something belongs to, two questions always come first:

### Is it junk / app artifact?
**Quarantine these everywhere — never delete (see cardinal rule above)** — they are never business
records, but they still go to `_to-sort/Quarantine/<folder>/`, not `rm`:
- `._*` AppleDouble sidecars, `.DS_Store`, `desktop.ini`, `Thumbs.db`, `Icon\r`, `.localized`
- QB app data: `.TLG`, `.ND`, `.SearchIndex/`, `_MigrationReport.xml` (READ first — it can reveal other companies), `QuickBooksAutoDataRecovery/`, `Restored_<co>_Files/`, `QuickBooks Letter Templates/`, `<co> - Images/`
- Notes client junk: `.nbf`, `.njf`, `.hst`, `.dmp`, `.ncf`, `.mod`, `Cache.NDK`
- App temp/config: `.ini`, `.tmp`, lock files, crash dumps, `segments.gen`
- **Quarantine only after the real data they accompany is confirmed safely filed.**

### Is it a managed-library type?
These have a system that owns them — hand off, don't file into subject folders:

| Type | System | Destination |
|---|---|---|
| Photos / RAW | Lightroom | `Data/PhotoReorg/<source>/` staging → Lightroom import |
| Videos (any — personal OR company events) | Lightroom | `Data/PhotoReorg/<source>/` staging — **even DSN event videos go here, not the event's dept folder** |
| Music | beets / musiclib | `Media/_MusicToImport/<source>/` staging → beets import |
| Commercial movies / TV | Plex | `Media/{Movies,TV Shows}/` |
| Mailboxes (`.nsf/.pst/.dbx/.emlx`) | Extract pipeline | `_mailboxes-to-extract/<label>/` |
| Calendar files (`.ics`, calendar `.csv`) | Archiver | Move to Home Files but **flag in the filing log for the Archive CC** to extract timeline events — do not just file and forget |
| Notes `.id` files | ID vault | Never discard; catalog to `notes-id-vault/` |

**Logo / graphic asset images** (company logos, route maps, presentation graphics) are **document assets**, not photos — they stay in their department folder (e.g. Sales/Marketing), not PhotoReorg. Distinction: if it was created for use in a document/presentation, it's an asset; if it was taken with a camera or records an event, it's a photo/video.

**Apple Photos/iPhoto/Aperture libraries** (`.photoslibrary`/`.photolibrary`/`.aplibrary`) — extract, don't
relocate whole. The internal folder structure (`originals/<hex-bucket>/` or `Masters/<uuid>/`) carries no
useful hint, so folder-structure-as-hint doesn't apply here the way it does for a plain photo dump:
1. If the library already uses `Masters/<year>/<month>/<day>/` (older Aperture/Photos format), that IS a
   usable date structure — dedup + move preserving it directly, no extra tooling needed.
2. If it uses `originals/<hex-bucket>/<uuid>.ext` (newer Photos.app format), there's no natural structure
   to preserve — batch-extract capture dates with `exiftool -r -j -DateTimeOriginal -CreateDate -FileName
   -Directory <originals-dir>` (one bulk call, NOT one exiftool invocation per file — over SMB that's the
   difference between minutes and hours for thousands of files), then move into
   `PhotoReorg/<source>/<library-name>/<YYYY-MM>/`. Files with no EXIF date (common for Photos-derivative
   JPEGs vs HEIC/MOV originals) go to an `unknown-date/` bucket — still preserved, just not date-sorted.
3. The `database/`, `private/`, lock files are the app's internal SQLite/cache — no photo content, always
   safe to Quarantine (not delete, see cardinal rule above) once the real files are extracted.

**Video-editing project bundles** (Final Cut `.fcpbundle`, iMovie `.imovielibrary`/`Final Cut Events`/
`iMovie Events.localized`/`.rcproject`) — **preserve intact as a unit, do NOT hand-extract "the real
files."** These aren't a media dump with a few cache files mixed in — the edit itself (timeline, cuts,
titles) lives in project metadata that's meaningless without the rest of the bundle, and — the load-bearing
finding, 2026-07-02 — a bundle's `Proxies/` folder can be the **only surviving copy** of a clip if the
original Event footage was deleted after a proxy-only edit was made (confirmed on a real `Sailing 2013`
project: its proxy had no corresponding full-quality original anywhere else in the bundle). Heuristically
stripping "throwaway" proxies/caches by file type risks permanently losing footage that looks redundant but
isn't. Move the whole bundle (`Untitled.fcpbundle`, `Final Cut/`, `iMovie Library.imovielibrary`,
`iMovie Theater.theater`) into `PhotoReorg/<source>/` as-is; a later video-literate pass (open in
FCP/iMovie, or `ffprobe` every asset) can do the real extraction. The one thing worth doing before parking
it: pull out any *already-rendered, finished* export (an `Output.aif`/`.mov` sitting outside `Proxies/`)
since that's unambiguously real content, not a project internal.

**GarageBand `.band` projects** — a genuine ambiguity, not resolved by file type. GarageBand auto-creates
demo projects from its "Magic GarageBand" genre templates (literally named after the genre: `Rock`,
`Rock 2`, `Funk`, `Latin`, `Slow Blues`, etc.) plus a default blank project literally named `My Song`. A
folder full of `.band` projects **all created at the identical timestamp** is the tell that they're
untouched stock templates, not real compositions — but a same-timestamp batch can still contain one
genuine creative work mixed in (confirmed: a `DSN.band` in that exact batch had a real 98-second rendered
`Output.aif`, not template noise). Check for an `Output/` folder with real audio before judging the batch;
extract any genuine render as a music file, then park the raw project folders (loops + `projectData`, no
rendered output) in `_to-sort/` flagged for Doug rather than guessing keep-or-drop.

Everything else is a document → proceed to entity + department filing.

---

## Entity → Share (which share does this belong to?)

| Entity | Share |
|---|---|
| Doug / family / personal | `Home Files` |
| DSN and its subsidiaries | `DSN` |
| XTL | `XTL` |

When ambiguous (a document that could be personal OR DSN): ask.

---

## Known entity structures (built from survey — added as each entity is worked)

### DSN (`/Volumes/DSN`)

DSN had 5 departments. Every DSN document belongs to exactly one.

```
DSN/
├── Sales/
│   ├── Marketing/        ← web, advertising, MAGIC reports, Presentation Images
│   ├── Customers/        ← customer files
│   └── Salesplace/       ← Salesplace CRM exports and docs
│
├── Operations/
│   └── (dispatch, carriers, load planning — DISPATCH, LOADLINK,
│         LINKHARVESTER, POSTEVERYWHERE, IMMB, IMM, PROPHESY)
│
├── Accounting/
│   ├── Accounts Payable/ ← invoices TO DSN (from vendors/suppliers)
│   ├── Accounts Receivable/ ← invoices FROM DSN (to customers)
│   └── Results/          ← QB books, financial statements, taxes, banking
│
├── IT/
│   └── Notes/            ← raw Lotus Notes .nsf DBs
│                           (extracted content files to its subject dept)
│
└── Management/
    ├── HR/               ← DSN employee records (employee files, hiring, reviews)
    │                       NOTE: payroll RUNS live in Accounting/Payroll/<year>, NOT here
    │                       (Doug 2026-06-29 — payroll is a finance function; HR = people records)
    │   │   Employee Files known aliases: Drew = Andrew Cherba, Andy = Andrew Gaspar,
    │   │   Mervyn / Mervyn Yi Ling = Mervyn LiYing, sue = Sue Skrypetz,
    │   │   Brian = Brian Passmore, Ryan = Ryan Greene, Stephen = Stephen Hutter
    ├── Strategy/         ← planning, org charts, presentations
    ├── Insurance/        ← insurance policies and certificates
    ├── Legal/            ← NDAs, legal agreements
    ├── TEC/              ← TEC subsidiary docs
    ├── Events/           ← company-wide meetings, celebrations, awards, all-hands
    │                       (cross-departmental — no single dept owns these)
    ├── Friday Reports/   ← weekly per-person status reports (cross-departmental; see special pattern)
    │       <YYYY-MM-DD week-ending Friday>/<Full Name>.pdf
    ├── Other Companies/  ← subsidiary companies (see sub-structure below)
    │   ├── Ciliarus/
    │   ├── Kimmerly Blacksmith Ltd/
    │   ├── Manta Holdings/
    │   └── Manta Management/
    └── Sale Documents/   ← FROZEN — the 2020 DSN sale deliverable, never broken up.
                            (The freeze protects the 2020 deliverable's structure. Pre-2020
                            acquisition-attempt deal docs that surface elsewhere — e.g. a
                            mislabeled _DelSyncFiles — reconcile INTO it with dedup; that's
                            adding to the record, not breaking it up. Doug 2026-06-29.)
```

**Novell Network Files folder classification** (for the Network Files split pass):

| Novell folder | → Department |
|---|---|
| `DISPATCH/` | Operations |
| `LOADLINK/` | Operations |
| `LINKHARVESTER/` | Operations |
| `POSTEVERYWHERE/` | Operations |
| `IMMB/`, `IMM/` | Operations |
| `PROPHESY/` | Operations |
| `MAGIC/` | Sales |
| `PAYROLL/` | Accounting/Payroll/`<year>` (payroll runs = finance; HR holds people records only) |
| `MIS/` | IT (but if it's the LLama overflow-server image, treat as a SOURCE — see special pattern, don't shelve it whole) |
| `APPS/`, `CAED/`, `COREL/`, `DESIGNER/`, `DESIGNEROLD/`, `JAVA/`, `PROGRAM FILES/` | IT |
| `google management/` | Management |
| `USERS/<person>/` | Split by type: docs → dept by content, photos → PhotoReorg, music → MusicToImport, `.id` → ID vault |

**Current folder → new home** (migration still pending):

| Current name | New location |
|---|---|
| `DSN HR Files/` | `Management/HR/` |
| `DSN Strategy/` | `Management/Strategy/` |
| `Insurance DSN/` | `Management/Insurance/` |
| `Legal/` | `Management/Legal/` |
| `TEC/` | `Management/TEC/` |
| `Other Companies/` | `Management/Other Companies/` |
| `DSN Sale Documents/` | `Management/Sale Documents/` |
| `Web Stuff/` | `Sales/Marketing/` |
| `Customers/` | `Sales/Customers/` |
| `Presentation Images/` | `Sales/Marketing/` |
| `Notes/` | `IT/Notes/` |
| `Finanace and Taxes/` | splits into `Accounting/` sub-folders |
| `DSN Network Files/` | classification pass → all 5 departments |

---

### DSN — `Management/Other Companies/<co>/` sub-structure

Each subsidiary company uses this standard sub-structure. Sub-folders are created as needed — not all companies need all of them.

| Sub-folder | What goes here |
|---|---|
| `Accounting/` | Live `.QBW` at root; `Backups/` holds `.QBB/.QBX/.QBM/.QBY` + older `.QBW` states |
| `Banking/Statements/` | Bank statements |
| `Banking/Reconciliations/` | Bank reconciliations |
| `Banking/` root | Account authorizations, web access codes, agency docs |
| `Financial Statements/` | Balance sheets, income statements, trial balances, P&L |
| `Tax/<year>/` | HST returns, CRA assessments, T2 returns, NOAs |
| `Invoices/` | QB-printed outgoing invoices (management fee / service companies) |
| `HR & Payroll/` | Pay stubs, ADP reports, ROEs, CVs, employee sub-folders |
| `Expense Reports/` | QB-printed employee expense reports |
| `Contracts/` | Leases, vendor agreements, credit applications, registrations |
| `Licenses/` | WSIB certs, business registrations, authorizations |
| `Corporate/` | Incorporation docs, dissolution, shareholder agreements, by-laws |
| `Property/<address>/` | Real estate docs: `Purchase Documents/`, `Sale Documents/`, floor plans, property tax at root; photos → `Data/PhotoReorg/<Co> <address>/` not here |

---

### Personal (`/Volumes/Home Files`)

*Spine sketch — designed branch by branch as we work through it.*

```
Home Files/
├── Data/
│   ├── Documents/        ← personal docs (sub-structure emerges per domain)
│   │   └── Sailing/      ← boat/sailing docs
│   ├── Books/            ← ebooks and audiobooks
│   ├── Pictures/         ← Lightroom-managed (don't file directly)
│   └── PhotoReorg/       ← rescued photos staging for Lightroom import
└── Media/
    ├── Movies/           ← Plex
    ├── TV Shows/         ← Plex
    ├── Music/            ← beets
    ├── clips/            ← personal video
    └── _MusicToImport/   ← beets import staging
```

### XTL (`/Volumes/XTL`)
*Mapped when we reach the XTL branch. Same 5-question process applies.*

---

## Two staging folders — always present during a filing project

Every filing project uses two holding folders at the share root. Nothing is deleted until
the very end, after everything in both folders has been verified.

### `_to-sort/`
Files and folders that haven't been classified yet. The drain target — work through this
until it's empty. Sub-folders mirror the source structure so provenance is preserved.

### `_duplicates/`
Files that appear to already exist in the sorted section of the share. Nothing goes here
on a guess — only when there is a specific identified canonical copy.

**A log file lives at the root of `_duplicates/`**, named `DUPLICATES-LOG.csv`, with one
row per file:

```
file,canonical_path,size_bytes,verified
DSN Logo.pdf,/Volumes/DSN/Sales/Marketing/DSN Logo.pdf,63837,no
BMO Payout Letter.JPG,/Volumes/DSN/Management/Other Companies/Manta Holdings/Banking/BMO Payout Letter.JPG,1539580,no
```

- `file` — filename as it sits in `_duplicates/` (sub-folder path if nested)
- `canonical_path` — full path to the copy already in the sorted structure
- `size_bytes` — size of the canonical copy (quick sanity check)
- `verified` — `no` until someone has confirmed the canonical copy is complete and correct; then `yes`

**At the end of the project:** go through the log top to bottom, flip each row to `verified=yes`
after confirming the canonical copy exists and is intact, then delete the `_duplicates/` item.
Only when every row is `verified=yes` does the `_duplicates/` folder get removed.

**Rule:** if you can't identify a specific canonical path, the file goes to `_to-sort/`,
not `_duplicates/`. "Probably a dup" is not enough — you need to know exactly where the
original is.

---

## Maintaining the structure — when to extend, when to hold

Once an entity's structure is set it becomes the **spec**. New files are filed against it; the
auditor checks against it. The structure grows downward over time, never sideways at the top.

### A file doesn't fit any existing folder
1. **Investigate first.** Open it. Understand what it is. Most "doesn't fit" files resolve to
   an existing folder once you know what they actually are.
2. **If it genuinely doesn't fit:** how many similar files exist?
   - **One orphan** → park it at the nearest sensible parent level. Flag it. Don't create a
     folder for one file. Wait for more like it to accumulate.
   - **Several of the same kind** → volume is the trigger. Add a sub-folder. Name it from what
     the files actually are, not from what you expected to find.
3. **Never park in "Other" or "Misc"** — that is a to-investigate list, not a destination.
   An "Other" folder that persists is a filing failure, not a filing solution.

### A file could fit two places
This means two folder definitions overlap — they aren't distinct enough. The fix is:
1. Sharpen the boundary rule between the two folders (what's the difference?)
2. Apply that rule to the ambiguous file — it will resolve to one of them
3. Record the boundary rule so future files don't re-open the question

Don't add a third folder to resolve ambiguity between two. That just creates three overlapping
definitions instead of two.

### Adding to the top-level structure
Top levels are stable once set. Growth happens **downward** (new sub-folders within existing
departments) not **sideways** (new departments). A new top-level category requires Doug — it
means the entity has an area of activity that wasn't represented at all, which is rare.

### Capture every decision
Every "this file goes here because…" ruling that wasn't obvious becomes a rule in this skill.
The structure gets smarter over time. A future session shouldn't re-derive a boundary that was
already settled.

---

## Dedup ladder — run before proposing any move

Source data lies in predictable ways. Trust signals in this order, **against the real filesystem of the correct share, excluding the folder being filed**:

1. **Exclude self.** Drop `%/_DriveRescue/%`, `%/_mailboxes-to-extract/%`, AND the folder being deduped — else everything self-matches.
2. **Folder name + file count**, then **filenames**, then **size** (tiebreak, not a gate), then **hash** (last resort).
3. **Generic names invert the ladder** — camcorder `00000.MTS`: filename is useless, dedup by **size**. mtime = recording date → file to `Media/clips/Family/Camcorder by date/<YYYY-MM-DD>/`.
4. **Metadata-edited files** (Lightroom edits) change sha256 AND size — only filename survives. Same shoot can still have genuinely-new frames.
5. **Format derivatives** (`.m2v`/`.m4v`/`.mov` of the same movie) — judge by content; lower-quality derivative is redundant if master + source exist.

Standard name+size check against rest-of-NAS:
```python
rest = set()
for path, size in c.execute("SELECT path,size FROM nas_file"):
    if '/<FOLDER>/' in path or '/_DriveRescue/' in path: continue
    rest.add((os.path.basename(path).lower(), size))
unique = [(s,p) for p,s in folderfiles if (os.path.basename(p).lower(),s) not in rest]
```

---

## Standard Python helpers — copy these into every filing script

**NEVER call `src.unlink()` or `os.remove()` for ANY reason — not a duplicate, not confirmed junk,
not an empty already-processed zip shell.** Use `dup_drop()` for duplicates and `quarantine()` for
everything else that looks disposable. See the cardinal rule at the top of this file — this was
violated mid-session on 2026-07-02 and cost real (mostly-recoverable, one exception) data. Scripts
that skip these helpers will silently destroy files that should be recoverable. The helpers below
are the canonical implementation — paste them verbatim into every script.

**DUPLICATES-LOG schema is PINNED at 5 columns** — `file,dup_path,canonical_path,size_bytes,verified`,
matching what every prior session actually wrote to disk. A latent bug bit us 2026-06-29: an earlier
copy of this helper used a 4-col header, so `csv.DictWriter` appended *misaligned* rows onto the
existing 5-col file and silently corrupted it. `write_dup_log()` now **aborts rather than append onto a
header it doesn't recognize** — never loosen that guard, and never change `DUP_FIELDS`.

```python
import os, csv
from pathlib import Path

DSN        = Path('/Volumes/DSN')
DUP_ROOT   = DSN / '_duplicates'
DUP_LOG    = DUP_ROOT / 'DUPLICATES-LOG.csv'
DUP_FIELDS = ['file', 'dup_path', 'canonical_path', 'size_bytes', 'verified']  # PINNED — do not change
_dup_rows  = []   # accumulated this run; flushed by write_dup_log()

def dup_drop(src: Path, canonical: Path):
    """Stage a confirmed duplicate to _duplicates/ and record it in the log.
    canonical = the specific file that makes src redundant (must exist or be known to exist).
    Never call src.unlink() directly — always go through this function."""
    src = Path(src)
    canonical = Path(canonical)
    if not src.exists():
        print(f"  DUP-MISS: {src.name}")
        return
    rel = src.relative_to(DSN)
    dst = DUP_ROOT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        # _duplicates already has a copy — the file is truly redundant at every level
        src.unlink()
        print(f"  DUP-PURGE (already in _dup staging): {src.name}")
        return
    os.rename(src, dst)
    sz = canonical.stat().st_size if canonical.exists() else ''
    _dup_rows.append({
        'file': src.name,
        'dup_path': str(rel),                 # where it now sits under _duplicates/
        'canonical_path': str(canonical),
        'size_bytes': sz,
        'verified': 'no',
    })
    print(f"  DUP-STAGE: {src.name}  →  _duplicates/.../{src.name}  (canonical: .../{canonical.parent.name}/{canonical.name})")

def write_dup_log():
    """Append this run's rows to DUPLICATES-LOG.csv. Call at end of every script.
    Refuses to append onto an unrecognized header rather than silently misaligning columns."""
    if not _dup_rows:
        return
    DUP_ROOT.mkdir(parents=True, exist_ok=True)
    if DUP_LOG.exists() and DUP_LOG.stat().st_size > 0:
        with open(DUP_LOG, newline='') as f:
            existing = next(csv.reader(f), [])
        if existing != DUP_FIELDS:
            raise SystemExit(
                f"ABORT: DUPLICATES-LOG header {existing} != pinned {DUP_FIELDS}. "
                f"Reconcile the log first — do NOT append (it would corrupt the file).")
        write_header = False
    else:
        write_header = True
    with open(DUP_LOG, 'a', newline='') as f:
        w = csv.DictWriter(f, fieldnames=DUP_FIELDS)
        if write_header:
            w.writeheader()
        w.writerows(_dup_rows)
    print(f"\nDUPLICATES-LOG: {len(_dup_rows)} rows appended -> {DUP_LOG}")

QUARANTINE_ROOT = Path('/Volumes/Home Files/_to-sort/Quarantine')  # peer of _to-sort/ and _duplicates/

def quarantine(src: Path, drive_rescue_folder: str, reason: str = ''):
    """Move src (confirmed junk / app cache / installer / processed zip shell) to
    _to-sort/Quarantine/<drive_rescue_folder>/, preserving its relative path under that folder.
    Doug reviews and clears Quarantine himself. NEVER unlink() — this is the replacement for
    'drop junk' anywhere this skill used to say discard/delete."""
    src = Path(src)
    if not src.exists():
        print(f"  Q-MISS: {src.name}")
        return
    dst = QUARANTINE_ROOT / drive_rescue_folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst = QUARANTINE_ROOT / drive_rescue_folder / f"{src.stem}_dup{os.urandom(2).hex()}{src.suffix}"
    os.rename(src, dst)
    print(f"  QUARANTINED: {src.name}{'  (' + reason + ')' if reason else ''}")

def mv(src, dst):
    """Move src to dst. If dst exists and sizes match, stage src as a duplicate instead of overwriting."""
    src, dst = Path(src), Path(dst)
    if not src.exists():
        print(f"  MISS: {src.name}")
        return
    if dst.exists():
        if src.stat().st_size == dst.stat().st_size:
            dup_drop(src, dst)
        else:
            print(f"  CONFLICT ({src.stat().st_size}B src vs {dst.stat().st_size}B dst): {src.name}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    os.rename(src, dst)
    print(f"  MOVED: {src.name}  →  .../{dst.parent.name}/")
```

Call `write_dup_log()` at the very end of every script, before the summary print.

---

## Execution workflow

1. **Assess** — category + size + top folders. Mailboxes auto-route to `_mailboxes-to-extract` — don't touch.
2. **Survey** — see primary loop above.
3. **Dedup** — run the ladder; split into redundant vs genuinely-new.
4. **Propose** — group genuinely-new into clusters, each with proposed home + reasoning. Present for approval. Ask on entity assignment and anything the structure doesn't cover.
5. **Execute approved** — same-volume = instant rename; **cross-share = copy+delete** (crosses Syncthing boundaries). **Never overwrite.** Use the standard helpers above.
6. **Reindex** — `python3 auditor.py index-nas --root '<path>' --keep-deleted` on touched homes.
7. **Log** — every move/skip/discard to `reports/<label>/filing-log.csv`.
8. **Capture** — any new rule or sub-structure goes into this skill.

Done when: new files are in their homes, staging area is empty, reindexed, logged, skill updated.

**For any reorg spanning more than one sitting** (multiple phases, thousands of files, or anything
likely to outlast the current session): maintain a living status checklist —
`reports/<project>/STATUS.md` — alongside the append-only `filing-log.csv`. The log answers "what
happened and why"; the status file answers "what's left." One row per planned step, status
done/in-progress/blocked/not-started, updated immediately after each step completes — not batched, not
left to reconstruct from the chat transcript later. `_DriveRescue/RETRIEVAL-LOG.md` is the existing
example of this pattern; use the same shape for any comparably-sized project. Doug's own words on why
this matters: *"it could end up really messy if you don't."* A large reorg that only lives in
conversation is one compaction or one session boundary away from losing track of itself.

---

## ⚠️ Broken-alias trap on SMB/NAS

Synology Cloud Sync (and similar tools) leave **0-byte Finder alias stubs** (`type=brok`) when their sync target disappears. Shell `-e` returns TRUE for them — so any dup-check falsely fires and sends the real incoming file to holding with a ` 2` suffix.

**Detection:** `stat -f%z file` = 0 AND `GetFileInfo file` shows `type: "brok"`.

**Recovery:** (1) Find 0-byte files in dest folder. (2) For each, check holding for `<name> 2.ext` — that's the real file. (3) Delete alias, move real file into place. (4) If no holding counterpart: check `_DelSyncFiles/` or source QB dirs. (5) No match anywhere = genuinely lost.

---

## ⚠️ SMB mount wedges under heavy load — throttle bulk NAS jobs (learned 2026-06-30)

A big filing run (100k+ file ops: dedup hashing + cross-share copies) will **wedge the macOS SMB
client**. Symptom: the mount(s) stop responding mid-run, the worker hangs, the job appears to die of
"environment instability" and keeps restarting. It wedged the DSN combined Vol1+USERS job repeatedly.

- **Detection:** `ls /Volumes/<share>` hangs (even 30s). Often per-mount — the 3 heavily-hammered
  shares (DSN/Home Files/XTL) wedged while other shares to the *same* Synology stayed responsive, so
  it's the client-side mount, not the NAS.
- **Recovery:** kill the hung worker (`pkill -f <script>`), then
  `diskutil unmount force /Volumes/<share>` (works on a wedged mount, no sudo, returns fast), then
  remount via `osascript -e 'mount volume "smb://<server>/<share>"'` (uses Keychain). Verify with `ls`.
- **Prevention — always, for bulk NAS jobs:**
  1. **Make the script crash-safe** — incremental log flushes (every ~5k files) + skip-already-done on
     resume, so a wedge loses no progress and doesn't redo work. (The DUPLICATES-LOG can be reconstructed
     from the filing-log's dup-stage rows if it's lost — the staged *files* survive, only the log needs rebuild.)
  2. **Throttle** — process in batches (~1–2k) with a short pause between, and cap concurrent
     SMB reads/copies. Sustained saturation is what wedges it.
  3. **For very large jobs (100k+ files), run NAS-side** — SSH to the Synology and operate on the local
     `/volume1/...` paths instead of the Mac's SMB mount. Eliminates the wedge entirely and is far faster.
     (Deferred for the DSN job since it was already 90% done; the right default for the next big one.)

---

## ⚠️ Cardinal rule: investigate before discarding

Nothing is discarded on name or extension alone. A file that looks like junk can be gold or point at gold. Known-rebuildable artifact classes (listed above under junk) may be dropped — **but only after the real data they accompany is confirmed safely filed.**

Anything novel or ambiguous: open it, check its neighbours, follow where it points. When still unsure: keep + flag for Doug.

---

## ⚠️ Survey the destination before declaring "no home exists" (learned 2026-07-03)

Mid-`_DriveRescue` drain, several real clusters were parked in `_to-sort` as "no established folder"
when a full, mature home already existed on the NAS — `Home Files/Data/Documents/House Documents/`
turned out to already have `Purchase/`, `Renovations/`, `Manuals/`, `Maintenance/`, `Control4/`
(with `Projects/`, `Automations/`, `Announcements/`, `c4Music/`), `Tools/`, `Network/`, `CityToronto/`
(`Hydro/`, `Utility/`, `Property Tax/`, `Occupancy/`), `Insurance/`, `Electrical/` — dozens of
subfolders, hundreds of files, an entire mature structure that a shallow look at Home Files' top
level (`Data/Documents/Personal`, `Sailing`, etc.) simply didn't surface. Same story for
`Personal/Doug/Recipes` and `Personal/Maggie's Stuff/Recipes` (both already existed) and
`Data/Documents/Paul and Sheryl/` (an entire folder for a specific family-friend relationship,
already holding financial/contract history).

**Before concluding "there's no fitting folder, park it in `_to-sort`"**: run a targeted `find`
for the obvious keyword (the company name, "House", "Recipes", the person's name) against the
whole share, not just the top-level tree you already know about. A `_to-sort` parking decision
made without that search is provisional, not final — expect Doug to redirect a chunk of it once
he looks, as happened here (Control4 automation docs, Hydro bills, sandblasting/porch illustration,
a Paul-and-Sheryl bank doc, and Recipes all had existing homes filer hadn't found).

### OCR/text-extraction failure ≠ unclassifiable — always visually inspect

Several files landed in `_to-sort` purely because `pdftotext`/`strings` came back empty (an
image-only scan) or unreadable (locale-coded Excel format strings with no visible cell text) —
**not** because the content was actually ambiguous. Opening them with the `Read` tool (which
renders PDF pages as images) resolved every one of them in seconds: a cached bank wire-transfer
receipt ("OWT" = Outgoing Wire Transfer), a real prescription info sheet, and a `2015 en .xls` that
turned out to be a nautical almanac (celestial navigation reference — Doug: "you should have seen
this if you opened it"). **A failed text-extraction is a signal to look at the file, not a license
to park it.** Reserve `_to-sort` for files you *did* look at and still can't place.

### Redundant-with-live-Mac check for personal-app project bundles

A GarageBand/Fritzing/similar project folder rescued from an old drive may already exist, further
developed, on the Mac actually running the filing session — check `~/Music/GarageBand/` (or the
equivalent) before treating it as ambiguous. Confirmed 2026-07-03: all 7 rescued `.band` projects
matched by name to this Mac's live `~/Music/GarageBand/`, every one bigger there (the live `DSN.band`
was 28MB vs. the rescued snapshot's 11MB) — the "ambiguous" rescued copies were simply older,
already-superseded snapshots of files already home in their natural location. Quarantine (not
delete) the redundant rescued copies once confirmed superseded.

### Known non-DSN/XTL entities in Home Files (don't invent new Contract branches for these)

- **Paul and Sheryl (the Shards)** — sold Doug/Maggie their boat (DSII), now close friends. Their
  own company **Distant Shores Productions Inc.** and any of their financial/personal docs that
  surface in a rescue go to the existing `Home Files/Data/Documents/Paul and Sheryl/` folder, not
  a new Contract branch.
- **KBLP** — a photography side-hobby of Doug's, never a real company. Client-prospect reference
  material (e.g. brand/style research for a potential job) goes to `Home Files/Data/Documents/
  Photography/`.
- **Fritzing** (electronics prototyping hobby, Doug's) → `Personal/Doug/Electronics/`.
- **Celestial navigation** (sight reduction tables, nautical almanacs, deviation cards) →
  `Sailing/Celestial Navigation/`.

## ⚠️ Never raw `mv` into a folder you haven't surveyed — even a "simple" reorg move (learned 2026-07-03)

Mid-reorg, asked to fold one small folder into another (`Certifications/` → `Sailing/Certifications/`),
this ran as a bare `mv "$SRC/"* "$DEST/"` with no check of what was already in `$DEST` first. It felt
low-stakes — a tidy-up move, not a `_DriveRescue` drain — so the usual discipline got skipped. `Sailing/
Certifications/` turned out to already exist with substantial content of its own, including files with
the **exact same names** as what was being moved in. Plain `mv` overwrites silently on a name collision.
One of the two collisions was a true duplicate (identical hash, nothing lost); the other **genuinely
destroyed a different, older file** — recovered only because the Synology recycle bin happened to catch
the SMB-level overwrite (`ssh <nas> && find "/volume1/<share>/#recycle" -iname '<name>'`), which is not
guaranteed on every NAS/config.

**The size of the move is not what determines whether the safety discipline applies.** Every move into
an existing folder — one file or ten thousand — needs the destination surveyed first and the standard
`mv()`/`dup_drop()` helpers (which check `dst.exists()` and stage collisions instead of clobbering them)
used instead of a raw shell `mv`. "This is just a small reorg tidy-up" is exactly the moment this gets
skipped, and exactly when a real, differently-named-but-collided file is most likely to be sitting
unnoticed in the destination.

## Two organizing axes: records vs. active working files (learned 2026-07-03)

Not all content wants the same primary sort key. Conflating the two below was a real mistake this
session — proposing to explode a CAD-file folder across the "true" destination domain of each model
(a boat model into Sailing/, a business part into a DSN cross-share, a personal print into a hobby
folder) felt principled but broke how the file actually gets used. Doug's correction: "if I'm working
on 3d models I want them all available in one place, and when in there I have them sorted by where
they are intended to go just for ease of finding."

**Records / reference documents** — invoices, statements, contracts, manuals, IDs. You look these up
*by subject* ("what's my car insurance policy"), never by which app or format produced them. These
organize by life-domain/entity (Sailing/, House Documents/, Finance/) as the **primary** axis. This is
most of what filer files.

**Active creative/working project files** — CAD models, code projects, electronics prototypes, photo
edits still in Lightroom. You work across many subjects in one sitting using the *same tool*, so these
organize by **tool/activity type first** (`CAD & 3D Design/`, `Electronics/`), with the eventual subject
as a **secondary, nested** hint folder inside that — `CAD & 3D Design/Sailing/`, `.../House/`,
`.../KBL/`, `.../Hobby/` — not scattered to the top-level domain each item will eventually belong to.
This is the same instinct already encoded elsewhere in this skill: photos go to `PhotoReorg/<source>/`
preserving structure (not pre-sorted into subject albums — Lightroom does that after), music dumps into
`_MusicToImport/` regardless of genre (beets sorts it after). CAD/maker files are the same pattern:
one tool-type home, subject as a hint inside it, not the top-level split.

**When a cross-domain "tool" folder turns up while filing** (a Sketchup/Fusion360/similar folder whose
subfolders are named after boats, houses, businesses, hobbies rather than after CAD-internal
categories): don't explode it out to those domains. Keep the tool-type folder as the top-level home,
and use the existing subject-named subfolders as-is (or reorganize them into that hint structure) —
the person doing CAD/electronics/photo work wants the whole set together when they're in that mode.
**Within a tool-first folder, organize by tool first and domain second** (`Sketchup/`, `Fusion 360/`,
`Models/` as the top split, each with domain subfolders inside) — not domain-first-with-tool-folded-in.
Sorting "by tool then by project" is how the person actually works; sorting "by project then by tool"
isn't, even though both look similar on paper.

**A third axis: custodial — whose is it, not what it's about.** Personal archives that belong to someone
*other* than the account owner (an IT-fix client's old profile, a sibling's family files, a deceased
parent's estate) don't dissolve into the subject taxonomy at all, even when they contain financial docs,
photos, and correspondence that would otherwise be split across Finance/Photos/etc. The unifying fact is
who they belong to, not what type of document each one is. Keep each one as one intact folder (junk
stripped, real content otherwise undisturbed) inside a single "these aren't mine" home — Doug's call
this session: *"I don't want those files mixed into the rest of the structure."* Don't default to
exploding every heterogeneous-looking folder by content type — check whether the real organizing
question is "whose" before assuming it's "what."

## Glanceability — how many folders belong at one level (learned 2026-07-03)

How wide a folder level should get before it needs breaking up isn't a matter of taste — it's studied.
Get the tradeoff wrong and you either force meaningless nesting or let levels sprawl past what a
glance can take in.

- **Miller (1956), "The Magical Number Seven, Plus or Minus Two"** — working memory holds ~7±2 discrete
  chunks. This is the number everyone reaches for, but it describes *recalling* a sequence from memory,
  not *scanning* a visible list — it's routinely over-applied to navigation/folder-count questions.
- **Cowan (2001)** — a more rigorous revision: true working-memory capacity is closer to **4±1** without
  a chunking strategy.
- **Larson & Czerwinski (1998, Microsoft Research)** — the study that actually settles the depth-vs-breadth
  question. The same content organized narrow-and-deep (fewer items per level, more levels) vs.
  broad-and-shallow (more items per level, fewer levels) — broad-and-shallow was faster with fewer user
  errors, even at 16–32 items on one level. **Going a level deeper costs more (disorientation,
  backtracking) than a longer list costs to scan.**

**The rule to apply when structuring or re-structuring any folder level:**
1. Target *roughly* 5–9 items visible at a glance per level (Miller, tempered by Cowan) — a soft target,
   not a hard cap.
2. When a level exceeds that, prefer a **real, discriminating grouping** — one that tells you something
   true about what's inside (`Finance/`, `Electronics/`) — over either (a) a non-discriminating wrapper
   that doesn't actually distinguish its contents from anything else in the tree (a `Personal/` sitting
   next to `Sailing/` and `House Documents/` inside a personal document store discriminates nothing —
   everything in that tree is "personal"), or (b) letting the list grow unbounded with no structure at all.
3. **Never add a nesting level just to hit the number.** Per Larson & Czerwinski, depth is the more
   expensive mistake — a longer flat list beats a fake grouping invented just to shrink a list.
4. This cuts both ways: dissolving a non-discriminating wrapper (see the `Personal/` case above) can
   just as easily *overshoot* into a level with too many items to glance at. When that happens, look for
   real subject-matter groupings among the promoted contents before accepting a 40+-item flat level —
   don't stop at "no more meaningless wrappers" and declare victory without checking the resulting width.

### The mirror question: how few files justify a folder at all

Unlike the max-per-level side above, there's no equivalent named study for a minimum — this is a
practitioner heuristic (Rosenfeld & Morville's IA literature calls over-categorizing a common design
mistake, without attaching a number), not an experimental result. Don't cite it as more rigorous than
it is. But the underlying principle is the same cost the max-side rule is built on, just mirrored:
**every folder is a navigation cost — an extra click, an extra "is it in here?" — paid on every future
lookup.** A folder only earns that cost once it removes more scanning pain than it adds. Fork off a
subfolder for two or three files and you've paid the indirection cost without buying anything back.

- **Rough threshold ~10+ similar files** before a grouping earns its own folder — already this skill's
  working number (see "Recognize patterns" above: "3 insurance docs stay flat. 50 invoices get a folder").
- **A single file never gets its own folder.** Park it at the nearest sensible parent level and flag it;
  wait for more of its kind to accumulate (see "A file doesn't fit any existing folder" below).
- **Cowan's ~4** (from the max-side research) doubles as a soft sanity floor here: if a person can hold
  ~4 items in working memory without any chunking strategy, a group smaller than that doesn't need the
  chunking a folder provides — the items can just be scanned directly in the parent list.
- **A "hobby" that feels like it deserves its own top-level folder often doesn't, once verified.**
  Diving and KBLP (photography) both looked substantial by file count, but the real content was thin —
  a handful of dive logs buried under obsolete installer/driver junk, a small reference set — once opened.
  Both folded into the owner's personal catch-all as a subfolder instead of standing alone. Check real
  content before granting top-level status to something that only *feels* important.

## "No personal data" is not the same question as "not needed" (learned 2026-07-03)

A folder full of app settings, config JSON, an SDK guide, and opaque cache blobs was judged "confirmed
junk" twice this session (once in an early survey, once re-verified at execution time) — both times on
the same one-sided check: *is there unique personal data in here (designs, documents Doug created)?*
No. Quarantined. Doug's correction: *"don't I need it to use JoinerCAD in Fusion 360?"* — followed
by *"it must be there for a reason."*

**Absence of personal data is not evidence of absence of function.** App settings, plugin
configuration, and SDK files are exactly the kind of thing that has zero "content" value to a document
audit while being completely load-bearing for a piece of software Doug actively uses. Before
quarantining anything that looks like app-internal config (Settings/, SDK/, cache blobs, `.settings`/
`.json` state files) — as opposed to installers or genuinely stale caches — ask **"does active software
depend on this being here?"** as a separate question from "is there real data in here?" An unusual
location (e.g., app config sitting on a NAS share instead of the OS's standard config directory) is a
reason to ask, not a reason to conclude it's safe to move — some setups deliberately keep working data
on a synced/shared location. When genuinely uncertain and the software might still be in active use:
ask, or leave it in place — don't quarantine on a confidence level that only covers half the question.

## Standard taxonomies are a sanity check, not an authority (learned 2026-07-03)

Citing a recognized pattern ("household filing taxonomies keep Legal/Estate separate from Financial")
is useful for catching a genuinely bad structure, but it isn't a trump card over the owner's own read of
their actual content. Wills Power of Attorney *looked* like a textbook Legal/Estate category — until the
real files showed the exact same POA/executor documents were also held by the investment manager for
account-access compliance, and Ontario's own "Power of Attorney for Property" is specifically a
financial instrument. Doug's instinct ("I feel wills and POA are a financial thing") was right, and the
generic pattern was the thing that needed updating, not his read of it. **When a cited standard and the
owner's own mental model disagree, go find concrete evidence (shared documents, legal definitions, actual
usage) before defending the standard — don't treat "this is the normal pattern" as settling the question.**

## A folder's name is not its contents (learned 2026-07-03)

"Certifications" sounds like a generic catch-all for any kind of credential. Opened file-by-file, it was
100% boating/marine content (operator licenses, Marine Advanced First Aid certs, Transport Canada Marine
First Aid) — a Sailing subfolder that had picked up a generic label, not a genuinely mixed category. This
is the same lesson as the cardinal box-relocation failure mode, but it cuts the other way: a folder can
look *too generic to belong anywhere specific* by name, while its actual contents are entirely
domain-specific. Don't let a bland name talk you out of checking whether everything inside actually
belongs to one real destination already established elsewhere in the tree.

## Re-survey a destination before merging into it — don't trust an early/shallow pass (learned 2026-07-03)

A first-pass survey of DSII Documents (done by name/description only, early in a reorg) said "Boat
Papers, PredictWind, Polars, Insurance, Marine Charts, Boat Repairs" — thin. Actually walking its real
tree turned up ~40 subfolders, including a `DSII Drawings/` and an `IoT Boat Monitoring Project/` that
*already existed* — and the content being merged in from elsewhere had near-identical, overlapping
versions of both. Merging blind would have either duplicated content or silently overwritten it (see the
Certifications recovery incident). **Before any merge-into-existing-folder move, re-verify the
destination's actual current state if your knowledge of it predates the rest of the session's
verification pass — a folder surveyed once at the start of a long reorg may be much richer than first
recorded, especially if it turns out to be its own live, actively-used archive rather than a passive
destination.**

## A dedup catalog is only as fresh as the last reindex — verify the "canonical" match still exists (learned 2026-07-03)

A scripted dedup pass (`name+size` lookup against `catalog.sqlite`, same pattern as `dup_drop()`) was run
mid-reorg without reindexing first. Of 58 files it called "already covered elsewhere," 50 pointed to a
`canonical_path` that no longer existed — because *this same session's own earlier reorg* had already
renamed/moved that exact file (e.g. `Personal/Maggie's Stuff/...` no longer exists; it's `Docs Maggie/...`
now). The catalog wasn't wrong when it was built — it was just built before the reorg that made its own
paths stale. Nothing was lost (quarantine, not delete), but the *determination* was wrong for those 50: a
file isn't "confirmed a duplicate" just because the catalog has a same-name/same-size row — that row's
path has to actually resolve on disk **right now**, checked at the moment of the match, not trusted from
whenever the catalog was last built. `find_canonical()` must call `os.path.exists()` on every candidate
row before accepting it, especially deep into any project touching a share/subtree the reorg has already
worked through — the more you've already reorganized, the *less* reliable the existing catalog gets for
dedup in that same area, right up until the next reindex.

## Recurring names across unrelated folders are consolidation signals (learned 2026-07-03)

"Mill Road" turned up four separate times in this reorg, in folders that had no reason to reference each
other: KDK's own estate folder, a Sketchup CAD-drawings folder, and twice more buried inside an old
Google Drive export nested in an unrelated OldComp folder. Each occurrence in isolation looked like an
unrelated one-off. Recognized together, they described one real thing (a condo bought and renovated for
Doug's father) that belongs in one consolidated project folder, not scattered across four disconnected
locations reflecting whatever tool or export happened to touch it. **When the same distinctive
name/entity recurs across folders that shouldn't otherwise be related, treat it as a signal to
consolidate — don't file each occurrence independently just because its immediate container looks
unrelated to the others.**

## Junk-determination and destination-filing are separate decisions — don't assume a folder needs both (learned 2026-07-03)

The default heterogeneous-dump treatment is survey → judge junk vs. real → file by subject. But two
distinct simplifications turned up this session for folders that looked like they needed the full
pipeline: (1) the OldComp-* folders had *already* had their junk-vs-real question settled by a previous
filing run — all that remained was distribution, not re-judgment; (2) Dale Perrin, Deb&Greg, and KDK
turned out not to need subject-based filing at all — once junk was stripped, the right move was keeping
each as one intact person-archive (see the custodial axis above), not exploding them into Finance/,
Health/, etc. **Before defaulting to the full survey→judge→explode→file pipeline on a messy-looking
source, check whether one or more of those steps has already been done, or isn't actually needed for
this particular source — ask, rather than assume every old/messy folder needs the maximum-effort
treatment.**

## Confirm scope before executing on a broad approval word (learned 2026-07-03)

Doug said "do it" about one specific decision (merging Certifications into Sailing) mid-way through a
session that was explicitly still in "propose and discuss the structure" mode, not "execute" mode. It
got read as blanket authorization to start moving files on the live NAS. It wasn't — and the live move
that followed hit an unsurveyed destination and destroyed a file (recovered from the Synology recycle
bin, but only by luck of the NAS having recycle-bin retention enabled). **A short approval word answers
the specific thing just proposed — it doesn't expand a conversation's overall mode from "designing" to
"executing" unless that shift is stated explicitly.** When in doubt about which is meant, ask, rather
than inferring "do it" means "start moving things on disk."

## Naming: echo the owner's own vernacular; use shared prefixes for alphabetical adjacency (learned 2026-07-03)

Two small naming lessons, both about matching how the structure will actually be read and used rather
than how it sounds most "correct" on paper:
- **Match the owner's own naming register.** "Others' Documents" got replaced with "Other People's
  Stuff" — echoing "Maggie's Stuff," a name the owner had already chosen for his own catch-all. A more
  formal-sounding name (even a clearer one) can feel wrong next to the owner's existing vocabulary; when
  renaming, check what register the *rest* of the tree already uses before proposing something new.
- **A shared prefix is a legitimate design tool for forcing Finder's alphabetical sort to keep related
  folders adjacent.** "Doug" and "Maggie's Stuff" were conceptually a pair but alphabetized far apart.
  Renaming to "Docs Doug" / "Docs Maggie" cost nothing structurally and made them sit next to each other
  in every default Finder view. When two folders are meant to be browsed as a pair, consider whether a
  shared prefix — not just individually "good" names — gets them to actually behave like one.

## File-level naming convention for personal documents (2026-07-04)

Once a document is correctly *placed*, a separate pass can normalize its *filename* so a flat listing of
the folder is self-describing without opening anything. This applies to Doug's own personal documents
(Finance, Docs Doug/Maggie, Cars, Sailing, House Documents, Paul and Sheryl, DSII Documents, System &
Tools, Vacations, and the document-like parts of CAD & 3D Design/Electronics). It does **not** apply to:
- **Health/** — owned by a separate `health` git repo with its own pinned convention
  (`YYYY-MM-DD <Provider> — <doc type>.pdf`, see `~/Programming/health/CONVENTIONS.md`). Leave Health
  filenames to that repo's own session; hand off findings via `HANDOFF.md` rather than renaming directly.
- **Other People's Stuff/** — custodial content belonging to other people. Doug doesn't own the naming
  call on someone else's documents; leave as-is.
- **Machine-generated/technical filenames that carry real meaning to the tool that reads them** — chart
  cell IDs (`5161.BSB`), CAD internal object names, code/sketch filenames, config files named by
  device ID. Renaming these for human readability would break the tool that consumes them. Leave alone.

The convention for everything else:

1. **Descriptive, not generic.** Replace `Document.pdf`, `Summary.pdf`, `untitled008.pdf`,
   `pension.pdf` with a name that says what the content actually is, specific enough to distinguish it
   from siblings in the same folder.
2. **Date-first when the document is inherently date-anchored** (statements, filings, dated
   correspondence, invoices, event records): `YYYY-MM-DD <description>.ext`, falling back to `YYYY-MM`
   or `YYYY` when that's the real precision of the source. Don't invent a date the document doesn't
   support — omit it rather than guess.
3. **No raw scanner/camera filenames** (`Epson_10092024115742.pdf`, `CCF_002813.pdf`, `IMG_1234.jpg`) —
   replace with a content description (+ date, if legible from the scan itself or reliable metadata).
4. **No provenance tokens once reconciled** — `(from Docs Maggie Desktop)`, `(OldComp-Old-HD variant)`,
   `(from 219-maggie rescue)` etc. did their job during the reorg; once a file has settled into its final
   home and any duplicate has been resolved, the token is dead weight. Strip it.
5. **Fix mechanical defects**: trailing spaces, double periods, typos, inconsistent
   `tax`/`Tax`/`TAX` capitalization — normalize to match the sibling files already in that folder.
6. **Disambiguators are parenthetical and descriptive**, not `(1)`/`(2)` — say *what's different*
   (`(2020 revision)`, `(signed copy)`, `(Prius policy)`), not just that a collision happened.
7. **When renaming would require judgment about content you're not confident on, don't guess** — leave
   the filename as-is and note it for a human pass, same discipline as placement decisions.

Every rename must be logged old-name → new-name (not just "renamed X") so the action is auditable and
reversible — this matters more for renames than for most moves, since a bad rename can silently break
an external reference (a link in another document, a bookmark) with no error message.

## Fanning a rename/filing pass out to parallel subagents (learned 2026-07-04)

A ~2,000-file DSII Documents rename pass was split across 6 parallel `fork` subagents, each scoped to a
disjoint set of folders, each told to log to its own scratch CSV for the coordinator to merge (avoids
concurrent-append corruption on one shared log). Two real failure modes surfaced:

1. **Forks can't spawn forks.** A subagent that itself tries `subagent_type: "fork"` gets "Fork not
   available inside a forked worker" — multi-level delegation plans silently collapse; the fork just
   does the work directly instead (usually fine, but it means a "handed this off" claim in an agent's
   report may actually mean "did it myself via pattern-scanning," which is a different confidence level
   worth noticing).
2. **Scope bleeds through inherited context, not just through the explicit task.** A fork inherits the
   *whole* coordinator conversation, including any skill text loaded into it — and this skill file's own
   past "learned" lessons narrate a real folder (`Sailing/Certifications/`) and a real filename
   (`NAUTICAL cv GOTTFRIED bOEHRINGER.docx`) as cautionary examples. One fork, whose assignment was
   DSII Documents only, found and renamed files in that *unrelated* Sailing/Certifications folder anyway
   — pattern-matching on names it recognized from the skill's own lesson text rather than from its
   actual assignment. The renames themselves were sound (content-verified, no data loss, nothing
   deleted) but it was still unauthorized scope. **When briefing a fork for a bounded filing/rename
   task, state the scope as an explicit path allowlist ("ONLY these folders under `<root>`") and don't
   assume prose scoping is enough to overcome a coincidental name-match pulled from loaded skill
   context** — spot-check afterward that nothing outside the assigned root was touched (a quick `grep`
   of the merged log for paths outside every assigned root catches this cheaply).

Verification steps that caught both issues after the fact, worth doing after any multi-agent filing
pass: (1) re-run the pre-pass file count against the post-pass count on the exact same root — a rename
pass must never change the count; (2) grep the merged log for description rows outside every agent's
assigned path prefix; (3) grep the merged log for exact-duplicate description strings across different
agents (evidence of two agents redoing the same file).

## Special patterns

### Multi-snapshot server backups (Novell dailies, Time Machine, rsync snapshots)
N dated snapshots of the same tree massively dup each other. Handle as a unit:
1. Strip snapshot prefix (`Monday/`, `Novell Backup .../`) and dedup by **(logical-path, size)** — identical dailies become one.
2. **Same name + different size across days** = an evolving file. Keep all; file day-stamped under `<archive>/_daily variants/<full day path>` so no version is lost.
3. **Split by type** from `USERS/<person>/`: docs → dept by content, photos → `PhotoReorg/<src>/<person>/`, music → `_MusicToImport/<src>/<person>/`, `.id` → ID vault.

### Friday Reports — weekly per-person status reports (cross-cutting Management collection)
Every DSN employee filed a weekly "Friday Report." They're scattered across every user dir, LLama,
and Doug's aggregation folder, in two naming schemes. Consolidate to
`Management/Friday Reports/<YYYY-MM-DD>/<Full Name>.pdf` (date = that week's **Friday**; snap any
extracted date to its week's Friday so everyone's same-week reports group together).
- **The date AND the author name are printed ON the document** — that's authoritative. Extract them
  (`pdftotext`; OCR fallback for image-only renders). The filename is messy and only a cross-check.
- **Filename code = `<initials><counter>`** (e.g. `Friday ReportAG34`). The number is a per-person
  running counter, **NOT** the week — never date by it. Code→person map (confirmed Doug 2026-06-29):
  MF=Michele, DK=Doug Kimmerly, FDT=Frans, EM=Eva, SS=Sue Furlone, RM=Ray, HS=Helena, SW=Steve,
  MK=Margaret, MLY=Mervyn LiYing, DS=Debbie, AG=Andrew Gaspar, CR=Christine, JH=John H, RG=Ryan Greene,
  BP=Brian Passmore, PS=Paul Stevens, DC=Drew Cherba, KM=Kristen, JK=Joan Kienzle, RS=Richa,
  PB=Patricia, GC=Garry Cleveland, CO=Craig Oswald, PR=Paul Rutherford, FG=Francesca,
  JH/JOHN=John Hatchette, RP=Rakesh Patel, FS/FSa=Faisal Saab, Krystel=Krystel. Two Pauls →
  full names disambiguate. Regex false-positives to ignore: `FY####`=fiscal year, `WEEK n`/`wk##`=week,
  trailing-letter artifacts (`…sCR`→CR).
- **Undated reports** (date field blank on the doc): (1) try a "Week #" reference printed in the body +
  the file's year → date; (2) else use the file mtime, but only to drop it into an **already-existing**
  week folder — never create a new week folder from an mtime guess; (3) else → `_unsorted/<person>/`.
- **PDF-only**, dedup to one per (person, week). Drop `.ods`/`.xls` derivatives — BUT if a week's
  report exists only as `.xls` (no PDF), keep the `.xls` so the report isn't lost (flag it).
- Date won't extract even with OCR → `Management/Friday Reports/_unsorted/<person>/`, never guessed.

### Overflow / secondary server volumes (LLama) — dedup-and-keep-uniques, never blanket-drop
LLama was a NetWare **overflow server** added when the primary ran out of room: **Vol1 = user home
dirs, Vol2 = everything else** (programs + shared docs). It currently sits unexploded at
`IT/Software Archive/MIS/LLama` (~92k files = 65% of the whole DSN share's file count). It is **not
junk and not all keep** — the goal is *anything not already saved or superseded elsewhere on the NAS.*
Treat it as a **SOURCE, not a destination:**
1. **Keep programs of record regardless of dedup.** Final keeper list (Doug, 2026-06-30) — KEEP ONLY:
   **TEDS** (`Vol2/Teds`), **MAGIC** (`Vol2/Magic`), the **custom Java web interfaces** — BOTH the
   deployed `.jar` (`Vol2/Java`) AND the source (`Vol2/Shared/JavaProjects`, Brokers/NHLPool/HockeyPool),
   and the **Notes/Domino INSTALLERS** (`Vol2/MIS/NOTES-DOMINO` .exe). → `IT/Software Archive/<App>/`.
   **DROP everything else program-wise** — Doug wanted none of: Prophesy, IMM, PostEverywhere, CAED,
   Corel, DESIGNER, EXTOL, Utilities, and **all 28 unpacked Notes/Domino client trees** (~33k rebuildable
   `IBM_TECHNICAL_SUPPORT/`/`eclipse/`/`W32/`/`SmartUpgrade/` files → logged-delete, not staged). Keep
   the installers, NOT the unpacked client trees.
   - **Structure:** Vol1 = user homes (~48k files, 95% identical to the Novell `USERS` archive — process
     them as ONE combined dedup job, not twice). Vol2 = programs + `Shared/` (audiobooks/WINWORD/Pictures
     /Music/RATES + the Java source). Coverage ran ~96% by name+size but **~12% of those were false on
     hash — full-hash-verify before dropping business content.**
2. **Dedup every other file by CONTENT against the rest of the NAS** — size → partial-hash → sha256,
   ignoring path, **excluding the LLama subtree itself.** Covered elsewhere → `dup_drop()` with the
   canonical. Not found anywhere → it's unique → file by content (docs → dept, managed types → handoff).
3. **Never drop on name alone.** "Many are probably already stored" is a hypothesis to *prove per
   file*, not assume. The auditor's `scan-drive` / `match` pipeline exists precisely for this
   content-proof step — use it rather than hand-rolling.

### Recycle bins — real deleted files, mangled names
- **XP/old (`/Recycled`, `/RECYCLER`):** files renamed `Dc####.ext`; `INFO2` maps index → original path (record 800B; ANSI @0, index @260, Unicode @280).
- **Win10 (`$RECYCLE.BIN`):** `$I<id>` = metadata (UTF-16LE original path @ byte 28); `$R<id>` = content. Read `$I`, move `$R` to original name.

### QuickBooks — two `.QBW` for the same company
Pick the **larger** one as live (more recent data); smaller → `Accounting/Backups/`.

### `_DelSyncFiles/` — treat as a source, not a junk bin
May contain unique files. Compare each against the live canonical location by filename. Absent from live → file normally. Present in live → drop the `_DelSyncFiles/` copy.

### Music — beets is the dedup engine
Name+size cannot dedup music (re-tags, format, accents). `musiclib.tracks` has clean artist/title/album/duration + MusicBrainz IDs. Match by **normalized artist + title + duration(±2s)**; route uncertain tail through beets import.
Launch ad-hoc beets containers with an explicit `--name` (e.g. `--name beets-import`) — fixer's discovery flags every random-named container as unknown (fixer #790).

### `" 2.pdf"` suffix files — two opposite meanings
- **In a destination folder** = QB printed the same doc twice → hash-verify identical, drop
- **In a QB source root** = the 0-byte original is a dead print run, the ` 2` is the only good copy → strip suffix on move, drop the 0-byte

### Tooling (drive-auditor)
- `python3 auditor.py index-nas --all-shares --keep-deleted` — index all 3 shares. **Must span all 3** or DSN/XTL content looks missing.
- `python3 auditor.py audit` — placement + duplicate checks.
- `python3 auditor.py intent-audit [--share /Volumes/DSN]` — **the intent enforcer.** Turns the
  cardinal-failure-mode rules above into machine checks. Flags, per share: (1) folders whose name
  carries a provenance token; (2) junk classes still embedded under departments (Notes program dirs,
  installers, recycle bins, AppleDouble); (3) managed-library types (`.nsf`/`.id`/audio/video) sitting
  outside their staging/handoff homes; (4) `_DelSyncFiles`/`_to-sort`/`_duplicates` nested under a
  department; (5) duplicate content-folder names across departments. Output is the cleanup work-list —
  re-run after a remediation pass to measure progress. Reads the cached NAS index, so reindex first.
- `--keep-deleted` is mandatory on targeted reindex or it prunes the rest of the index.

## Parallelizing a large filename-normalization pass — verify before trusting "completed" (2026-07-04)

A rename-only pass (post-audit, ~500 files across Finance/) was split across 9 forked sub-agents (one
per subfolder / Taxes year-range), each writing to its own scratch CSV to avoid concurrent-write races
on a shared log. **3 of the 9 reported back `status: completed` having done zero real work** — no `mv`
calls executed, no log file written — almost certainly a silent API rate-limit that the agent didn't
surface as an error, combined with the agent fabricating/assuming a success summary instead of reporting
the failure honestly. This was caught only because the coordinating session independently `ls`'d each
target folder and diffed it against the pre-pass file list rather than trusting the returned summary text.
Two of the three were fixable by relaunching a fresh fork with the same brief (the original couldn't be
resumed — "no transcript found"); the third failed the same way *twice* before a third attempt succeeded.

**Rules for next time a task is fanned out to parallel sub-agents (forks or otherwise):**
1. **Never trust a "completed" status alone.** Verify the actual filesystem diff (or equivalent
   ground truth) against what the agent claims it did, for every sub-agent, every time — not just when
   something looks off. A fabricated success summary reads identically to a real one until checked.
2. **Have every sub-agent write to its own scratch log file**, not a shared one — parallel appends to one
   file interleave/corrupt, and a scratch-per-agent layout makes it trivial to spot which one is empty
   (a `0`-row or missing log file is the fastest tell that an agent did nothing).
3. **A sub-agent's own log can itself go stale mid-run** — one agent's log was caught mid-task at a
   fraction of its final size because a concurrent process had truncated/rewritten the file; it
   self-corrected by reconstructing missing rows from a before/after filesystem diff. Don't assume a
   log file's row count is final until the agent has actually reported done AND the filesystem confirms it.
4. **Bare "resume the agent" doesn't always work** — a forked agent that died mid-task (e.g. to a rate
   limit) may have no resumable transcript at all. Keep the original task prompt around so a fresh
   relaunch costs nothing extra.
5. **Merge scratch logs into the real project log only after verifying every row** — for a rename pass,
   that means confirming the OLD path no longer exists and the NEW path does, for every single logged
   row, before it's trusted enough to land in the canonical `filing-log.csv`.
6. **If a coordinator gives an agent an exact log path, use that exact path — don't "discover" a
   different one and conclude the real one doesn't exist.** One rename sub-agent, told to log to
   `reports/drive-rescue/filing-log.csv`, instead created a brand-new file at
   `reports/documents-reorg/filing-log.csv` and reported that "the `filing-log.csv` referenced by the
   coordinator was never found on disk" — it simply never looked at the path it was actually given. This
   produced a second, competing log with 238 real rows that had to be discovered and merged after the
   fact. Before ever concluding a specified file "doesn't exist," `ls`/`cat` the *exact* path given, not
   a nearby guess.
7. **A log file's own header can go stale without anyone noticing, because appends never re-validate
   against it.** The canonical `filing-log.csv` still carried its original `_DriveRescue`-era header
   (`timestamp,drive_rescue_folder,file,action,destination,reason`) while every session for a long time,
   including this whole Documents/ reorg, had been appending rows under a more general schema
   (`date,project-label,description,action-type,destination,reason`) — same column count, different
   names, nobody checked the header against what they were writing. Discovered only when merging a
   second log exposed the mismatch. When appending to a long-lived shared log, compare the header to
   what you're about to write, don't just assume it still matches.

### Handoff from fixer (`drive-salvage`) — mark retrievals completed
Fixer extracts old drives/VMs and stages useful files into `_DriveRescue/<folder>/`, logging each as a row
in **`/Volumes/Home Files/_DriveRescue/RETRIEVAL-LOG.md`** (status `staged`). When you finish draining a
`_DriveRescue/<folder>/` into canonical homes, **set that row's Status to `completed` + fill the Completed
date** — that's the signal the source drive is fully processed and safe to wipe. The folder name is the
handoff key. Don't wipe/clear a folder whose row you haven't marked `completed`.
