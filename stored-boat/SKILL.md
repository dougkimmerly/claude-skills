---
name: stored-boat
description: Stored-boat mode for Distant Shores II — the vessel-mode flag (crewed vs stored), what each mode arms/disarms (arid bilge adaptive scheduler, voice announcements, storedBoat 2.0 power management), and how to diagnose when stored-mode behaviors aren't firing. Use when activating or deactivating stored mode, building stored-mode features, or troubleshooting autonomous boat behavior during the 8-month unattended period (May 2026 – Jan 2027).
---

# Stored Boat Mode

**Period:** ~May 2026 – Jan 2027. Boat on the hard, solar-only power, unattended. Systems watch themselves and each other; Telegram only when human action is genuinely required.

**Authoritative plan doc:** `fixer/docs/runbooks/stored-boat-plan.md` — full resilience matrix (sections A–E), 45+ open items, architectural decisions. Read that before proposing new stored-mode work.

---

## Stored-mode WAN topology

During storage, Starlink Maritime service is **paused** (not cancelled). Cell is primary.

| WAN | Device | Status |
|-----|--------|--------|
| Masthead LTE (HD1 Dome) | MAX HD1 Dome via SIM Injector | **Primary** — TelCell SIM, APN `internet.telcell.am`, Band 8 locked |
| Starlink Maritime | starlinkInverter relay | Service paused; relay 1 rewired NC→NO departure-day (OFF by default) |
| Glow / Fleet One | Redport → FleetOne | Last resort, ~150 kbps satellite |

**TelCell config (Sint Maarten, IMSI 362510100240143):**
- APN: `internet.telcell.am` (set in HD1 Dome Connection Settings → Custom APN)
- Band lock: LTE Band 8 (900 MHz) only — all other LTE bands + WCDMA unchecked
  - Why: Band 3 (1800 MHz) CA at SINR 0.0 dB dragged throughput to ~43 kbps; Band 8 alone = 4.6 Mbps peak
- CGNAT: WAN IP 10.x.x.x — no inbound. Access via Tailscale DERP or SpeedFusion only.
- Plan: 10 GB/month auto-renew, TelEm Group / TelCell Mobile
- SIM Injector (392C-0DE1-8E62, slot 2) on independent Secondary Network power circuit — not affected by storedBoat 2.0 load shedding

**HD1 Dome physical placement — DO NOT MOVE (verified 2026-05-22):**
- Dome is mounted **inside the boat** at a specific optimized location
- Signal varies by up to 10 dB RSSI between spots inside the same fiberglass hull
- Current position: RSSI 16–18 dB, SINR 10–12 dB — matches outdoor performance
- Why it varies: copper anti-fouling paint, metallic primers, wire runs, and metal fittings create a partial Faraday cage. Effect varies hugely by location — near hatches/portlights/thin hull sections is much better than deep inside.
- If someone moves the dome during boat work, it needs to go back to the marked spot. Recovery: reposition dome and check WAN Quality chart (target SINR >10 dB, RSSI >15 dB).

