---
context: fork
agent: general-purpose
description: The kitchen MagicMirror (Raspberry Pi 5, 192.168.20.18) — a MagicMirror² display run under pm2 as `mm`, showing clock, calendar, home + Sint Maarten weather, Toronto waste pickup, newsfeeds, Google Sheets. Use when changing what's on the mirror, editing modules/config/styling, deploying a config change, upgrading the MagicMirror app, or diagnosing why the mirror is blank/erroring/crash-looping. Covers the X11-not-Wayland launch gotcha, cold-boot clock-skew cert errors, the scp deploy model, and where the config + custom modules live in git.
---

# MagicMirror (kitchen mirror)

**Host:** Raspberry Pi 5, Debian 12 (bookworm), arm64
**Access:** `ssh doug@192.168.20.18` (user `doug`, passwordless sudo)
**App:** MagicMirror² at `~/MagicMirror`, run under **pm2 as process `mm`** (pm2 daemon via systemd `pm2-doug.service`)
**Web UI:** http://192.168.20.18:8080 (address `0.0.0.0`, ipWhitelist empty = open on the LAN)

## Canonical config lives in git — don't reinvent it here

This skill is the *how-to-operate* layer. The **source of truth for config, styling, deploy commands, and gotchas is the repo README**, which ships with the code:

- **`github.com/dougkimmerly/MagicMirror`** — `config/config.js` (modules) + `config/custom.css` (styling). Read its `README.md` first; it has the exact deploy + upgrade commands.
- **`github.com/dougkimmerly/MMM-MyWastePickup`** — the custom Toronto waste-pickup module (its own repo; ships `csv-parse` v5 in a force-tracked `node_modules`).

⚠️ The Pi's `~/MagicMirror` is the **upstream MagicMirrorOrg app** (branch `master`), which gitignores `config/`. So the config repo is **not** checked out on the Pi — changes are **copied over with `scp`**, there is no `git pull` of the config repo on the device.

## Find current state (don't trust hardcoded values)

```bash
ssh doug@192.168.20.18 'pm2 list'                                   # is mm online? restart count?
ssh doug@192.168.20.18 'cd ~/MagicMirror && node -p "require(\"./package.json\").version"'  # MM app version
ssh doug@192.168.20.18 'pm2 logs mm --err --lines 60 --nostream'    # recent errors
ssh doug@192.168.20.18 'pm2 logs mm --out --lines 80 --nostream'    # startup banner, fetch logs
# which custom CSS is actually loaded: MM default is config/custom.css (defaults.js customCss)
```

To see the rendered result, drive the web UI with the playwright MCP (navigate to the Web UI, then `getComputedStyle` on `.module.calendar table`, etc.). This is how to verify a CSS/size change actually took effect.

## Deploy a change

1. Edit in the **config repo** (`config/config.js` / `config/custom.css`), `node --check config/config.js`, commit + push.
2. `scp` the file(s) to `~/MagicMirror/config/` on the Pi (back up the live file first).
3. `ssh doug@192.168.20.18 'pm2 restart mm'` and verify logs + rendered UI.

A custom module change goes through *its own* repo (e.g. MMM-MyWastePickup), then `git pull`/`scp` onto the Pi under `~/MagicMirror/modules/`.

## Known failure modes (the expensive-to-rediscover ones)

| Symptom | Cause | Fix |
|---|---|---|
| Wall of `CERT_NOT_YET_VALID` / "certificate is not yet valid" right after a (re)boot, then it stops | RPi has no RTC; on cold boot the clock is stale and TLS fetches fail until NTP syncs | Self-heals. Hardened: `systemd-time-wait-sync` enabled + `pm2-doug.service` ordered `After=time-sync.target`. If it recurs, confirm those are still in place. |
| `mm` crash-loops, log shows `Failed to connect to Wayland display` + `electron exited with signal SIGSEGV` | MM 2.36+ default `npm start` forces `--ozone-platform=wayland`; this Pi is **X11** | `~/mm.sh` (the pm2 launch script) must run `npm run start:x11`, not `npm start`. |
| `npm install` fails `EBADENGINE` after `git pull` | New MM release needs newer node than installed | `sudo apt-get update && sudo apt-get install -y --only-upgrade nodejs` (NodeSource 22.x channel), then re-run `npm install`. |
| Waste module: `TypeError: parse is not a function` | `csv-parse` version mismatch (code uses v5 `const {parse}`; old pin shipped v1 `{Parser}`) | MMM-MyWastePickup must ship csv-parse **v5** in its force-tracked `node_modules` (node_modules is otherwise gitignored). |
| A panel shows blank / `ERR_CONNECTION_REFUSED` every minute | An `MMM-SmartWebDisplay` panel points at a backend that's down (e.g. wyze-bridge cameras on .19:8888, boat Grafana on 192.168.22.16:3000) | Confirm the backend with `curl`; if intentionally gone, comment the panel block out in `config.js`. |

## Calendars

The `calendar` module reads **iCal feeds**, and a Google iCal feed contains only events that live *on that calendar* — i.e. events you created or were **invited to as a guest**. Someone else's events that you only *see* via a shared/overlay calendar are **not** in your feed. So "some of person X's events show, not all" = the shown ones are the invites; the rest live on X's own calendar.

To pull all of another person's events: add **their calendar's "Secret address in iCal format"** (Google Calendar → Settings → their calendar → Integrate calendar; owner-only, treat like a password) as another entry in the `calendars: []` array. Give it a distinct `symbol` (e.g. `heart`) so it's visually separable.

Duplicates across feeds (an event on both calendars because of an invite) are handled by the module's **`hideDuplicates: true`** (default on) — it drops events with matching title + start + end. Edge case: if one side renames/retimes their copy, both can show. The kept copy uses the symbol of whichever feed is listed first. `maximumEntries` caps the total shown; a second busy calendar fills it faster, so bump it if you want to see further out.

## Coordinating changes over time

- Make config/styling changes **in the config repo and commit them** — the live Pi file is downstream of the repo, not the other way around. An uncommitted edit made only on the Pi is how knowledge gets lost (that's exactly what happened with the csv-parse fix).
- After a non-trivial change, **verify in the rendered UI** (playwright), not just the logs.
- If you change deploy/topology/gotchas, update the **repo README** (living doc) and this skill's failure-mode table (experiential) — keep canonical config in the README, keep "how to operate / what breaks" here.
