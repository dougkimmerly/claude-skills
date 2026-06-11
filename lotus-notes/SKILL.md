---
name: lotus-notes
description: Extract data (calendars, mail, documents) from Doug's 25-year Lotus Notes / HCL `.nsf` archive WITHOUT a working Notes GUI. The Notes Eclipse client is dead on the Win11 host, so extraction runs headlessly through the classic C engine via the COM API on the XPS (55videoserver). Use for ANY "pull X out of an .nsf / read a Notes mailbox / export a Notes calendar / get the old DSN/XTL documents" task, for finding/inventorying NSFs across the NAS, or for mounting NSFs that live inside Parallels VMs. Companion to the [[notes-archive-vault]] project memory.
---

# Lotus Notes / NSF extraction

Doug lived in Lotus Notes for ~25 years (XTL → DSN eras). The archive is preserved as `.nsf` files scattered across the NAS and inside old Parallels VMs. **There is no licensed running Domino server and the Notes GUI client crashes on the Win11 host** — so all extraction is **headless, via the Notes C engine + COM API** on the XPS. This skill is the operating manual for that.

Project context, scope decisions, and the keep/drop list live in the **`notes-archive-vault`** memory — read it for the "why" and current state. This skill is the "how".

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
Most IDs are password-protected. **`Initialize("")` with a blank/wrong password HANGS on a hidden GUI prompt** (kill the stuck `cscript`). To pass the real password without putting it in the transcript:
1. Have Doug save it via Notepad to `C:\NotesData\pw.txt` (just the password, "Save as type: All Files").
2. The script reads it from the file.
3. **`Remove-Item C:\NotesData\pw.txt`** immediately after.

Never echo a password into chat. See [[feedback-never-echo-secrets]].

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

Mail/document extraction follows the same engine pattern (iterate views/documents, pull items, export); document DBs (`xtldocs`, `DSNGENER`, DSN docs) are best fed into the **`imaging-expert`** service rather than re-homed as NSFs.

## Finding NSFs

```bash
# full inventory across the NAS (Synology busybox: no -printf, no strings)
ssh doug@<synology> "find /volume1 -iname '*.nsf' -not -path '*/@eaDir/*' 2>/dev/null"
# count calendar entries in a loose NSF without opening it:
ssh doug@<synology> "grep -a -o ApptUNID '<path>.nsf' | wc -l"   # ApptUNID/CalendarDateTime/StartDateTime markers
```
Key locations: loose files under `/volume1/Home Files/Data/Systems Stuff/Old Computers/…`, `/volume1/DSN/…`, `/volume1/XTL/…`. **Install media:** `…/Install Pgms/Windows/notes/{9.0.0,8.5.1,7.0.3}/`. **Notes IDs:** `…/MIS/Notes ID Files/DSN/` (everyone + `CERT.ID`), plus per-user `…/lotus/notes/data/<name>/user.id`.

## NSFs inside Parallels VMs

Many richest copies live *inside* `.pvm` VMs on the NAS (`/volume1/Home Files/Data/Systems Stuff/Virtual Macines/` — e.g. `MaggieDSN`, `MaggiesOld`, `KBL XP`). Doug's Mac is **Apple-Silicon (M1) → CANNOT BOOT** these x86 VMs, but **can mount their disks read-only** to copy files out:

```bash
# the Home Files share mounts on the Mac at /Volumes/Home Files
open -a "/Applications/Parallels Desktop.app/Contents/MacOS/Parallels Mounter.app" \
  "/Volumes/Home Files/.../<VM>.pvm/<VM>.hdd"
# mounts appear under /Volumes/.PEVolumes/PEVolume{...}  (one per partition)
pgrep -fl PEFSUtil          # shows the mount points + [C]/[D] labels
```
- Mounter over SMB is **slow + flaky**. If it wedges (Explorer running, no PEFSUtil), reset: `pkill -f "Parallels Mounter"; pkill -f "Parallels Explorer"`, then relaunch.
- The PEFS filesystem is **unreliable for recursive `find`** (`bfs:` errors skip dirs) — enumerate top-level dirs, then `ls` each Notes-named dir + its `mail/` subdir directly.
- Unmount: `osascript -e 'tell application "Parallels Mounter" to quit'`.

## Gotchas / recovery checklist
- `ActiveX component can't create object` → you used 64-bit cscript/regsvr32. Use **SysWOW64**.
- `cscript` hangs forever → blank/wrong password prompting invisibly. Kill it, feed the real password via `pw.txt`.
- `INIT_FAIL: wrong password` → returns fast (no hang) when a non-blank password is wrong.
- Notes GUI ("IBM Notes" / `notes.exe`) → **expected to hang on Win11; ignore it, use COM.**
- Garbled accents / `sort: Illegal byte sequence` → it's Win-1252; `iconv` to UTF-8, and use `LC_ALL=C` for byte-wise greps.
- XPS unreachable → it's a headless Plex box; if Jump shows black, a **reboot** restores its display path (Plex auto-recovers). RDP won't help — it's Win11 **Home** (no RDP host).

## Related
- `notes-archive-vault` memory — project scope, keep/drop list, current state
- `homelab-synology` — the NAS where the archive lives
- `imaging-expert` — destination for extracted documents
- `knowledge-architecture` — these archives are *Reference*; import wholesale into a siloed store, don't hand-curate prose
