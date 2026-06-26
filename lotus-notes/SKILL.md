---
name: lotus-notes
description: Extract data (calendars, mail, documents) from Doug's 25-year Lotus Notes / HCL `.nsf` archive WITHOUT a working Notes GUI. The Notes Eclipse client is dead on the Win11 host, so extraction runs headlessly through the classic C engine via the COM API on the XPS (55videoserver). Use for ANY "pull X out of an .nsf / read a Notes mailbox / export a Notes calendar / get the old DSN/XTL documents" task, for finding/inventorying NSFs across the NAS, or for mounting NSFs that live inside Parallels VMs. Companion to the [[notes-archive-vault]] project memory.
---

# Lotus Notes / NSF extraction

Doug lived in Lotus Notes for ~25 years (XTL → DSN eras). **As of 2026-06-12 every distinct database is consolidated into one place: `C:\NotesArchive\` on the XPS** (`primary\` = best copy of each db, `copies\` = other distinct versions, `MANIFEST.txt` = provenance). It's backed up via the unified→restic→USB tiers. The scattered loose originals were deleted; backups (NAS `#recycle`, Novell-backup folders, Time Machine, the VMs) were left intact. **There is no licensed running Domino server and the Notes GUI client crashes on the Win11 host** — so all *reading/extraction* is **headless, via the Notes C engine + COM API** on the XPS. This skill is the operating manual.

Project context, scope decisions, and the keep/drop list live in the **`notes-archive-vault`** memory — read it for the "why" and current state. This skill is the "how".

**Downstream consumer:** the `life-timeline-project` memory + the **`life-timeline` skill** (the data-pipeline side) — Doug's unified life timeline (events→photos/docs/emails across XTL, KimmerlyBlacksmith, DSN, Gmail, **Maggie/MKIMMERL**). This skill is its extractor for the Notes-held sources. Calendar export AND full *mail* ingest (Form="Memo" + bodies + attachments → `mail.message`) are both **proven/done** (XTL via `dougXTL.id`, DSN via `user.id`, **Maggie's MKIMMERL via `MAGGIE_ID_PASSWORD`** — 2026-06-16, source `mkimmerl`/owner `Maggie`, 8,158 msgs; her mail was 3 fragmented copies merged). Attachments now feed the life-timeline's eTicket/folio PDF cost parsers.

> **⚑ CANONICAL EXTRACTORS NOW LIVE IN GIT (2026-06-18):** `~/Programming/dkSRC/apps/archive/pipeline/notes/` — `extract_docs`, `extract_mail`, `extract_cal`, `extract_attach`, `validate_id` (`.vbs`+`.ps1`), `merge.vbs` — moved out of ephemeral `/tmp/dsncal/`. The **Archive platform** (`apps/archive`, ADR 0001) is now the umbrella consumer (domains dsn/kbl/xtl/personal); use it, not `/tmp`, for the current scripts.

## The Mac live client (Aperture Mac) — Doug's working environment

As of 2026-06-13 Doug reads his mail in a **fully-working Mac IBM Notes GUI** on the **Aperture Mac (`192.168.20.219`)** — this, not the headless XPS engine, is the live environment. (The XPS COM engine below remains the tool for *scripted* extraction/inventory and for password/identity diagnostics.)

- SSH (legacy crypto, OpenSSH 7.8 / macOS 10.13): `ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -i ~/.ssh/id_rsa doug@192.168.20.219`.
- **Config = `~/Library/Preferences/Notes Preferences`** (NOT a `notes.ini` in the data dir). Keys: `Directory=`, `MailServer=`, `MailFile=` (Windows-style backslash, e.g. `mail\douglask.nsf`). **Notes rewrites it on quit → edit only while Notes is CLOSED** (`pgrep -f /Applications/Notes.app/Contents/MacOS`); back up as `.bak-<date>` first.
- Data dir = `~/Library/Application Support/Lotus Notes Data/`. **Working dbs must sit at the path the workspace/mail bookmarks expect** (e.g. `mail/douglask.nsf`); a db present only under `Archive/` is invisible to those bookmarks → "can't find database / email".

