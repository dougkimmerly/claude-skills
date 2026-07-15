---
name: dsiv-shipslog
description: Reach and deploy to the DSIV ship's-log Mac (Sheryl's M2 aboard Distant Shores IV). Use when updating, debugging, or deploying the dsiv-shipslog app remotely — covers the SSH path, the deploy-without-git method (no Xcode CLT on the M2 yet), what to EXCLUDE from any rsync, and metered-Starlink build hygiene. Repo: ~/Programming/dsiv-shipslog; its CLAUDE.md owns the app architecture.
---

# DSIV Ship's Log — connect & deploy

## Connect

```bash
ssh sherylshard@shipslog.local        # Doug's Mac's key is already authorized
```

- If `shipslog.local` doesn't resolve, FIRST check which WiFi YOUR device is on
  (`ipconfig getsummary en0 | grep SSID`) — a client on the wrong network was
  the whole story on Jul 15 2026 (laptop on a 10.10.10.x net, boat WiFi is
  elsewhere; mDNS doesn't cross networks). Only then suspect the M2: it may
  have hopped WiFi (gotcha 4 in the repo CLAUDE.md) or mDNS is mid-heal.
  Find it by probing the LAN:
  `arp -a`, then `curl http://<ip>:3200/health` → `{"ok":true,...}` is the app.
  Check `/tmp/shipslog-mdns.log` on the M2 — it records every IP re-advertisement,
  so it tells you when and where the Mac hopped.
- Post-Horta the remote path is Tailscale SSH (see repo HANDOFF checklist).

## Deploy WITHOUT git (until Xcode CLT is installed in Horta)

The M2 has no git binary, so `./update.sh`'s pull fails there. Method (proven
Jul 14 2026, mid-Atlantic):

```bash
cd ~/Programming/dsiv-shipslog   # commit first; deploy the committed tree
rsync -az --delete \
  --exclude '.DS_Store' --exclude 'deploy/dsiv-signalk/' --exclude 'plugin/node_modules/' \
  --exclude 'shipslog-data-*.tgz' --exclude '.sim-state.json' \
  --exclude 'Start Ships Log.command' --exclude '.claude/' \
  ./ sherylshard@shipslog.local:dsiv-shipslog/
ssh sherylshard@shipslog.local 'export PATH="/usr/local/bin:$PATH"; cd ~/dsiv-shipslog \
  && docker compose build shipslog && docker compose up -d \
  && docker exec -i shipslog-postgres psql -q -U dk400 -d dk400 < deploy/dsiv-init/02-ais-ships.sql \
  && curl -s localhost:3200/health'
```

On the M2, docker/colima/lima live in `/usr/local/bin` (the offline install
bundle put them there), NOT `/opt/homebrew/bin` — an SSH shell's default PATH
has neither (verified Jul 14 2026).

**Never invoke `python3` in an ssh command to the M2** — no Xcode CLT yet, so
it pops an install dialog on the boat Mac's SCREEN (repo gotcha 12; done by
reflex Jul 15 2026 — someone aboard had to tap Cancel). Parse JSON on your own
Mac or with node.

**Never drop these excludes:**
- `deploy/dsiv-signalk/` — the LIVE SignalK home (bind-mounted into the
  container: settings, plugin config, kip sqlite). `--delete` here destroys the
  boat's instrument config.
- `Start Ships Log.command` — M2-local launcher, not in git.
- Include `.git/` (default) so the M2's repo lands on the deployed commit —
  makes the Horta git/remote setup trivial.

## Housekeeping rule for this repo

Any crew-facing change must also update `docs/manual.html` — plain English for
non-technical readers (Doug's house rule). docs/ is NOT in the Docker image:
manual edits deploy by rsync alone, no rebuild.

## Before / after

- **Before anything risky**: `ssh … './transfer-data.sh export'` and `scp` the
  tgz back (voyage data is the crown jewel). Backups land in `~/dsiv-backups`
  on Doug's Mac.
- Voice announcer needs NO reload — launchd re-execs the JXA every 20 s tick,
  so a synced `deploy/dsiv-voice.jxa` is live within a tick.
- Verify: `/health`, `/api/voyages/active` (voyage resumed), `/api/settings`,
  `curl -L /log` (`-L`! the shortcut is a 302 — a bare curl greps empty), and
  `docker logs shipslog | tail`.
- If timestamps or the data meter look wrong, compare `date -u` (host) with
  `colima ssh -- date -u` AND an external truth (GPS `navigation/datetime`
  time-of-day, or `curl -sI https://google.com | grep -i date`). If the HOST
  disagrees with truth, someone set ship time by moving the clock instead of
  the timezone — repo CLAUDE.md gotcha 13 (froze the meter 10 h, Jul 14 2026).
  Fix: automatic time ON + advance the closest-city timezone.

## Starlink data hygiene

The boat meter is often over budget — a docker rebuild that invalidates the
`npm install` layer re-downloads ~200 MB over Starlink. Package files unchanged
→ layer should cache; if you see `RUN cd plugin && npm install` executing, the
cache missed (the M2 uses the legacy builder and misses more than buildkit
would). Don't churn `plugin/package*.json` in deploys you can avoid.
