---
name: entertainment
description: The media pipeline on the Synology — gluetun-VPN'd Arr stack (sonarr/radarr/lidarr/prowlarr/bazarr/sabnzbd) + Kometa, plus the Plex server (55videoServer) it feeds and the Kometa franchise sort-title system. Use for any arr-stack issue, VPN/gluetun trouble, "why can't sonarr reach the internet", Kometa runs/scheduling/franchises, Plex library/token, or changing how the media stack is configured.
---

# Entertainment (home media pipeline)

The home media pipeline:

**Prowlarr (indexers) → SABnzbd (download) → Sonarr/Radarr/Lidarr (manage) → Bazarr (subs) → Plex (serve) → Kometa (organise).** Requests come in via **Overseerr** (`http://192.168.20.16:5055`).

- **Usenet-only.** Torrents were dropped (qBittorrent disabled 2026-01-11, NZBGet removed Dec 2025) — SABnzbd + Usenet providers is the only download path now. If you see qBittorrent/torrent references in old docs, they're stale.
- **Watchtower** auto-updates the stack's containers daily (~02:00) — so image versions drift on their own; pin if that ever causes trouble.
- The music-library audio-analysis ML worker also runs on the Plex host (55videoServer, RTX 4060) — see `homelab/docs/video-server.md`; that's a separate domain (the `music-library` app), not this pipeline.

## Where it lives
- **Live config (working copy):** Synology `192.168.20.16`, `/volume1/Home Files/Media/arrStack/`.
- **Media library root:** `/volume1/Home Files/Media/` (Movies, TV Shows, Music, Other Shows) — the one canonical location. The whole arr stack mounts only this; Plex points at `\\Blackhole55\Home Files\Media\...`. A legacy `/volume1/Media` shared folder used to hold an old Plex TV library (a strict subset, ~3 TB) left behind by a Jan-2026 cutover into `Home Files/Media`; it had no unique episodes and nothing referenced it, so the data + the `Media` share/subvolume were deleted 2026-06-01 (`synoshare --del TRUE Media`), reclaiming 3 TB. There is no longer any `Media` share — if a doc or memory mentions one, it's stale.
- **Git source of truth:** `homelab-synology/arrstack` (compose.yaml, run-kometa.sh, kometa franchise configs, `config.yml.example`). Secrets (`.env`, real `config.yml`) and generated files (`franchises-auto.yml`) are gitignored — see Secrets below.
- **Docker on the Synology:** non-interactive PATH lacks it — use `sudo /usr/local/bin/docker`. `sudo` is passwordless for `doug`.

## The one architectural fact that explains most problems
Every container — sonarr, radarr, lidarr, prowlarr, bazarr, sabnzbd, **and kometa** — runs with `network_mode: "service:gluetun"`. They have **no network of their own**; all traffic exits through gluetun's VPN, and their web-UI ports are published *on gluetun*. Consequences:
- **gluetun down → they have no network** and are unreachable (ports live on gluetun). A container with `network_mode: service:gluetun` can't even start unless gluetun is running.
- **gluetun *recreated* → their namespace pointer goes stale** → they must be **recreated** to reattach.

### The gotchas that follow (learned the hard way)
- **`docker compose restart` does NOT re-read `.env`.** Only `docker compose up -d` (recreate) applies env changes. A `restart` after an `.env` edit silently keeps the old config — and the drift bites on the next real recreate.
- **After gluetun is recreated, reattach the others with `up -d` (recreate), NOT `restart`** (`restart` errors `No such container` against the old gluetun id).
- **`docker compose up -d --no-deps <svc>` FAILS** for these containers (`network service:gluetun not found`) — `--no-deps` can't resolve the shared namespace for `up`. Use plain `up -d <svc>`; gluetun won't be recreated if its config already matches the running container (verify by comparing `docker inspect --format '{{.Id}}' gluetun` before/after).
- **`--no-deps` DOES work for `docker compose run`** (one-off), which is why the Kometa wrapper uses it.

## Diagnostics
```bash
SYN=doug@192.168.20.16; D="sudo /usr/local/bin/docker"
# gluetun health + which exit it's on
ssh $SYN "$D inspect --format='{{.State.Health.Status}}' gluetun; $D logs gluetun --tail 5"
ssh $SYN "$D exec gluetun wget -qO- --timeout=10 https://ifconfig.co/json"   # exit IP/country
# is the arr stack actually routing through the tunnel?
ssh $SYN "$D exec sonarr curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://api.github.com"
# stack status + UIs
ssh $SYN "$D ps --format '{{.Names}}: {{.Status}}' | grep -iE 'gluetun|sonarr|radarr|lidarr|prowlarr|bazarr|sab|kometa'"
```