### Two identities (DSN + XTL) — Switch ID, not Locations
Doug has two identities, each with its own mailbox, **each locally encrypted to that id** (the other id gets `GetDatabase → NULL` — it's encryption, not config):

| Identity | id file | mailbox | msgs | SOPS pw key |
|---|---|---|---|---|
| **DSN** (primary) `CN=Douglas Kimmerly/O=DSN` | live `user.id` | `mail/douglask.nsf` | 7066 | `DOUG_ID_PASSWORD` |
| **XTL** `CN=Doug Kimmerly/O=XTL` | `dougXTL.id` | `mail/dkimmerl.nsf` | 45068 | `XTL_ID_PASSWORD` |

- **Two ways to switch:** (a) **File → Security → Switch ID** → pick id → enter password → open that mailbox. (b) **Location documents** (in `names.nsf`): two Island-type (`LocationType=3`, pure-local) Locations "DSN"/"XTL", each with its `MailFile` AND a **`UserID` field that binds the ID file** — so switching Location switches mailbox *and* identity in one move. Build them by cloning an existing `LocationType=3` Location doc via the engine (`create_locs.vbs`: `CreateDocument`→`tmpl.CopyAllItems`→`ReplaceItemValue` Name/MailFile/UserID/MailType=1, `Save`) on a copy of `names.nsf`, then **rsync the file back delta-only** (it's ~100MB+; only the new docs transfer).
- **Editing the Aperture Mac safely:** the Notes APP runs from `/Volumes/Promise RAID/Restored files/Apps/IBM Notes.app` (NOT `/Applications`) → check running with `pgrep -f "Notes.app/Contents/MacOS"`. Only swap `names.nsf`/`Notes Preferences` while Notes is CLOSED. Old-Mac idle-sleep murders back-to-back SSH (NIC re-sleeps between the slow legacy-RSA handshakes) — raise its sleep timer, `nc -z :22` right before each ssh, or do the whole job in one rsync/ControlPersist session; `caffeinate` over ssh dies with the session.
- **Expired certs do NOT block local reads.** Both certs are long-expired (DSN 09/2019); cert expiry only blocks live-server auth + re-certification. The id's encryption keys never expire — verified, both expired ids opened their mailboxes. (`CERT.ID` for DSN is in the archive if re-certification is ever wanted — unnecessary.)

### Finding which id + password opens an encrypted NSF
Old id *snapshots* freeze the password as-of-snapshot, so the *current* remembered password may fail while an *older* one works. On the XPS engine: `xtl_matrix.ps1` (× `xtl_test.vbs`) tries every candidate password × every id file and reports which combo opens the target NSF; `idmap.ps1` maps id files → identity names; `open_test.vbs` tests whether id X can open db Y. (Saved `/tmp/dsncal/`.) Multiple snapshot copies of one identity are interchangeable (same keys).

### Backup (intermittently-on → PUSH)
`~/bin/notes-backup.sh`: rsync 1 `Archive/`→`notes-archive/`; rsync 2 the rest of the data dir (mail + working dbs + `user.id` + `dougXTL.id` + config, excludes `Archive/`+`log.nsf`)→`aperture-live/` → restic+USB. One-click `~/Desktop/Back Up Notes.command` (adds a restic snapshot); LaunchAgent every 20min when Notes is closed.

## Consolidating / merging mailboxes (proven 2026-06-14)

Doug's mail came in **time-sliced version-copies** (each machine/era kept a different slice; the "current" file is often just the latest slice). Consolidate all copies of one identity's mailbox into a single full-history mailbox:

- **`/tmp/dsncal/merge.vbs` (target, src1, src2, …)** — opens target, builds a `seen` dedup dict from it, then per source: collect docs → dedup → copy. **Dedup key** = `$MessageID`/`InetMessageId`, else `Form + Subject + (Start/Posted/Delivered date)`. Run under an id that opens BOTH target and all sources (e.g. all DSN `douglask` copies open with `DougDSN.id` + the **XTL** password).
- **Iterate with `db.Search("Form=\"Memo\" | Form=\"Appointment\" | …")`, NOT `db.AllDocuments`.** AllDocuments can include deletion stubs / a corrupt doc that throws **`NotesDocumentCollection: Argument has been deleted`** on `GetNextDocument`. Search by content-forms skips them. (XTL merge survived AllDocuments by luck; DSN's `douglask` had a bad entry and failed twice until switched to Search.)
- **Two-phase copy** (collect UNIDs in pass 1, then `GetDocumentByUNID`+`CopyToDatabase` in pass 2) — copying during live-cursor iteration can invalidate the cursor.
- **Overlapping date ranges ≠ duplicate docs — merge EVERY copy.** Dedup handles true overlap; location-variants hold surprising uniques (DSN **Mac** copy added **+5,880** docs the NAS "primary" lacked, and extended mail 2018→2019). Result: XTL `dkimmerl` 2002–2012 (53,637), DSN `douglask` 2010–2019 (24,427).
- **Unlock an encrypted version-copy with the matrix** (`/tmp/dsncal/matrix_locked.ps1` + `locked_test.vbs`): for each id file × each candidate password, init then `GetDatabase` the target (Nothing = locked). Old files are often keyed to a *different/older* id+password than you'd expect.
- **Push a big merged NSF back to the Aperture Mac** with `rsync -a --partial --timeout=180 -e "ssh <legacy opts>"` (delta-only — never full-scp 2–3 GB over the slow legacy-SSH link). Back up the live one first (`cp …/mail/x.nsf …/mail/x.nsf.premerge`), Notes CLOSED, then `md5` both ends to verify byte-identical.

### Other mail sources beyond NSF (for the life-timeline project)
- **Apple Mail imports** (Mac): `~/Library/Mail/V10/<UUID>/Import.mbox/<name>.mbox/` — messages are `.emlx` files in `Data/` subdirs; the `.mbox` itself shows **0 bytes**. Year histogram: `find … -iname '*.emlx' | while read f; do head -80 "$f" | grep -iE -m1 '^date:'; done | grep -oE '(19|20)[0-9]{2}' | sort | uniq -c`. (Found the dead **DSN-Gmail** account this way: 40,098 msgs, native 2020–21, only surviving copy → backed up to `unified/dsn-gmail-mail/`.)
- **Google Takeout**: multi-part `takeout-*.zip` (each part an independent zip). **Synology has no `unzip`** — use `7z` or `python3 -c "import zipfile"`. Mail can be **deselected** at export time (then `Takeout/Mail/` holds only settings JSON, no `.mbox`).

## Structured mail extraction → postgres (`mail.message`, the life-timeline store)

Proven 2026-06-14: extracted 69,965 Notes messages (XTL 48,389 + DSN 21,576) + 20,055 attachments into the shared `mail.message` table for the life-timeline crawler. Recipe (scripts in `/tmp/dsncal/`):
- **Bodies** (`extract_mail.vbs`): `db.Search("Form=""Memo"" | Form=""Reply"" | Form=""ReplyWithHistory""")`; per doc emit a **JSON line** — UNID, `PostedDate`/`DeliveredDate`→`LSGMTTime` ISO-Z, From/INetFrom, SendTo/CopyTo arrays, Subject, `Body` via `GetUnformattedText()` (cap 200k). Write UTF-8 with **`ADODB.Stream` charset utf-8** (emits a BOM — strip line 1 on load). JSON-escape with a RegExp control-char strip (don't loop char-by-char — too slow at 70k docs).
- **Attachments** (`extract_attach.vbs`): per doc, `s.Evaluate("@AttachmentNames", doc)`; for each name `doc.GetAttachment(name).ExtractFile(path)`. Notes UNID = filesystem-safe msgkey. tar on Windows (`tar.exe`/bsdtar, UTF-8) → pull to docker-server → extract into the backup root → restic+USB.
- **Load** (postgres pg16): pipe `CREATE TEMP … ; \copy … FROM STDIN (FORMAT csv, QUOTE E'\x01', DELIMITER E'\x02') ; <data> ; \. ; INSERT…` as **one stdin stream** to `docker exec -i … psql` (NOT `-f` + piped stdin — there `\copy FROM STDIN` reads the *script's* next lines, not your data). Guard malformed lines with `WHERE raw IS JSON` (pg16). Connect as `homelab_admin` (no `postgres` superuser exists here; client-side `\copy`, not server `COPY`).
- **VBScript gotchas:** it's **case-insensitive** → `MAN` and `man` collide ("Name redefined"); declare all `Dim`s once at top; `Option Explicit`.
- **Set `owner` on every insert** (`'Doug'`/`'Maggie'`/`'KimmerlyBlacksmith'` — the *mailbox* person, ADR 0009) or the row lands `owner=NULL` and breaks the per-person views. Multi-copy mailboxes (e.g. Maggie's `MKIMMERL`: 3 complementary-era copies, all decrypt with `maggie.id`) must be **merged deduped first** — they're NOT pre-consolidated despite what a brief may say; extracting one copy drops whole years.
- ⚠️ **`mail.message` is shared by multiple writers — NEVER `TRUNCATE`/`DROP` it** (a Notes load wiped the timeline CC's 40k dsn-gmail rows once). Loads are additive (`ON CONFLICT DO NOTHING`); reload/update one source only via `… WHERE source_system='notes-xtl'` etc. Convention lives in `life-timeline/docs/attachments.md` + `notes-mail-extraction.md`.

## Generic document extraction + credential probing (2026-06-18, DSN/Archive)

Beyond mail/calendar, **whole document DBs** (DSNGENER, DSNLet, SALESMAN, the NAS docs, A_JKNOX) extract via **`extract_docs.vbs`** (`apps/archive/pipeline/notes/`): iterate `db.AllDocuments`, emit form/subject/body/date/attachments JSONL. 5,452 DSN docs loaded this way → `dsn.document` (the Archive corpus path; supersedes "feed to imaging" for that store).
- **`doc.Created` is a Date *variant*, NOT a NotesDateTime object** — format it directly (`If IsDate(d) Then Year(d)&"-"&…`). The `.LSGMTTime` path (correct for *item* DateTimeValues like `StartDateTime`) returns the **1899-12-30 epoch** on a document property — silently dated 498 docs to 1899 before the fix.
- **Body fallback:** if `GetFirstItem("Body")` is empty, concatenate non-`$` text items (`itm.Text`) — catches form-field docs with no rich-text body.

### Cheap credential probe (no full matrix)
Run the proven `extract_docs.ps1` against ANY **dummy** local NSF with a candidate id+password and read the result: **`NULL_DB` = auth SUCCEEDED** (id unlocked, just couldn't open *that* db) · **`Wrong Password` = bad pw** · **`Could not open the ID file` = id path / PATH wrong, NOT a password verdict.** Faster than `matrix_locked` for a few candidates; validated vs known-good `maggie.id`/`DougDSN.id`.

### Notes-id era mismatch (the DSN-mailbox-unlock dead end)
The MIS id repo `…/MIS/Notes ID Files/DSN/` holds **2002/2013-vintage** ids; *current* per-user ids live in home dirs (`USERS/<name>/NOTES/USER.ID`). A later-era password won't open an earlier id copy (a password change re-encrypts the id; old copies keep the old pw) → "Wrong Password" on every copy. Doug's per-person pws (`secrets/home/dsn-ids.sops.yaml`: keys sue/drew/chris/… + a `notes_server` key) are newer and/or **network/email** pws ≠ Notes-id pws → Drew's/Christine's mailboxes stayed locked; Audrey/Mike Frith mailboxes aren't in the backup at all. (The server/admin Notes pw came from the sensitive logins doc on the DSN share — values live in SOPS / that doc only; **never put credential values in skills, memory, commits, or chat**.)

## The one thing that works: headless COM on the XPS

| Fact | Value |
|---|---|
| Engine host | **55videoServer / the XPS 8960** — Doug's home Plex box, x86 Windows 11. IP via NetBox (was `.201`, actually answers on `192.168.20.12`; confirm with `nc -z <ip> 32400`). SSH key auth as `doug` works from Doug's Mac. |
| Notes install | `C:\Program Files (x86)\IBM\Notes\` — **Notes 9.0.0, 32-bit** |
| Scratch dir | `C:\NotesData\` — stage NSFs + IDs here |
| GUI status | **DEAD.** `notes.exe` (Eclipse/Java) hangs "running but not responding" on Win11; `nlnotes.exe` (Basic) won't self-configure. Don't fight it — use COM. |

**Why COM works when the GUI doesn't:** the Eclipse front-end is Java/SWT (incompatible with Win11 25H2). The COM automation (`nlsxbe.dll`) drives the classic **C core** (`nnotes.dll`) — the same engine, no Java — and it runs fine.

### Bitness — the #1 trap
Notes is **32-bit**. You MUST use the 32-bit tools or you get `ActiveX component can't create object`:
- Register: `C:\Windows\SysWOW64\regsvr32.exe` (NOT System32)
- Run scripts: `C:\Windows\SysWOW64\cscript.exe` (NOT System32)

### SSH quoting — the #2 trap
Inline PowerShell/cmd over SSH mangles easily (especially the `(x86)` parens). **Always write a `.ps1`/`.vbs` locally, `scp` it over, and run `powershell -NoProfile -ExecutionPolicy Bypass -File C:\x.ps1`.** Don't pipe complex inline scripts.

## One-time engine setup (idempotent)

```powershell
# comsetup.ps1 — wire notes.ini + register the 32-bit COM backend
$base='C:\Program Files (x86)\IBM\Notes'; $data="$base\Data"
Copy-Item 'C:\NotesData\<the>.id' "$data\<the>.id" -Force
@"
[Notes]
Directory=$data
KeyFilename=<the>.id
NotesProgram=$base
Timezone=5
DST=1
"@ | Set-Content "$base\notes.ini" -Encoding ASCII
Push-Location $base
& "$env:WINDIR\SysWOW64\regsvr32.exe" /s "$base\nlsxbe.dll"
Pop-Location
```

`KeyFilename` selects which **Notes ID** the engine runs as. The ID must have access to the database (for a *local, unencrypted* NSF, any valid ID works; for the owner's own mail, use the owner's ID).

## Passwords — keep them off-chat
Most IDs are password-protected. **`Initialize("")` with a blank/wrong password HANGS on a hidden GUI prompt** (kill the stuck `cscript`). The export script reads the password from `C:\NotesData\pw.txt` on the XPS; the value gets there one of two ways:

**Maggie's ID password is already in SOPS** — no need to ask:
```bash
cd ~/Programming/dkSRC/infrastructure/homelab-secrets
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
PW=$(sops -d --extract '["MAGGIE_ID_PASSWORD"]' secrets/home/lotus-notes.sops.yaml)
# write it to the XPS without echoing, run the export, then delete:
ssh doug@<xps> "powershell -Command \"Set-Content -NoNewline C:\NotesData\pw.txt '$PW'\""; PW=
# ... run export ... then:
ssh doug@<xps> "powershell -Command \"Remove-Item C:\NotesData\pw.txt -Force\""
```
(`secrets/home/lotus-notes.sops.yaml` can hold other Notes-ID passwords too — add `DOUG_ID_PASSWORD` etc. via `sops set` as needed; see the `secrets` skill.)

**For an ID NOT yet in SOPS:** have Doug save it via Notepad to `C:\NotesData\pw.txt`, use it, then **store it in SOPS** (capture into a var off the box, `sops set`, round-trip-verify by hash) so it's there next time, and `Remove-Item` the plaintext.

Never echo a password into chat. See [[feedback-never-echo-secrets]] and the `secrets` skill.

## Verify the engine (before any real work)

```vbs
' comtest.vbs — run via SysWOW64\cscript with the Notes dir on PATH
On Error Resume Next
Dim fso,pw,s : Set fso=CreateObject("Scripting.FileSystemObject")
pw=Trim(fso.OpenTextFile("C:\NotesData\pw.txt",1).ReadAll())
Set s=CreateObject("Lotus.NotesSession") : s.Initialize pw
If Err.Number<>0 Then WScript.Echo "INIT_FAIL: "&Err.Description : WScript.Quit
WScript.Echo "INIT_OK "&s.NotesVersion&" user=["&s.UserName&"]"
```
```powershell
# runner.ps1
$base='C:\Program Files (x86)\IBM\Notes'; $env:PATH="$base;"+$env:PATH; Set-Location $base
& "$env:WINDIR\SysWOW64\cscript.exe" //nologo C:\comtest.vbs
```
`INIT_OK ... user=[CN=... /O=...]` means you're in. An **expired-certificate warning is harmless** for reading local files (only matters for connecting to a Domino server).

## Common task: export a calendar → .ics

```vbs
' core of export_cal.vbs (full working copy was at /tmp/dsncal/export_cal.vbs)
Set db = s.GetDatabase("", "C:\NotesData\<MAILFILE>.NSF")
If Not db.IsOpen Then db.Open "", "C:\NotesData\<MAILFILE>.NSF"
Set col = db.Search("Form = ""Appointment"" | Form = ""Notice""", Nothing, 0)
' for each doc: Subject, Location, StartDateTime, EndDateTime
'   date: Set it=doc.GetFirstItem("StartDateTime"): d=it.DateTimeValue.LSLocalTime
'   format d as YYYYMMDDTHHMMSS ; escape , ; \ in SUMMARY ; UID = doc.UniversalID
' write BEGIN:VCALENDAR / VEVENT blocks / END:VCALENDAR
```
- Notes writes **Windows-1252**, not UTF-8 → convert before import: `iconv -f WINDOWS-1252 -t UTF-8 in.ics > out.ics`.
- Then run the same **noteworthy-events cleanup** used for Doug's calendar: parse VEVENTs, **collapse any SUMMARY appearing >4× to its earliest dated instance** (kills repeated birthdays/anniversaries/payment reminders), sort by DTSTART. Stage the result in `~/Downloads/` for one-click Google Calendar import into a dedicated archive calendar.

Mail/document extraction follows the same engine pattern (iterate views/documents, pull items, export); document DBs (`xtldocs`, `DSNGENER`, DSN docs) now feed the **Archive corpus** (`extract_docs`/`extract_attach` → `load_docs.py` → `<domain>.document` → `ingest.py`; see the **[[archive]]** skill), NOT imaging — supersedes the old "feed to imaging-expert" guidance. **Parked doc DBs (mapped 2026-06-21 — probed all 79 NSFs in `C:\NotesArchive\primary\`, `live_userid.id`+`DOUG_ID_PASSWORD`):** the big rich ones are **ENCRYPTED-LOCKED, not unencrypted as assumed** — `corresp.nsf` (4.3 GB), `Carriers` (2.5 GB), `reports`, `library`, `MISMANUA`, `howto`, `products`, `opport`, `suspects`, `tcorders`, `Concord`, `Financia`/`accounts`, `custcontent`, `DSNDispatchFaxMail` all return `NULL_DB`. **Crack FAILED:** matrix of 14 Doug/DSN/XTL/server id snapshots × 53 passwords (17 SOPS + 36 harvested-from-email) vs `corresp` → 0 opens — the same era-mismatch dead-end as the mailboxes (next section); the encrypting pw is an old DSN-era one we don't hold (or the DSN server id's). **Don't re-run the matrix** — leads are an old pw Doug recalls, or `logins.docx` on the NAS (`/volume1/DSN`, lists DSN pws). **Still extractable now (~15k docs, OPEN):** `GroupCal.nsf` (10,202 calendar), `EmpBen`(1,915, confidential), `MISRequest`(1,485), `emerg`(578), `dgibbons`(392), `adminlet`, `OPERATIO`, `General Procedures`. Full open/locked map + extract path in archive `docs/STATE.md` "Parked".

## Finding NSFs

```bash
# full inventory across the NAS (Synology supports -printf; busybox has no strings)
ssh doug@<synology> "find /volume1 -type f -iname '*.nsf' -not -path '*/@eaDir/*' -not -path '*/@appdata/*' -printf '%s|%p\n' 2>/dev/null"
# count calendar entries in a loose NSF without opening it:
ssh doug@<synology> "grep -a -o ApptUNID '<path>.nsf' | wc -l"   # ApptUNID/CalendarDateTime/StartDateTime markers
```
- **ALWAYS `-type f`.** Eclipse workspace metadata creates *directories* named `*.nsf` (e.g. `Salesplace_5copport.nsf`); `find` without `-type f` returns them, and **`md5sum` HANGS on a directory** (`Is a directory` over busybox blocks). The NAS had 2712 `.nsf` matches but only 1212 real files. Exclude `@appdata/` too (Synology bind-mounts double-count every share).
- **Run heavy work over SSH, not SMB.** SMB-mounted finds (Mac → `/Volumes/...`) are glacial and flaky; the same `find` run *on the host* via SSH is instant. Hosts seen: NAS, this Mac (local), Aperture Mac, 2008 Mac, VMs (qemu-nbd).

**SMB share → real host:** `mount | grep cifs` / `smbutil status <ip>` to confirm which IP serves a share. **Don't assume by elimination** — `.212` looked like the Aperture Mac (live SMB peer) but was a **Control4 controller** (Dropbear, `CONTROL4HOME` workgroup) that ate hours. The real Aperture Mac is `.219`.

**Old Macs need legacy SSH crypto** (and an RSA key — pre-2014 OpenSSH/Dropbear has no ed25519):
```bash
# Aperture Mac .219 (OpenSSH 7.8): -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -i ~/.ssh/id_rsa
# 2008 Mac .216 (OpenSSH 5.2): also -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
#   -o Ciphers=+aes128-cbc,3des-cbc -o MACs=+hmac-sha1
```
To authorize my key when it isn't yet: **mount the Mac's disk (SMB/AFP) and append `~/.ssh/id_rsa.pub` to `/Volumes/<disk>/Users/<u>/.ssh/authorized_keys`** — file is writable as that user over the share. (2008 Mac = AFP `/Volumes/Mac2008Snow`; it had 0 NSFs — pure Final Cut box.)

Key locations: loose files under `/volume1/Home Files/Data/Systems Stuff/Old Computers/…`, `/volume1/DSN/…`, `/volume1/XTL/…`. **Install media:** `…/Install Pgms/Windows/notes/{9.0.0,8.5.1,7.0.3}/`. **Notes IDs:** `…/MIS/Notes ID Files/DSN/` (everyone + `CERT.ID`), plus per-user `…/lotus/notes/data/<name>/user.id`.

## NSFs inside Parallels VMs

Many richest copies live *inside* `.pvm` VMs on the NAS (`/volume1/Home Files/Data/Systems Stuff/Virtual Macines/` — e.g. `MaggieDSN`, `MaggiesOld`, `KBL XP`). Doug's Mac is **Apple-Silicon (M1) → CANNOT BOOT** these x86 VMs.

### Browsing / small files: Parallels Mounter (Mac) — METADATA ONLY
```bash
open -a "/Applications/Parallels Desktop.app/Contents/MacOS/Parallels Mounter.app" \
  "/Volumes/Home Files/.../<VM>.pvm/<VM>.hdd"   # mounts under /Volumes/.PEVolumes/PEVolume{...}
pgrep -fl PEFSUtil                                # shows mount points + [C]/[D] labels
```
- Good for `ls` and file *sizes*. **CONTENT reads of large files HANG** (PEFS wedges; even a 1 MB `dd` blocks). Don't use it to copy a multi-hundred-MB NSF.
- Flaky over SMB: if it wedges, `pkill -f "Parallels Mounter"; pkill -f "Parallels Explorer"`, relaunch, be patient (can take 100s+ and a couple of auto-relaunches).
- Recursive `find` over PEFS throws `bfs:` errors and skips dirs — enumerate top dirs, `ls` each directly. Unmount: `osascript -e 'tell application "Parallels Mounter" to quit'`.

### Copying a real file out: qemu-nbd on docker-server (THE reliable way)
docker-server (`192.168.20.19`) has passwordless sudo, **/dev/kvm**, Docker, and the NAS read-only at **`/mnt/home-files`**. Attach the Parallels disk as NBD and copy just the one file (reads only needed blocks, not the whole 87 GB image):
```bash
# on docker-server, as root:
apt-get install -y qemu-utils ntfs-3g          # one-time
modprobe nbd max_part=8
HDS="/mnt/home-files/Data/Systems Stuff/Virtual Macines/<VM>.pvm/<VM>.hdd/<VM>.hdd.0.{...}.hds"
qemu-nbd --read-only --connect=/dev/nbd0 -f parallels "$HDS"
partprobe /dev/nbd0; lsblk -rno NAME,SIZE,FSTYPE /dev/nbd0   # find the big NTFS = C:
mount -o ro /dev/nbd0p2 /mnt/mvm
cp "/mnt/mvm/Notes/Data/mail/MKIMMERL.NSF" /tmp/out.nsf      # NOTE: Linux NTFS is CASE-SENSITIVE
umount /mnt/mvm; qemu-nbd --disconnect /dev/nbd0
```
- **Case-sensitivity trap:** Linux NTFS is case-sensitive — the on-disk path is `/Notes/Data/mail/...` (capital `Data`). Use `find -type f -iname` to discover real case.
- **nbd reset between VMs:** back-to-back `--disconnect`/`--connect` leaves nbd0 loading **0 B** (no partitions). Between VMs: `rmmod nbd; modprobe nbd max_part=8`, then **verify `blockdev --getsize64 /dev/nbd0` > 0 before mounting** (retry once if 0). If `partprobe` shows no `nbd0pN`, the parallels partition table is unreadable (one KBL XP disk did this) — fall back to Parallels Mounter or skip.
- **Root-owned extracts:** if the extract script ran under `sudo`, the copied files are **root-owned** → a later `scp` as `doug` silently fails to read them. `sudo chown -R doug:doug /tmp/vmextract` first.
- Relay to the XPS via the Mac (`scp` docker-server→Mac→XPS), or add docker-server's key to the XPS (`C:\ProgramData\ssh\administrators_authorized_keys`) for a direct wired push. ~30s per GB.
- Skip the Mac/Linux VMs (no Notes). DANIELS XP was a 2 MB empty stub; KBL Win8/XP had no Notes data.

## Encrypted NSFs (active mailboxes)
Some copies are **locally encrypted** with the owner's ID (active working mailboxes often are; unencrypted *replicas/exports* of the same mailbox also exist and carve fine). Tell-tale: `grep -a -o Subject file.nsf` returns **0** (zero readable strings at all), the body is high-entropy, but the **header is still a valid NSF magic `1a 00 00 04 ...`**. Carving/`strings` is useless on these. **Only the encrypting ID opens it** — run the COM engine with that owner's `.id` + password and it decrypts transparently (e.g. MaggieDSN's 1.16 GB `MKIMMERL.NSF` is encrypted; `maggie.id` opens it). So: encrypted = *more* complete/authoritative, not a dead end — just route it through the engine, never the grep.

## Adding a source / re-consolidating (the 2026-06-12 pipeline)
The archive is built; to fold in a *new* source (e.g. the 2008 Mac if it ever gets Notes, or a found NSF) follow the same shape — all of it ran from `/tmp/dsncal/` scripts:
1. **Inventory** the host over SSH (`find -type f -iname '*.nsf' ... -printf '%s|%p'`).
2. **Classify** data vs system/template (drop `bookmark/names/log/help*/lccon*/*.ntf/...` and `.metadata/.projects` dirs). ~70% is plumbing.
3. **Hash** the data files (run `md5sum` *on the host*, write to a host-local file; an interrupt-able ssh-pipe loop drops). Push the path list via `ssh "cat > /tmp/x"` (Synology SFTP is chrooted — `scp` to it fails).
4. **Dedup by content** across all sources → distinct databases; `primary\` = largest of each name, `copies\` = other distinct versions (name them `<base>__<src><ext>`).
5. **Copy to XPS** (`C:\NotesArchive\{primary,copies}\`) reading source via `ssh cat`/local, scp to XPS, **hash-verify on read**, resumable (skip if dest size already matches).
6. **MANIFEST.txt** — record every original location of every database.
7. **Back it up (the hard gate before any delete):** land the archive in docker-server `/home/doug/backups/unified/notes-archive/` (docker-server pulls from XPS), then run `BKP_RESTIC` — static data inherits restic (Synology repo) + USB Tier-3 for free. See `backup-recovery`.
8. **Verify** every XPS file's MD5 matches a known-good source hash.
9. **Delete LOOSE originals only** — live Notes folders on Macs + loose NAS copies. **Classify keep-vs-delete:** delete only paths NOT under `#recycle` / `Novell Backup` / `Backups.backupdb` (Time Machine) / inside a VM. **Before deleting each file, confirm its content hash is in the backed-up archive** (belt-and-suspenders on irreplaceable data — the fixer CLAUDE.md 73 GB rule).

## Gotchas / recovery checklist
- `ActiveX component can't create object` → you used 64-bit cscript/regsvr32. Use **SysWOW64**.
- `cscript` hangs forever → blank/wrong password prompting invisibly. Kill it, feed the real password via `pw.txt`.
- `INIT_FAIL: wrong password` → returns fast (no hang) when a non-blank password is wrong.
- Notes GUI ("IBM Notes" / `notes.exe`) → **expected to hang on Win11; ignore it, use COM.**
- Garbled accents / `sort: Illegal byte sequence` → it's Win-1252; `iconv` to UTF-8, and use `LC_ALL=C` for byte-wise greps.
- XPS unreachable → it's a headless Plex box; if Jump shows black, a **reboot** restores its display path (Plex auto-recovers). RDP won't help — it's Win11 **Home** (no RDP host).
- `md5sum` hangs on a `.nsf` → it's a *directory* (Eclipse workspace). Use `find -type f`.
- qemu-nbd shows `0 B` / no partitions → reset (`rmmod nbd; modprobe nbd max_part=8`) + `blockdev --getsize64` check.
- `scp` of VM extracts gets nothing → root-owned (sudo). `chown -R doug` first.
- old-Mac SSH `Bad key types` / `Permission denied` → legacy crypto opts + RSA key (no ed25519); authorize via the mounted disk.
- `Could not open the ID file` **even with the correct password** → the Notes program dir isn't on the cscript process's `$env:PATH` (C-engine DLLs can't load). The `.ps1` MUST do `$env:PATH="$base;"+$env:PATH`. This is NOT a password error.
- All extracted dates land on **1899-12-30** → you called `.LSGMTTime` on `doc.Created` (a Date variant). Format it directly; reserve `.DateTimeValue.LSGMTTime` for item values like `StartDateTime`.

## Related
- `notes-archive-vault` memory — project scope, keep/drop list, current state, archive location
- `backup-recovery` — how the archive is backed up (unified→restic→USB); use to add a source
- `homelab-synology` — the NAS where the loose sources lived
- [[archive]] — destination for extracted DSN/XTL documents (the corpus + event pipeline); `imaging-expert` — boat/home document store (separate; converging per ADR 0012)
- `knowledge-architecture` — these archives are *Reference*; import wholesale into a siloed store, don't hand-curate prose
