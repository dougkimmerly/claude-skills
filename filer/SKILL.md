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
Drop these everywhere — they are never business records:
- `._*` AppleDouble sidecars, `.DS_Store`, `desktop.ini`, `Thumbs.db`, `Icon\r`, `.localized`
- QB app data: `.TLG`, `.ND`, `.SearchIndex/`, `_MigrationReport.xml` (READ first — it can reveal other companies), `QuickBooksAutoDataRecovery/`, `Restored_<co>_Files/`, `QuickBooks Letter Templates/`, `<co> - Images/`
- Notes client junk: `.nbf`, `.njf`, `.hst`, `.dmp`, `.ncf`, `.mod`, `Cache.NDK`
- App temp/config: `.ini`, `.tmp`, lock files, crash dumps, `segments.gen`
- **Drop only after the real data they accompany is confirmed safely filed.**

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

**NEVER call `src.unlink()` to drop a duplicate. Always use `dup_drop()`.** Scripts that skip
this helper will silently destroy files that should be recoverable. The helpers below are the
canonical implementation — paste them verbatim into every script.

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