**Starlink Standby Mode (paused state):**
- Enable via Starlink app from home — no boat connection required
- Hardware registration retained; reactivates in minutes
- **Costs $5–10/month** (not free — Starlink replaced free pause with Standby Mode)
- **500 kbps unlimited** while in standby — enough for SSH, Telegram, monitoring; not enough to load the Starlink web UI
- **Monthly data does NOT roll over** when entering standby
- **Purchased data add-ons are forfeited** when switching to standby (don't buy add-ons before pausing)
- **12-month maximum** in standby — after that, Starlink can require upgrade or suspend service
- ToS says "not intended for maritime use" (refers to in-motion maritime; boat-on-the-hard is stationary)
- Standby Mode no longer supports in-motion use as of March 2026

**Reactivation from standby:**
1. Open Starlink app from home
2. Account → Resume service
3. Full speed restored in minutes; service picks up from beginning of new billing cycle

**Starlink power control via Telegram (when cell WAN is too slow for web UI):**
- `/starlink on` → SK PUT `electrical.commands.switch.sensesp-starlinkInverter = "on"` → relay 1 energizes → Starlink powers on
- `/starlink off` → de-energizes relay → Starlink off
- Works at any bandwidth (Telegram works at 1 kbps; Starlink web UI needs ~1+ Mbps)
- Relay wired NC→NO departure-day: default stored state = Starlink OFF (relay de-energized)
- See item #32 in stored-boat-plan.md

**Peplink outbound policy — WAN-aware routing (item #34, not yet configured):**
Both WANs stay powered on. Peplink routes per-connection; no relay toggling for daily management.

| Rule | Source | Destination | Algorithm | WAN order |
|------|--------|-------------|-----------|-----------|
| Large transfers | `192.168.22.15` (centralsk) | Home server Tailscale IP | Priority | Starlink → Cell |
| Default | Any | Any | Priority | Cell → Starlink |

- Cell down → monitoring/SSH falls back to Starlink 500 kbps automatically
- Starlink down → backups fall back to cell automatically (slower, uses cell data budget)
- Use Priority not Enforced — Enforced drops traffic if designated WAN fails; Priority fails over
- Relay 1 becomes emergency-only (extreme low-SoC load shed), not daily management
- Starlink always-on draws ~20–30W — account for in storedBoat 2.0 load budget

**Data budget (2026-05-22 baseline):**
- Postgres dump: ~128 MB/day compressed = ~3.8 GB/month (growth slows significantly in storage)
- Total monthly cell usage estimate: 5–6 GB within 10 GB plan
- Monitor via resource planner API: `curl -s http://192.168.22.15:3200/api/resource-planner/stored-state | jq .snapshots.cell_data`
- Alert threshold: 3 GB remaining (warn), 1 GB remaining (critical) — `CellDataResource` queries HD1 Dome USSD every 6h (item #33)

**Cell budget policy — no hard cap (Doug 2026-05-24):**
- TelCell rollover is acceptable. If the 10 GB plan is exhausted, it auto-renews and bills another ~$30 cycle. The resource planner soft-manages cell consumption (Starlink scheduling, Syncthing pause/resume) but never enforces a hard cap.
- **Peplink BAM is NOT configured.** It would use calendar month while TelCell uses rolling 30-day (so accuracy is limited anyway) AND a hard cutoff could lock us out at the wrong moment. The Peplink skill documents the BAM API for reference; do not configure it on this boat.
- Cell-overage penalty in `stored.js` value function is a soft cost. Steers the planner; doesn't force a shed.

**Starlink-pause date — 2026-06-06.** Service goes into Standby Mode (500 kbps unlimited) on that date for the storage period. Two implications:
- **Pre-pause data flush deadline:** any boat→home backlog should drain before 2026-06-06. Item #41 in the plan doc has the checklist. After pause, ~200 MB/h realistic throughput, so a big backlog could take days to clear.
- **Throughput assumption (`STARLINK_STANDBY_MB_PER_HOUR = 200` in transfer-demand.js) matches post-pause reality.** Before 2026-06-06 the planner over-sizes windows because real Starlink throughput is much higher; harmless.
- Doug can unpause from the Starlink app from home (no boat connection needed) for short windows if needed during storage.

---

## What's live today (2026-05-24, sessions 11–15)

| Component | Status | Host | Notes |
|---|---|---|---|
| stored-boat-heartbeat.py | **Live** | N2KPower (192.168.22.14) | storedBoat 2.0 PNP daemon. Normal mode: watchdog + stored-state polling every 5 min. Phase 2 mode: SoC-scaled duty-cycle (7d/3d/24h/6h/2h). Supersedes centralsk-watchdog.py. Fixed 2026-05-24: SK JWT auth, COMMS_URL → Tailscale IP. |
| centralsk-watchdog.py | **Retired** | N2KPower | Disabled 2026-05-23. Service stopped + disabled. |
| signalk-ble-watchdog.timer | **Live** | centralsk (systemd) | Fires every 10 min. If ≥3 of 5 BLE battery IDs missing from SK AND PowerNet Pi reachable → `systemctl restart signalk`. Auto-recovers from power-glitch boot-race. Script: `/opt/signalk/watchdog/ble-reconnect.sh`. Logs: `journalctl -t ble-watchdog`. |
| storedBoat v1 | Disabled | centralsk | `enabled:false` in plugin-config-data since 2026-03-17. Never wired to real circuits. |
| Vessel mode flag | **Live** | cruising-app (port 3200) | sb-p1-22 RESOLVED. `cruising.vessel_config` (mode/occupancy/nav_state_override). Chips in every header. `/boat-status/` management page. |
| voyage-events SK publication | **Live** | centralsk SK plugin | vessel.mode published to `vessel.mode` SK path. Startup fetch (8s delay) + POST notification on every mode change. Plugin at `/opt/signalk/custom-plugins/voyage-events/`. |
| alarm-manager TTS gate | **Live** | centralsk SK plugin | sb-p1-22 RESOLVED. Subscribes to `vessel.mode` SK path. In stored mode, `/alarm-manager/test` returns `{suppressed:true}` immediately; no Fusion stereo, no TTS. N2K safety alarms unaffected. |
| Arid bilge scheduler | **Live** | cruising-app (port 3200) | sb-p1-21 RESOLVED. `scheduler_enabled=false` until departure. Worker: `app/workers/arid-bilge-scheduler.js`. Schema: `cruising.arid_bilge_schedule`. |
| Resource planner stored mode | **Live** | cruising-app (port 3200) | item #35 DONE. Worker: `app/workers/stored-boat-resource-planner.js`. Schema: `cruising.stored_mode_state` + `mode` column on `resource_plans`. API: `GET /api/resource-planner/stored-state`. Fires hourly at :08 only (startup tick removed 2026-05-24 — it was causing immediate Phase 2 on reboot). Active only when vessel.mode = 'stored'. |
| Resource planner page (crewed suppression) | **Live** | cruising-app (port 3200) | `/resources/` shows storedBoat 2.0 status panel (tier, runway, net Wh/day, Starlink/dehumidifier, last tick) instead of crewed schedule when in stored mode. |
| Forecast-driven Starlink decision | **Live (2026-05-24)** | cruising-app | ADR 0002 mode-strategy. `app/lib/modes/stored.js` runs 3 candidates per tick (`starlink_on`/`starlink_windowed`/`starlink_off`) through the prediction engine; optimizer picks. Value function: hard-floor cost + soft floor at day-8 SoC 50% + headroom + telemetry + cell overage. Replaces threshold ladder. |
| Cell projection EWMA | **Live (2026-05-24)** | cruising-app | 24h half-life EWMA over hourly per-WAN cell deltas (Peplink). 72-entry ring buffer in `wan_traffic` snapshot. Activates after 3 samples accumulated. `cell_data.projection_source` surfaces which path won: `recent_ewma > rolling_ussd > cycle_average`. |
| Demand-driven windows + Syncthing/BKP coordination | **Live (2026-05-24)** | cruising-app | `app/lib/transfer-demand.js` reads Syncthing per-receiver `needBytes` (valid/syncing only — orphans excluded) and dk400 job lag. Window length sized to demand. Worker pauses Syncthing folders + holds rsync push job in lockstep with Starlink relay (idempotent; no-op when state matches). |
| Schedule + vital-stats endpoints | **Live (2026-05-24)** | cruising-app | `GET /api/resource-planner/starlink-schedule` returns latest forecast + regime + in_window. `GET /api/resource-planner/vital-stats` returns 253-byte compact summary (under 280-byte FleetOne target); X-Payload-Size header for budget tracking. |
| Boat vital-stats home puller | **Live (2026-05-24)** | docker-server dk400 | `BOAT_VITAL_PULL` runs hourly at :15. Reads boat schedule first; skips if regime is `off` or `windowed-out-of-window`. Otherwise fetches vital-stats, stores in `fixer.boat_vital_stats_history` (JSONB time series). Program: `boat_vital_stats_pull.py`. |
| Syncthing topology — single-source over WAN | **Live (2026-05-24)** | boat + home Syncthing | `centralsk-backups` now shared only with docker-server from boat; docker-server fans out to synology over LAN. Saves ~3.84 GB/month redundant satellite traffic. Orphan `pwspm-f5ehd` folder removed. |
| Starlink manual override | **Live (2026-05-24)** | cruising-app + Command Centre | User-initiated time-bounded shed (default 15 min) for Wyze cam access. Boat: `GET/POST/PATCH/DELETE /api/resource-planner/starlink-override`. Command Centre: 🛰️ icon in header. Worker honors active+unexpired override over forecast. DELETE auto-restores Starlink ON when clearing a forced-off override (avoids reconciliation gap). See [[starlink-manual-override]] memory for full details. |
| **SignalK user-mode systemd** (resilience) | **Live (2026-05-25)** | centralsk | After 2026-05-25 bit-rot incident: SK now runs under `~/.config/systemd/user/signalk.service` with `loginctl enable-linger doug`. The legacy `/etc/systemd/system/signalk.service` is disabled (SEGVs on startup — missing session env vars for BLE/dbus plugins). BLE watchdog patched accordingly. See [[centralsk-bitrot-recovery]] memory. |
| Golden SK snapshot | **Live (2026-05-25)** | centralsk + Syncthing | `/opt/golden/signalk-{config-and-plugins,server-install}-2026-05-25.tar.gz` (566 MB + 51 MB). Replicated to home via Syncthing at `/opt/centralsk/syncthing/backups-data/centralsk-golden/`. Canonical restore source if bit-rot recurs. |
| `.stfolder` marker repaired | **Live (2026-05-25)** | centralsk Syncthing | The marker at `/opt/centralsk/syncthing/backups-data/.stfolder` was missing; cross-site replication had been silently stalled. Re-created. Verify via Syncthing API `globalBytes` growth after writing test files. |
| Water rate — zero in stored mode | **Live** | cruising-app | Both trajectory endpoint (`getWaterRateForCurrentState`) and prediction-inputs (`buildHourlyWaterConsumption`) return 0 L/day when vessel.mode = 'stored'. |
| Water rate — crew scaling | **Live** | cruising-app | Crewed mode: rate scales by `crew_count / 2` (reference = Doug + Maggie). Count from open embarkations (`signed_off_at IS NULL`). 0 open → uses reference crew of 2 as safe default. |

Check heartbeat daemon on PNP:
```bash
ssh doug@192.168.22.14 "systemctl status stored-boat-heartbeat && tail -30 /var/log/stored-boat-heartbeat.log"
```

Check vessel mode in SK (voyage-events plugin must be running):
```bash
curl -s http://192.168.22.15:3000/signalk/v1/api/vessels/self/vessel/mode
```

Check arid bilge scheduler state:
```bash
curl -s http://192.168.22.15:3200/api/bilge/arid/schedule
```

---

## Boat state model — four dimensions (built 2026-05-22)

All four dimensions stored in `cruising.vessel_config` (single row, id=1). Each is a separate
concept controlled independently.

| Dimension | Column | Values | Source |
|---|---|---|---|
| **Vessel mode** | `mode` | `crewed` / `stored` | Manual only — deliberate human declaration |
| **Occupancy** | `occupancy` | `occupied` / `not_occupied` | Manual (future: companionway button → security sensor) |
| **Nav state** | `nav_state_override` (NULL = auto) | sailing / motoring / anchored / docked / on_the_hard | Auto from SK `navigation.state` + manual override |
| **Crew roster** | — | Array of names | From current voyage (stays.crew) — read-only in vessel-config page |

**UI:** Three chips injected into every page header via Express middleware (boat-status.js). Chips
show current state, color-coded (amber for stored/away/on_the_hard). Clicking any chip → `/boat-status/`.

**Future occupancy enhancements:** companionway button → occupancy toggle, security sensor activation,
lights simulation (make occupied/unoccupied look right from outside). All wired through `occupancy`
column — just add triggers on change.

**On the hard detection:** If roll_rms_deg + pitch_rms_deg stay near-zero for hours but nav_state ≠ on_the_hard,
fire voice announcement asking to update nav state. (Not yet built — planned in stored-boat-plan.)

## The vessel mode flag

Single source of truth for whether the boat is crewed or unattended. All stored-mode features check
this at decision time (not at scheduling time) — flipping mode takes effect on each feature's next cycle.

| Item | Detail |
|---|---|
| DB | `cruising.vessel_config.mode` — `'crewed'` \| `'stored'` |
| SK path | `vessel.mode` (published by voyage-events plugin after config change notification) |
| UI | `/boat-status/` page — requires explicit confirmation; shows what will arm/disarm |
| Build status | **LIVE** as of 2026-05-22 |
| Route file | `app/routes/vessel-config.js` in cruising-app |

Check current mode:
```sql
SELECT mode, mode_changed_at, mode_changed_by,
       occupancy, occupancy_changed_at, nav_state_override
FROM cruising.vessel_config LIMIT 1;
```

API (live on centralsk):
```bash
curl -s http://192.168.22.15:3200/api/vessel-config
```

From SK (once voyage-events plugin updated to publish vessel.mode):
```bash
curl -s http://192.168.22.15:3000/signalk/v1/api/vessels/self/vessel/mode
```

---

## What the mode flag gates

| Feature | Stored (armed) | Crewed (off) | Build status |
|---|---|---|---|
| Arid bilge adaptive scheduler | External circuit control, 6h–72h adaptive interval, weather-aware, burnout protection | Unit runs its own 3h internal timer; scheduler idle | **Live** — item #30 |
| Voice announcements (alarm-manager) | All TTS suppressed | Normal — today list, pills, gongs, wakeup all active | **Live** — item #31 |
| storedBoat 2.0 PNP executor | Active — SoC-adaptive load management, graceful centralsk shutdowns | Inactive | **Live** — ADR 0012 |
| Resource planner stored mode | Active — hourly SoC trajectory, load-shed decisions | Normal operation | **Live** — item #35 |

---

## Arid Bilge in stored mode (item #30)

The scheduler takes external control of circuit `48.10`. In stored mode the circuit stays **OFF by default** — the unit's internal 3h timer is bypassed entirely.

**Cycle flow:**
1. Power ON at `next_cycle_at`
2. Monitor current until siesta (≤ 0.15 A sustained 5 min) — cycle complete
3. Power OFF; evaluate wet/dry verdict; compute next interval; write new `arid_bilge_schedule` row

**Interval algorithm:**
- Dry cycle → `next_interval = min(72h, current_interval × 1.5)`
- Wet cycle → `next_interval = max(6h, current_interval / 2)`
- Rain forecast override → clamp to 6h regardless of dry streak

**Wet/dry verdict:** any zone with `suck_dur_s > 20` on the initial sweep = wet. Below 20 s = condensation/trace = dry for scheduling.

**Weather-aware floor:** before scheduling next cycle, query SK forecast (`environment.outside.*`). If precipitation ≥ threshold (e.g. 5 mm) in next 24 h → use MIN_INTERVAL (6 h). Rain is the only water source when on the hard.

**Burnout protection (JOB-1084 failure mode):** if any single zone hits `suck_dur_s = 282` (unit's suction timeout ceiling) on **5 consecutive cycles** → set `scheduler_enabled = false`, power off circuit, Telegram: "Arid Bilge disabled — [Zone] unable to clear after 5 cycles." Counter is per-zone; resets when that zone has any non-cap cycle. Re-enable via `/bilge` page only — not remotely, without understanding why.

**Schema:**
```sql
-- Scheduler state
SELECT current_interval_s/3600.0 AS interval_h, next_cycle_at,
       dry_streak, last_cycle_at, scheduler_enabled
FROM cruising.arid_bilge_schedule;

-- Burnout risk: zones hitting cap recently
SELECT zone_name, COUNT(*) AS cap_cycles
FROM cruising.arid_bilge_cycle_events
WHERE suck_dur_s = 282
  AND started_at > now() - interval '7 days'
GROUP BY zone_name ORDER BY cap_cycles DESC;
```

**Worker:** `app/workers/arid-bilge-scheduler.js` (cruising-app). Started by `server.js` alongside other workers.
**Switch path:** `electrical.switches.bank.48.10.state` via SignalK PUT.
**DC read path:** `electrical.dc.8.9.current` (0-indexed: channel 10 → dc index 9).
**API endpoints (live):**
```bash
# Current scheduler state
curl -s http://192.168.22.15:3200/api/bilge/arid/schedule

# Enable / disable
curl -X POST http://192.168.22.15:3200/api/bilge/arid/schedule/enable \
  -H 'Content-Type: application/json' -d '{"enabled": true}'
```
**GRANT required after schema create on centralsk** (centralsk postgres creates tables as owner `postgres`; cruising-app runs as `dk400`):
```sql
GRANT SELECT, INSERT, UPDATE ON cruising.arid_bilge_schedule TO dk400;
```

See `bilge-pumps` skill (cruising-app) for cycle decomposer, zone mapping, and full arid bilge internals.

---

## Voice announcements in stored mode (live as of 2026-05-22)

`alarm-manager` SK plugin at `/opt/signalk/custom-plugins/alarm-manager/` on centralsk.

In stored mode: all TTS suppressed — today list, pills, dinner gong, wakeup, zone announcements. Telegram fan-out is the replacement channel when nobody is aboard. alarm-manager subscribes to `vessel.mode` SK path via `app.streambundle.getSelfStream('vessel.mode')` and caches it in `vesselMode`. In stored mode, `/alarm-manager/test` returns `{suppressed:true}` immediately. **N2K safety alarms (processPendingAlarms) are NOT suppressed.**

Test suppression:
```bash
curl -s -X POST http://192.168.22.15:3000/alarm-manager/test \
  -H 'Content-Type: application/json' -d '{"message":"test","severity":"info"}'
# stored mode → {"accepted":true,"suppressed":true,"reason":"stored mode",...}
# crewed mode → plays TTS, returns {"accepted":true,...}
```

Check configured announcements:
```bash
ssh doug@192.168.22.15 "cat /opt/signalk/.signalk/alarm-manager.json"
```

### SK plugin endpoint auth gotcha

**IMPORTANT:** SignalK auth-gates any URL under the `/plugins/` prefix. Routes registered as:
```javascript
app.post('/plugins/voyage-events/vessel-config-changed', ...)  // ← 401 Unauthorized
```
must use a non-`/plugins/` prefix:
```javascript
app.post('/voyage-events/vessel-config-changed', ...)  // ← OK, unauthenticated
```
This affects both the plugin's own registered routes AND any callers. `vessel-config.js` calls `/voyage-events/vessel-config-changed` (not `/plugins/voyage-events/vessel-config-changed`).

Check voyage-events endpoint is live:
```bash
curl -s -X POST http://192.168.22.15:3000/voyage-events/vessel-config-changed
# should return 204
```

---

## storedBoat 2.0 architecture (ADR 0012)

**Brain — resource planner on centralsk (hourly at :08):**
- Objective: maintain ~80% SoC (100% on first full-sun day each month for BMS cell balancing)
- Reads all three arch MPPTs + battery SoC; computes runway; sheds loads by tier
- Shed tiers: Tier1 >30d (all on) → Tier2 14–30d (shed Starlink) → Tier3 7–14d (+ shed dehumidifier) → Phase2 <7d (hand off to PNP)
- **Phase 2 requires 3 consecutive hourly readings** below 7d runway before triggering — protects against single bad reads (e.g. MPPT data not yet populated after a reboot)
- Publishes decisions to `/api/resource-planner/stored-state`

**Muscle — PNP executor (Python systemd, polls every 5 min):**
- Reads `/api/resource-planner/stored-state` from centralsk
- Executes CLMD16 toggles: `bank.45.15` (Secondary Network / centralsk circuit), `bank.43.16` (dehumidifier power gate)
- Graceful centralsk shutdown before toggling off: SSH → `sudo shutdown -h now` → wait for ping fail → toggle circuit
- Fallback when centralsk unreachable: SoC thresholds only (< 40% → shed fans + Secondary Network; > 70% → ensure Starlink on)

**Bootstrap safety:** PNP controls centralsk's power circuit. centralsk does not control its own power. The v1 fatal flaw (bootstrap paradox) is resolved by this physical split.

**stored_mode_state schema** (`cruising.stored_mode_state`, single row):
```sql
SELECT tier, phase2_active, low_production_readings, low_runway_readings,
       good_production_cycles, last_runway_days, last_net_wh_per_day,
       last_production_wh_today, starlink_shed, dehumidifier_shed,
       last_action, updated_at
FROM cruising.stored_mode_state;
```
- `low_production_readings` — consecutive daylight ticks with panel < 10W (triggers production-collapse Phase 2 at 6)
- `low_runway_readings` — consecutive ticks with runway < 7d (triggers runway-based Phase 2 at 3)
- Both counters reset to 0 when condition clears

**Solar production — three active arch MPPTs (as of 2026-05-24):**
- `electrical.solar.mpptArchPrt` — Arch Port: ~300W peak
- `electrical.solar.mpptArchStb` — Arch Starboard: ~300W peak
- `electrical.solar.mpptArchCentre` — Arch Centre: ~600W peak
- `electrical.solar.mpptFwdStb` / `mpptFwdPort` — zero (not producing)
- **Values are in Joules** — divide by 3600 for Wh
- Typical Sint Maarten May day: ~8000 Wh total (all 3), ~1150W peak at noon
- Resource planner reads all three; missing Centre was a bug that caused 33% underestimate and false Phase 2

**Production proxy (morning before 1pm local):**
- Uses yesterday's full-day yield as the daily forecast baseline
- Or extrapolates today's current pace to noon — whichever is higher
- **Never use min(yesterday, today_partial)** — that picks the partial morning accumulation (~1500 Wh at 6 AM) over yesterday's full day (~8000 Wh), causing 5× underestimate → false short runway → false Phase 2

Check PNP heartbeat daemon:
```bash
ssh doug@192.168.22.14 "systemctl status stored-boat-heartbeat && tail -30 /var/log/stored-boat-heartbeat.log"
```

Check resource planner decision (live):
```bash
curl http://192.168.22.15:3200/api/resource-planner/stored-state
```

Check stored_mode_state in DB:
```bash
ssh doug@192.168.22.15 "docker exec dk400-postgres psql -U dk400 -d dk400 -c 'SELECT tier, phase2_active, low_runway_readings, last_runway_days, last_net_wh_per_day, last_action, starlink_shed, dehumidifier_shed, updated_at FROM cruising.stored_mode_state;'"
```

See `homelab-boat-network` skill for CLMD16 circuit table and N2K bus topology.

---

## Controlling bank.45.15 from PNP (centralsk power circuit)

**bank.45.15** is the Secondary Network power circuit — it controls centralsk's power. It is on PNP's own N2K bus (source: `powerNet.c03c8c2d16178147`), controllable from PNP even when centralsk is down.

**Prerequisites** (both must be true):
1. `signalk-n2k-switching` plugin enabled on PNP's SK:
   ```bash
   # Check/enable:
   python3 -c "
   import json
   f='/home/doug/.signalk/plugin-config-data/signalk-n2k-switching.json'
   d=json.load(open(f))
   print('enabled:', d.get('enabled'))
   "
   # If false, set enabled=true and restart SK:
   sudo systemctl restart signalk
   ```
2. Valid JWT auth token in the PUT request (SK requires auth for PUT even from localhost)

**Generating a JWT from PNP:**
```python
import base64, hashlib, hmac, json, time

with open('/home/doug/.signalk/security.json') as f:
    secret = json.load(f)['secretKey']

def b64u(data):
    if isinstance(data, dict):
        data = json.dumps(data, separators=(',',':')).encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

h = b64u({'alg':'HS256','typ':'JWT'})
p = b64u({'id':'admin','iat':int(time.time())})
sig = hmac.new(secret.encode(), f'{h}.{p}'.encode(), hashlib.sha256).digest()
token = f'{h}.{p}.{base64.urlsafe_b64encode(sig).rstrip(b"=").decode()}'
print(token)
```

**Making the PUT (async — must poll for completion):**
```bash
TOKEN=$(python3 /path/to/above)

# Cut power (value=0) or restore (value=1)
curl -s -X PUT http://localhost:80/signalk/v1/api/vessels/self/electrical/switches/bank/45/15/state \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"value":0}'
# Returns: {"state":"PENDING","requestId":"...","statusCode":202,...}

# Poll until COMPLETED:
curl -s http://localhost:80/signalk/v1/requests/<requestId>
# Returns: {"state":"COMPLETED","statusCode":200,...} when done
```

**Power-cycling centralsk remotely:**
```bash
# 1. SSH graceful shutdown
ssh -i /root/.ssh/id_centralsk doug@192.168.22.15 "sudo shutdown -h now"
# Wait ~30s for OS to halt

# 2. Cut power (bank.45.15 = 0), wait 15s, restore (bank.45.15 = 1)
# ... use PUT above ...

# 3. Wait for centralsk to boot (~90s), then verify:
ping 192.168.22.15
```

**If centralsk was shut down but power was never cut** (e.g. 401 errors prevented circuit toggle), the Pi is halted but powered. It will NOT restart on its own — must cut and restore power to boot it.

---

## Diagnosing stored-mode behaviors not firing

1. **Check vessel mode** — is the flag actually set to `stored`? (SQL or SK path above)
2. **Arid bilge idle?** → check `scheduler_enabled` in `arid_bilge_schedule` — burnout protection may have disabled it
3. **Announcements still playing?** → check SK `vessel.mode` path is `"stored"` — alarm-manager reads it; if SK path is stale, voyage-events plugin may not have received a notification. Try POST to `/voyage-events/vessel-config-changed` to force re-publish.
4. **PNP heartbeat not acting?** → `systemctl status stored-boat-heartbeat` + `tail /var/log/stored-boat-heartbeat.log` on PNP (192.168.22.14)
5. **Resource planner not running?** → check cruising-app logs on centralsk; verify `/api/resource-planner/stored-state` responds
6. **Mode not propagating to SK?** → check cruising-app worker that publishes `vessel.mode` path

## Diagnosing WAN / connectivity issues

**ALWAYS check Peplink WAN status FIRST** before diving into device-specific diagnostics:

```bash
# NarwhalCore MANGA API — one call shows what each WAN actually sees
curl -s http://192.168.22.1/api/status.wan.connection | jq '.[]|{id,statusLed,message,uptime}'
# statusLed "green" = connected; "red" = problem (see message: "No Cable Detected", "No Signal", etc.)
```

The Peplink has layer-1/layer-2 visibility that device-specific tools don't. `statusLed: "red", message: "No Cable Detected"` means physical cable or power — don't spend time on USSD/API debugging until the Peplink sees the link.

**Lesson (2026-05-28 HD1 Dome incident):** USSD balance query was failing. Root cause was Peplink reporting "No Cable Detected" on WAN 2 — the modem had gone physically dark. Went deep into USSD wire-protocol debugging without checking `status.wan.connection` first. Doug had to point it out from the PowerNet control panel. One API call would have resolved it immediately.

**Also:** `wan_traffic` delta-based metrics (like `recent_rate_gb`) can look plausible from pre-failure activity. Don't trust computed freshness when the raw source-of-truth check is available.

### Phase 2 shutdown loop (2026-05-24 incident)

**Symptom:** Telegram alerts saying boat is going into shutdown; centralsk repeatedly shutting down and rebooting; heartbeat log shows `phase2_active=True detected` every 5 minutes.

**Root causes found (all three must be addressed):**
1. Resource planner had a 20-second startup tick — fired before SK data was populated after reboot, giving 0 Wh production → false short runway → Phase 2
2. Resource planner was missing `mpptArchCentre` — only read 2 of 3 active MPPTs, underestimating production by 33%
3. Production proxy used `min(yesterday, today_partial)` — at 6 AM this picks the partial morning accumulation (~1500 Wh) over yesterday's full day (~8000 Wh), causing 5× underestimate

**Emergency stop:**
```bash
# On PNP — stops the loop immediately
ssh doug@192.168.22.14 "sudo systemctl stop stored-boat-heartbeat"

# Clear phase2 flag file
ssh doug@192.168.22.14 "sudo rm -f /var/lib/stored-boat/phase2_active"

# Clear phase2_active in DB (run on centralsk if it's up, else wait for it to boot)
ssh doug@192.168.22.15 "docker exec dk400-postgres psql -U dk400 -d dk400 -c \
  'UPDATE cruising.stored_mode_state SET phase2_active=false, low_runway_readings=0 WHERE id=1;'"

# Restart heartbeat once stable
ssh doug@192.168.22.14 "sudo systemctl start stored-boat-heartbeat"
```

**If centralsk is down after the loop:**
Check `bank.45.15` from PNP first:
```bash
ssh doug@192.168.22.14 "curl -s http://localhost:80/signalk/v1/api/vessels/self/electrical/switches/bank/45/15/state"
```
- Value=1 but no ping: Pi is halted with power applied → needs power cycle (see circuit control section above)
- Value=0: circuit is off → restore power with authenticated PUT

**COMMS_URL on PNP heartbeat:** must be Tailscale IP `http://100.121.19.37:3500` — the home LAN IP `192.168.20.19` is unreachable from the boat. If Telegram messages from the daemon are silently failing, check this first.

---

## Activation / deactivation

### Arming stored mode (departing)
1. Hub toggle → "Boat is STORED" + confirm (`/boat-status/`)
2. Verify `cruising.vessel_config.mode = 'stored'`
3. Verify SK `vessel.mode` path = `"stored"` (voyage-events plugin publishes within 1–2 s)
4. Enable arid bilge scheduler: `POST /api/bilge/arid/schedule/enable {"enabled":true}`
5. Verify alarm-manager TTS suppressed: `POST /alarm-manager/test` → should return `{suppressed:true}`
6. Confirm storedBoat 2.0 executor acknowledges new mode in logs (once built)

### Disarming stored mode (returning)
1. Hub toggle → "Boat is CREWED" + confirm
2. Arid bilge reverts to unit's internal 3h timer; scheduler stops controlling circuit 48.10
3. Announcements resume
4. storedBoat 2.0 executor goes passive

---

## Key cross-references

| Topic | Where |
|---|---|
| Arid bilge internals, cycle decomposer, circuit wiring | `bilge-pumps` skill (cruising-app) |
| CLMD16 circuits, N2K bus topology, WAN topology | `homelab-boat-network` skill |
| PNP watchdog, resilience matrix, all 45+ open items | `fixer/docs/runbooks/stored-boat-plan.md` |
| Power management, SoC monitoring | `homelab-centralsk` skill |