## VPN rotation (gluetun `.env`)
The `.env` (provider/country/WireGuard key) is **managed by the dk400 `vpn_rotation` program** — real rotation, retry-until-healthy, auto-blacklist of dead combos, keep-alive revert, daily + heal-on-unhealthy. **Do not hand-edit `.env` and `restart`** — that's the broken pattern it replaced. See fixer **ADR 0015**. State in `qsys._vpnstate` / `qsys._vpnblacklist`. Manual rotate / heal:
```bash
ssh doug@192.168.20.19 "docker exec dk400 python -c \"import asyncio;from programs import vpn_rotation as v;print(asyncio.run(v.run(force=True)))\""
```
If a provider fails on *every* country, its key is stale (check the blacklist filling with that provider) — refresh the key in SOPS, not the program.

## Kometa
- Persistent scheduler container, runs daily (see `KOMETA_TIME` in compose). `restart: always` (a crash + reboot-while-exited once left it dead for ~2 months under `unless-stopped`).
- **Manual run: `/volume1/Home Files/Media/arrStack/run-kometa.sh`** — wraps `compose run --rm --no-deps … kometa` so it can't recreate gluetun and sever the stack. A bare `docker compose run kometa` *will* recreate gluetun (config-drift reconcile) — don't.
- Logs: `kometa/config/logs/meta.log`; validate config with the container's parser: `$D exec kometa /lsiopy/bin/python -c "from ruamel.yaml import YAML; YAML().load(open('/config/<file>'))"` (in-container path is `/config`).

### Franchise sort-titles
Kometa groups franchise films/shows in the main A–Z view via per-item `sort_title` (`"Franchise YYYY - Title"`), set by metadata files:
- `franchises-auto.yml` — **generated daily** by the dk400 `franchise_sync` program from TMDb collections; do NOT hand-edit.
- `franchises-custom.yml` — hand-maintained overrides (loaded AFTER auto, so they win): groupings TMDb can't express.
- `tv-franchises.yml` — TV (no TMDb collections for shows; all manual).
Same-title remakes (e.g. two "RoboCop") can't be title-keyed safely and are skipped. To add a custom grouping, edit `franchises-custom.yml` / `tv-franchises.yml` with exact Plex titles.

## Plex (55videoServer)
Server address, tokens, library section keys, and the API all live in the
**`plex`** skill. Kometa-specific gotcha worth keeping here: Kometa needs Plex's
**owner** token (the registry `PlexOnlineToken`); a *read-only* token makes Kometa
report "No libraries found / token is read only".

## Subtitles — the Bazarr (arr-stack) side
Doug + Maggie rely on subtitles for everything. **Find/sync split (ADR 0019):** Bazarr here is
**find-only** — it fetches the best real sub but does **not** sync, and it is **not** a Whisper
provider (ADR 0020). The **syncing, Whisper transcription, QC/repair/remap, and the Subs-tab** are a
separate system **owned by the `watch-recommendations` skill + the `watch-rater` repo**
(`subsync-worker/`, `whisper-asr/`, `whisper-worker/`, `watchlist.subtitle_syncs`) — **that's the
source of truth**: go there for the engine, the workers, the `--repair`/remap/wrong-sub logic (incl.
the DS9 off-by-one find) and the run model. What lives in *this* skill is the **Bazarr config** the
find side runs on (`…/arrStack/bazarr/config/config/config.yaml`; stop bazarr → edit → start
so it can't overwrite on shutdown):
- **`use_subsync: false`** — find-only. (Was `true`; flipped 2026-06-04 so the Synology
  stops running ffsubsync. The worker on 55videoserver syncs instead.)
- The ffsubsync *behaviour* below still governs the **worker** (same engine) + the manual
  recipe — keep it in mind when syncing:
- **`no_fix_framerate: false`** — MUST be false. If true, ffsubsync only *shifts* and
  never corrects framerate, so PAL/NTSC mismatches **drift through the show** (the #1
  "fine at first, way off by the end" complaint). ffsubsync corrects a constant offset
  AND one framerate scale across the whole audio (e.g. `0.959` = 23.976÷25 = a 25 fps
  sub on a 23.976 file) — i.e. *linear* drift. It does NOT fix *non-linear* drift
  (different cut / ad-break gaps / missing scenes) — that needs `alass`, not ffsubsync.
- **`max_offset_seconds: 300`** — default 60 is too low; big lead-in differences (intro
  logos) need headroom or the sync is abandoned.
- **`use_embedded_subs: false`** — embedded (in-.mkv) subtitle tracks **can't be
  synced/shifted**; if Bazarr counts them as "done" it never fetches a syncable external
  sidecar (this is why a film can be stuck on a mistimed embedded track). False → Bazarr
  always grabs an external `.srt` it can sync.
- **HI subtitles:** profile item `hi: "False"` (non-HI preferred, HI as fallback) + `subzero_mods: remove_HI` **strips `[door creaks]` annotations** from whatever's downloaded — so an "English HI" *source* still delivers plain English. That combo is the wanted "plain English, HI fallback"; don't fight it.
- **Perpetual upgrade loop** (a title re-downloading the *same* sub every `upgrade_frequency` hours forever — e.g. The 39 Steps did this twice-daily for years): the upgrader re-grabs a sub that can't reach a "perfect" score, and each re-download resets the file's age so `days_to_upgrade_subs` never closes it. Diagnose with repeat counts in `GET /api/movies/history?length=2000`. **Fix (keep the sub, stop re-trying):** set that title's profile to none — `POST /api/movies` `radarrid=<id>&profileid=null` (sidecar stays on disk, Bazarr just stops managing it). Blacklisting does the OPPOSITE (deletes the sub + fetches a different one).

Bazarr API (`X-API-KEY` header, key in config.yaml, `http://192.168.20.16:6767`):
list/run jobs via `GET`/`POST /api/system/tasks` (`--data taskid=<id>`):
`wanted_search_missing_subtitles_{movies,series}`, `upgrade_subtitles`,
`{movies,series}_full_scan_subtitles`. A full-library wanted-search is a long background
job — providers throttle (OpenSubtitles daily caps); Bazarr paces and retries on its own.

- **`audio_exclude` is the big silent gotcha:** profile item `audio_exclude:"True"` means
  "don't fetch subs when the audio already matches this language" → with English audio
  (most of the library), Bazarr fetches NO English subs and looks "flaky/idle." Set it
  `"False"` for "subtitles on everything." Profiles live in the DB, edited via
  `POST /api/system/settings` (`languages-profiles`=JSON) — that save is slow (reprocesses
  the library) and can leave the API 500ing; **restart bazarr** to recover + recompute.
- **A previously-unmonitored series Bazarr ignores for subs.** Monitor it (in Sonarr) →
  Bazarr `update_series` → re-apply its profile → `series_full_scan_subtitles` to rebuild
  the "wanted" list; only file-present, monitored episodes get fetched.
- **Historical CPU trap (now designed out):** when `use_subsync` was `true`, every grab ran
  ffsubsync *in the bazarr container*, so hammering the wanted-search stacked parallel jobs
  that saturated the J3455 and timed out Bazarr's API (HTTP 000; `docker restart bazarr`
  cleared it). With sync now off in Bazarr and moved to the 55videoserver worker (ADR 0019),
  Bazarr's wanted-search is light again. If 55videoserver ever feels the sync load during
  Plex playback, the worker runs at concurrency 1 by design; bump/cap there, not in Bazarr.

