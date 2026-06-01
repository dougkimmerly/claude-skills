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
- The server that serves the media: **`192.168.20.12`** (ethernet, preferred) / `192.168.20.201` (wifi) — a **Windows** host (`hostname 55videoServer`; SSH drops into cmd.exe, use `powershell -Command`).
- **Owner token** (full read/write — needed by Kometa & tooling) = the `PlexOnlineToken` in the host's registry: `Get-ItemProperty 'HKCU:\Software\Plex, Inc.\Plex Media Server' -Name PlexOnlineToken`. A *read-only* token makes Kometa report "No libraries found / token is read only".
- Library section keys: Movies = **3**, TV Shows = **5**. List/inspect via `http://192.168.20.12:32400/library/sections?X-Plex-Token=…` and `/library/sections/<key>/all?includeGuids=1` (the bulk movie list with TMDb ids, one call).

## Secrets (ADR 0017 — SOPS, not a vault)
- gluetun `.env` VPN creds → SOPS (`secrets/home/dk400-vpn.sops.yaml`), injected into the dk400 container by `dk400-homelab/deploy.sh` (`sops exec-env`). The program reads them via env.
- Kometa `config.yml` (Plex token, TMDb apikey, *arr API keys — 19 secret fields) is still host-only plaintext, **pending SOPS migration** (secrets-migration runbook). `config.yml.example` in git has them redacted.
- TMDb + Plex tokens for `franchise_sync` are in the same SOPS file.
- Never commit the real `config.yml` or `.env`; never embed these tokens in skills.

## Changing things / deploy
Edit on the Synology live dir (fastest) or in `homelab-synology/arrstack` (git source) then deploy to the Synology. Kometa/franchise changes apply on the next Kometa run; gluetun/arr changes need `up -d` (recreate), not `restart`. Related: fixer ADR 0015 (VPN rotation), the `command-centre` skill, and the watch-recommendations skill (which consumes Plex + the franchise data).
