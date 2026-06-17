---
name: plex
description: The Plex Media Server (55videoServer) that serves the home media library — server address, tokens (owner vs programmatic), library section keys, and the HTTP API for watch history, library listings, and marking watched (scrobble). Includes the load-bearing rule that the LOCAL server API is reliable while the Plex cloud watchlist/Discover API is flaky. Use for anything that talks to Plex directly: tokens, watch history, mark-watched, library queries. The Arr/Kometa pipeline that FEEDS Plex is the `entertainment` skill; picking/rating/recommending is `watch-recommendations`.
---

# Plex (55videoServer)

The single home for how to talk to the Plex server. The media *pipeline* that fills
it (Arr stack, Kometa, franchises) is the **`entertainment`** skill; the
rating/recommendation app that reads it is **`watch-recommendations`**.

## The server

- **55videoServer** — `192.168.20.12` (ethernet, preferred) / `192.168.20.201` (wifi).
- A **Windows** host: `ssh doug@192.168.20.12` drops into `cmd.exe` — wrap commands in `powershell -Command "…"`.
- HTTP API base: `http://192.168.20.12:32400`. **Not directly reachable from the Mac** — go through a homelab host, e.g. `ssh doug@192.168.20.19 "curl … "`.
- The music-library audio-analysis ML worker also runs on this host (RTX 4060) — separate domain (`music-library`), not Plex.

## Tokens

- **Owner token (full read/write)** — `PlexOnlineToken` in the Windows registry. Needed by Kometa and any write tooling; a *read-only* token makes Kometa report "No libraries found / token is read only":
  ```bash
  ssh doug@192.168.20.12 'powershell -Command "(Get-ItemProperty \"HKCU:\Software\Plex, Inc.\Plex Media Server\" -Name PlexOnlineToken).PlexOnlineToken"'
  ```
- **Programmatic token** — the same value lives in SOPS (NOT Bitwarden — retired, ADR 0017):
  - `homelab-secrets/secrets/home/dk400.sops.yaml → PLEX_TOKEN` (dk400 programs incl. `watch_sync`, franchise_sync).
  - `homelab-secrets/secrets/home/watch-rater.sops.yaml → PLEX_TOKEN` (the Shows app).
  ```bash
  export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
  PLEX_TOKEN=$(sops -d --extract '["PLEX_TOKEN"]' ~/Programming/dkSRC/infrastructure/homelab-secrets/secrets/home/dk400.sops.yaml)
  ```

## Library section keys

Movies = **3**, TV Shows = **5**. List/inspect:
```
/library/sections?X-Plex-Token=…                       # all sections + keys
/library/sections/<key>/all?includeGuids=1             # bulk list incl. tmdb:// GUIDs (one call)
```

## API cheatsheet (reach via a homelab host)

```bash
PLEX="http://192.168.20.12:32400"   # PLEX_TOKEN from SOPS, see above

# Recent watch history
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' \
  '$PLEX/status/sessions/history/all?sort=viewedAt:desc&limit=50'" | python3 -c "
import sys, xml.etree.ElementTree as ET
from datetime import datetime
for v in ET.parse(sys.stdin).getroot().findall('Video'):
    d = datetime.fromtimestamp(int(v.get('viewedAt', 0))).strftime('%Y-%m-%d')
    t = v.get('type')
    title = v.get('title') if t == 'movie' else f\"{v.get('grandparentTitle')} — {v.get('title')}\"
    print(f'{d}  [{t}]  {title}')
"

# Movie library (section 3) — <Video>;  TV shows (section 5) — <Directory>
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' '$PLEX/library/sections/3/all'"

# Mark watched (scrobble) — reliable LOCAL API. key = the item's ratingKey.
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' \
  '$PLEX/:/scrobble?identifier=com.plexapp.plugins.library&key=<ratingKey>'"
# Mark unwatched: /:/unscrobble  (same params)
```

Watched status is per **Plex account** — scrobbling with the owner token marks it
watched on the shared owner account.

## ⚠️ The reliability rule (local vs cloud)

- **LOCAL server API** (`192.168.20.12:32400`) — reliable. Use it for history, library
  queries, and marking watched.
- **Plex cloud Watchlist / Discover API** (`discover.provider.plex.tv`,
  `metadata.provider.plex.tv`) — **flaky and undocumented.** Reading the account
  watchlist works, but search→add is unreliable. **Don't build on it.** This is
  exactly why the Shows app keeps its *own* watchlist in Postgres and uses local
  scrobble instead of the Plex watchlist.

## Troubleshooting playback (error `s1001 (Network)` / "won't play")

`s1001` in the web client is a **generic** symptom — it just means the player
couldn't start a stream. The usual real cause is that **Plex can't read the file**,
so it never analyzed it. Diagnostic chain:

1. **Check the item's media metadata.** `GET /library/metadata/<ratingKey>` — if
   `<Media>` shows `container`/`videoCodec`/`width` all empty (and no `<Stream>`
   children), Plex has the file *listed* (it can `stat` it) but **never read its
   contents to analyze**. That's the tell.
2. **Check file permissions on the NAS.** Media lives on the Synology
   (`192.168.20.16`) under `/volume1/Home Files/Media/...`, served to the
   videoserver as the SMB share `\\Blackhole55\Home Files`. Plex reads it over SMB
   as a **non-owner**, so the file must be readable by group/other.
   - Transcoder/Arr output is owned `home:users` mode `0777` → fine.
   - Files **copied** onto the NAS (e.g. from a Mac over SMB/AFP) can land owned
     `doug` mode `-rw--w--w-` (**no read bit for o/g**) → Plex can't read →
     empty media → `s1001`. (2026-06-17: 4 Home-Movies files copied during a
     transcode session had this; `Currans s1e5 BillsBBQ` was the reported one.)
   - Find offenders: `find "/volume1/Home Files/Media/<dir>" -type f ! -perm -o+r | grep -v @eaDir`
   - Fix: `chmod 0777 "<file>"` (matches the tree convention), then re-analyze:
     `PUT /library/metadata/<ratingKey>/analyze` and confirm metadata now populates.
3. If perms are fine, confirm the file itself is sound with `ffmpeg -i` on the
   Synology (`/usr/bin/ffmpeg`; note **no `ffprobe`** on that box, and its build
   lacks an h264 *decoder* so "Decoder not found" is harmless — look at the
   `Input #0 ... Duration/Stream` header lines instead).

## Recovering a downed Plex Media Server (Windows host)

Since 2026-06-17 (ADR 0028) PMS runs **headless** from the Task Scheduler task
**`PlexMediaServer-Headless`** — runs whether logged on or not, as `doug`,
`LogonType=Password`, `RunLevel=Highest`, in **session 0**. Triggers: `AtStartup`
+ a 5-min watchdog that re-runs the guard `C:\ProgramData\plex-ensure.ps1` (starts
PMS only if not already running) + `RestartCount=3` backstop. So a crash now
self-heals within ~5 min and survives reboot **without any interactive login**.
`Plex Update Service` is a separate, unrelated service. (`doug`'s profile folder is
`C:\Users\8960` — don't be thrown by the path.)

- Confirm state: `tasklist | findstr /I Plex` (look for `Plex Media Server.exe`);
  `Test-NetConnection localhost -Port 32400`. PMS shows `SessionId 0` now.
- **Force a restart immediately** (don't wait for the watchdog):
  `schtasks /Run /TN PlexMediaServer-Headless` (or `Start-ScheduledTask`). The
  guard relaunches PMS if it's down; ~15–30 s to open 32400 (`/identity` 503→200).
- Task config / re-register lives in **ADR 0028**; password is SOPS
  `secrets/home/videoserver.sops.yaml → WIN_DOUG_PASSWORD` (inject via stdin, never
  echo). If you ever rebuild the task, set the repetition by **borrowing** a working
  `.Repetition` object — `New-ScheduledTaskTrigger`'s repetition args don't persist
  on their own.

### Why the credential/token detail matters (the trap we hit)

PMS reaches the media on the Synology (`\\Blackhole55\Home Files` = `192.168.20.16`)
by **NTLM pass-through from its logon token** — there is **no stored `cmdkey`**
(`cmdkey /list` = NONE). The token must carry `doug`'s password:

- The headless task's **Password logon** carries it → SMB works (verified by a live
  206 byte-range read from session 0).
- A **network logon** (plain SSH) or a **password-less scheduled task** (**S4U**
  token) does **not** → every file access fails `system:1326` (ERROR_LOGON_FAILURE)
  → users see **"Please check that the file exists and the necessary drive is
  mounted"** (distinct from `s1001`). So **never** launch PMS via a bare `ssh …
  "Plex Media Server.exe"` or an S4U task — use `PlexMediaServer-Headless`.
- You also can't pre-seed a `cmdkey`/`CredWrite` from SSH — both blocked from a
  network logon (`CredWrite` → err `1312`).

Last-resort: **reboot** (`AutoAdminLogon` is still on; the boot trigger starts PMS).
NB: triggering `…/analyze` on **multi-GB** files can itself take PMS down — do them
one at a time.

## Who talks to Plex

- **`entertainment`** — Kometa + the Arr pipeline that feeds the library; franchise sort-titles. Needs the **owner** token.
- **`watch-recommendations`** (the Shows / watch-rater app) — watch history for taste profiles, `/library/sections/{3,5}/all` to know what's already on Plex, and scrobble for "Seen it". The `watch_sync` dk400 program pulls sections 3+5 (with `includeGuids`) into the `watchlist` schema.
- **`music-library`** — playlist/library sync.