### Manually re-sync one title (a specific sub is off)
ffsubsync is bundled in the bazarr container at `/app/bazarr/bin/libs`:
```bash
D="sudo /usr/local/bin/docker"
MKV="/movies/<dir>/<file>.mkv"; SRT="/movies/<dir>/<file>.en.srt"
$D exec -e PYTHONPATH=/app/bazarr/bin/libs -e REF="$MKV" -e IN="$SRT" -e OUT=/tmp/s.srt bazarr \
  /lsiopy/bin/python3 -c 'import os,sys; sys.argv=["ffsubsync",os.environ["REF"],"-i",os.environ["IN"],"-o",os.environ["OUT"],"--max-offset-seconds","300"]; from ffsubsync import main; sys.exit(main())'
# it logs "offset seconds" + "framerate scale factor"; back up + replace the .srt with /tmp/s.srt
```
Plex *does* index sidecar `<video>.<lang>.srt` files. To make Plex use a specific sub:
refresh the item (`PUT /library/metadata/<id>/refresh`), identify the stream
(`GET /library/streams/<sid>` returns the srt — match by first cue), then set it default:
`PUT /library/parts/<partId>?subtitleStreamID=<sid>&allParts=1`. (Plex server/token: `plex` skill.)

## Secrets (ADR 0017 — SOPS, not a vault)
- gluetun `.env` VPN creds → SOPS (`secrets/home/dk400-vpn.sops.yaml`), injected into the dk400 container by `dk400-homelab/deploy.sh` (`sops exec-env`). The program reads them via env.
- Kometa `config.yml` (Plex token, TMDb apikey, *arr API keys) → **SOPS source-of-truth 2026-06-02** (option 1): binary-encrypted at `homelab-secrets/secrets/home/synology/kometa-config.yml.sops`. The **live `config.yml` stays plaintext on disk by design** — the persistent kometa container reads it on its own daily schedule (untouched). To change config (collections OR secrets): `sops` the encrypted source → run `homelab-synology/arrstack/render-kometa-config.sh` on the Synology to push it live → Kometa applies next run. Binary mode = exact byte/comment preservation (git diff shows an opaque blob; use `sops` to view). `config.yml.example` in git still has redacted placeholders.
- TMDb + Plex tokens for `franchise_sync` are in the same SOPS file.
- Never commit the real `config.yml` or `.env`; never embed these tokens in skills.

## Changing things / deploy
Edit on the Synology live dir (fastest) or in `homelab-synology/arrstack` (git source) then deploy to the Synology. Kometa/franchise changes apply on the next Kometa run; gluetun/arr changes need `up -d` (recreate), not `restart`. Related: fixer ADR 0015 (VPN rotation), the `command-centre` skill, and the watch-recommendations skill (which consumes Plex + the franchise data).
