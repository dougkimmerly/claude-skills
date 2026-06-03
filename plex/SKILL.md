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

## Who talks to Plex

- **`entertainment`** — Kometa + the Arr pipeline that feeds the library; franchise sort-titles. Needs the **owner** token.
- **`watch-recommendations`** (the Shows / watch-rater app) — watch history for taste profiles, `/library/sections/{3,5}/all` to know what's already on Plex, and scrobble for "Seen it". The `watch_sync` dk400 program pulls sections 3+5 (with `includeGuids`) into the `watchlist` schema.
- **`music-library`** — playlist/library sync.
