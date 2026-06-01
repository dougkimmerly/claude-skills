---
description: SignalK on CentralSK (192.168.22.15:3000) — the boat's primary N2K data hub. Use when SK paths are missing/stale, iKonvert is hung, dashboards show wrong data, or you need to diagnose what's flowing from PowerNet or NavNet buses into SK. Covers provider config, plugin interactions, ALREADY_INITIALISED recovery, federation fallbacks, and the diagnostic chain raw_serial → canboatjs → n2k-signalk → SK paths.
---

# CentralSK SignalK

SignalK runs on centralsk under user-mode systemd. It is the single authoritative SK instance the cruising-app and all dashboards read from. CentralSK has direct N2K access to **both** the PowerNet bus and the NavNet bus via two iKonvert USB gateways. When SK is dark on either side, the dashboards lie.

For host-level concerns (hardware, services, network) see `homelab-centralsk`. This skill is just SK itself.

## Architecture quick-map

```
N2K PowerNet bus  ──┐
                    ├── iKonvert-power (USB 1-1, FTDI FT232R B400BI8Z)
                    │      └── /dev/ikonvert-power → /dev/ttyUSB? (udev-renamed)
                    │             └── SK provider "ikonvert-power" (canboatjs)
                    │                    └── emits on "nmea2000JsonOut-power" + signalk-n2k-switching
                    │
N2K NavNet bus  ────┐
                    ├── iKonvert-nav   (USB 1-2, FTDI FT232R different serial)
                    │      └── /dev/ikonvert-nav → /dev/ttyUSB? (udev-renamed)
                    │             └── SK provider "ikonvert-nav" (canboatjs, default event names)
                    │                    └── emits on "nmea2000JsonOut" (default)
                    │
                    └── @signalk/n2k-signalk subscribes → maps PGN → electrical.* / navigation.* paths
                          ── e.g. PGN 127501 → electrical.switches.bank.{instance}.{ch}.state
                                    127508  → electrical.batteries.{id}.voltage / current
                                    127506  → electrical.batteries.{id}.capacity.stateOfCharge
                                    129025  → navigation.position
                                    127245  → navigation.rudderAngle
```

Two **federation sources** also feed centralsk:
- `powernet-pi-ble` — subscribes to `electrical.batteries.*` on PNP (192.168.22.14:80) over WS, batteries only
- `navnet-pi-bt` — subscribes to nav+environment on NavNet Pi (192.168.22.16:80) over WS

CentralSK is the only host that reads CLMD16 switch state directly. PNP also has bank.* but via its own bus connection. Federation does NOT carry switch state today.

## Service control

SK runs under user-mode systemd, NOT the old system unit. The system unit at `/etc/systemd/system/signalk.service` is disabled (kept on disk for reference). User unit at `/home/doug/.config/systemd/user/signalk.service`.

```bash
# Status / restart / journal — must export XDG_RUNTIME_DIR
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status signalk
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart signalk
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u signalk -f
```

Service unit has `StartLimitIntervalSec=60 StartLimitBurst=3` to cap SEGV-loops. After 3 restarts in 60s the unit goes to `failed`, which `sk-segv-watchdog.timer` (every 5 min) detects and runs `boot-self-heal` on. See `[[centralsk_bitrot_recovery]]` memory for details.

## Diagnostic chain — when paths are missing

When `curl http://localhost:3000/signalk/v1/api/vessels/self/<path>` returns 404 or stale data, work the chain from the wire backwards:

```bash
# 1. Are RAW PGNs flowing? (provider-agnostic; tests the iKonvert+bus only)
sudo timeout 20 cat /dev/ikonvert-power | awk -F, '{print $2}' | sort -u | head
sudo timeout 20 cat /dev/ikonvert-nav | awk -F, '{print $2}' | sort -u | head
# Expected: list of PGN numbers (127501, 127506, 127508, 127751, 130312, …).
# Empty = bus dead or iKonvert disconnected. Mixed = device alive but maybe stuck.

# 2. Is SK process holding the device?
sudo lsof /dev/ikonvert-power /dev/ikonvert-nav
# Expected: node process from signalk-server.

# 3. Is SK's iKonvert provider successfully handshaking?
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u signalk --since '5 min ago' | grep -i ikonvert
# Healthy: empty (no NAK messages) or a single startup ALREADY_INITIALISED that's then handled.
# Broken: repeated "iKonvert NAK: code=ALREADY_INITIALISED isSetup=true" lines.

# 4. Are PGNs being emitted as SK paths?
curl -s http://localhost:3000/signalk/v1/api/vessels/self | \
  python3 -c 'import sys,json
d=json.load(sys.stdin)
counts={}
def walk(o):
    if isinstance(o,dict):
        s=o.get("$source","")
        if "ikonvert" in s: counts[s]=counts.get(s,0)+1
        for v in o.values(): walk(v)
walk(d)
for k,v in sorted(counts.items()): print(f"{v:5d}  {k}")
'
# Healthy: dozens of paths per ikonvert-* source (e.g. ikonvert-power.1, .2, …).
# Broken: zero paths from one or both.

# 5. Specific PGN path check
curl -s http://localhost:3000/signalk/v1/api/vessels/self/electrical/switches | \
  python3 -c 'import sys,json; print(list(json.load(sys.stdin).keys()))'
# Healthy: ['venus-0', 'venus-1', 'gx', 'bank']
# Missing 'bank': switch state is dark (CLMD16 data not flowing into SK).
```

## iKonvert `ALREADY_INITIALISED` recovery (verified 2026-05-27)

**Symptom:** SK log shows repeating `iKonvert NAK: code=ALREADY_INITIALISED isSetup=true`. SK paths from `ikonvert-power` (or `ikonvert-nav`) are empty even though raw bytes still flow on the device.

**Why this happens:** iKonvert MCUs are powered from the N2K bus, NOT USB. They retain their setup state across USB power events. When SK reconnects, it sends `$PDGY,N2NET_OFFLINE` as the first setup command; the device replies NAK ALREADY_INITIALISED. The canboatjs handler at `node_modules/@canboat/canboatjs/dist/ikonvert.js:192` *does* recognize this and is supposed to mark `isSetup=true` and start streaming — but it only fires on the *first* NAK. Subsequent NAKs are logged but ignored. If the provider state machine is otherwise polluted (e.g. SK was holding the previous tty handle when USB re-enumerated, or only one iKonvert was cycled while SK held the other), inbound PGNs never get decoded into SK paths.

**Triggers we've seen:**
- N2K bus power-cycle (the iKonvert MCU loses bus power briefly, comes back in a state inconsistent with what canboatjs expects)
- USB re-enumeration while SK was still running and holding the old tty
- Manual `echo 0/1 > /sys/bus/usb/.../authorized` on only one device

### Working recovery (verified 2026-05-27)

The recipe that actually works — **stop SK first, cycle BOTH iKonverts together, then start SK.**

```bash
# 1. Identify which USB device tree paths the iKonverts are on
#    (typically 1-1 and 1-2 on the XCY X63G, but verify)
for d in /dev/ikonvert-*; do
  usb=$(udevadm info -q property -n $d | grep ^DEVPATH= | grep -oE 'usb[0-9]+/[0-9-]+' | tail -1)
  echo "$d -> $usb"
done

# 2. Stop SK
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop signalk
sleep 3

# 3. Cycle BOTH USB devices, deauth → reauth, in one batch
for u in 1-1 1-2; do echo 0 | sudo tee /sys/bus/usb/devices/$u/authorized; done
sleep 5
for u in 1-1 1-2; do echo 1 | sudo tee /sys/bus/usb/devices/$u/authorized; done
sleep 5

# 4. Confirm udev re-created the named symlinks
ls -la /dev/ikonvert-* /dev/ttyUSB*

# 5. Start SK
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start signalk

# 6. Wait 30s, then verify
sleep 30
sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u signalk --since '45 sec ago' | grep -i ikonvert
# Expected: empty OR a single ALREADY_INITIALISED that's handled (no repeating NAKs).

curl -s http://localhost:3000/signalk/v1/api/vessels/self/electrical/switches | \
  python3 -c 'import sys,json; print(list(json.load(sys.stdin).keys()))'
# Expected: ['venus-0', 'venus-1', 'gx', 'bank']
```

### Why cycling ONE device doesn't work

Tonight (2026-05-27) I cycled only USB 1-1 (ikonvert-power) while SK was running. USB re-enumerated, udev created a new tty (ttyUSB0 instead of ttyUSB2), but SK was still holding the OLD handle to ikonvert-nav and apparently got into a state where it kept both providers in `ALREADY_INITIALISED`-NAK loops. Cycling BOTH while SK was stopped fixed it.

### What does NOT fix this

- USB authorized cycle while SK is running (SK holds stale tty, recovery fails)
- Restarting SK without cycling USB (iKonvert MCU still says ALREADY_INITIALISED)
- Manually sending `$PDGY,N2NET_OFFLINE` to the device — the MCU may already be in offline state and this doesn't reset its setup
- The two-layer SEGV watchdog (`sk-segv-watchdog`) — it only catches a *failed* unit, not a unit that's `active(running)` but dark on one provider

### Fallback if USB cycle fails entirely

If the recovery above doesn't restore data flow, the boat is still observable via federation:
- **batteries**: `powernet-pi-ble` federation from PNP at 192.168.22.14 already covers `electrical.batteries.*`
- **switches (bank.*) — not federated today**. To add: extend the `powernet-pi-ble` provider's `subscription` in `/opt/signalk/.signalk/settings.json` to include `electrical.switches.bank.*`. PNP's own iKonvert publishes these natively. *Caveat:* PNP and centralsk are on the SAME PowerNet bus, so if the bus itself is down both go dark; this fallback only covers centralsk-iKonvert-specific failure modes.
- **nav/environment**: `navnet-pi-bt` federation from NavNet Pi at 192.168.22.16 covers nav data.

Physical-access last resort: pull the iKonvert from its N2K tee, wait 30 s, plug back in. This fully power-cycles the MCU and clears any persistent state.

## Provider config (canonical, current as of 2026-05-27)

`/opt/signalk/.signalk/settings.json` `pipedProviders`:

| id | type | device / host | event names | role |
|---|---|---|---|---|
| `ikonvert-nav` | NMEA2000 / ikonvert-canboatjs | /dev/ikonvert-nav @ 230400 | default (`nmea2000Out`, `nmea2000JsonOut`) | NavNet bus → SK paths via @signalk/n2k-signalk |
| `ikonvert-power` | NMEA2000 / ikonvert-canboatjs | /dev/ikonvert-power @ 230400 | **custom**: `nmea2000out-power`, `nmea2000JsonOut-power` | PowerNet bus; custom events route to `signalk-n2k-switching` plugin |
| `powernet-pi-ble` | SignalK / ws | 192.168.22.14:80 | n/a (federation) | Backup view of PNP's battery data |
| `navnet-pi-bt` | SignalK / ws | 192.168.22.16:80 | n/a (federation) | Backup view of NavNet data + environment sensors |

The custom event names on `ikonvert-power` exist because the `signalk-n2k-switching` plugin (which handles PUT action handlers for switch control over N2K) needs to know which provider/bus to write back to. The plugin checks `if (src && src.startsWith('ikonvert-power')) return 'nmea2000JsonOut-power'` to route outbound switch commands to the PowerNet bus iKonvert.

## udev — keep iKonvert device names stable

`/etc/udev/rules.d/99-ikonvert.rules` maps the two FT232R serial numbers to fixed names so SK provider config doesn't break when Linux reassigns ttyUSB numbers:

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="B400BI8Z", SYMLINK+="ikonvert-power"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="<other-serial>", SYMLINK+="ikonvert-nav"
```

If the symlinks vanish after a USB cycle, re-run `sudo udevadm trigger`.

## Plugins worth knowing about

| Plugin | Role | If broken |
|---|---|---|
| `signalk-n2k-switching` | Registers PUT handlers on `electrical.switches.bank.*.state`. Routes outbound commands to ikonvert-power. | Switch control from cruising-app dies. Reading state still works because n2k-signalk handles inbound. |
| `signalk-switch-automation` | Higher-level switch policy/automation logic. | Less critical — read the plugin's own config. |
| `signalk-n2k-virtual-switch` | Lets SK paths appear as switchable circuits for plugins that don't know N2K. | Affects whatever consumers depend on virtual switches. |
| `alarm-manager` | TTS announcements + zone-based alerting. **Mode-aware** as of 2026-05-26 — reads vessel-config mode, suppresses fridge/freezer zones in stored mode. | See `[[alarm_manager_bridge]]`. |
| `centralsk-monitor` | Publishes /sys/class/hwmon temps to SignalK so CPU/disk temps show in the boat data. | New custom plugin (2026-05-26). |
| `bilge-sense` | Bilge pump runtime tracking. | Gives no telemetry on bilge runs. |

Enabled/disabled flags live in `/opt/signalk/.signalk/plugin-config-data/<plugin>.json` under `"enabled": true|false`. Vessel-mode-watcher toggles a known list of plugins when mode changes.

## Useful diagnostic one-liners

```bash
# What unique PGNs appeared on each bus in last 20 sec
sudo timeout 20 cat /dev/ikonvert-power | awk -F, '{print $2}' | sort -u
sudo timeout 20 cat /dev/ikonvert-nav   | awk -F, '{print $2}' | sort -u

# Top SK sources by path count (which providers are actually feeding paths)
curl -s http://localhost:3000/signalk/v1/api/vessels/self | python3 -c 'import sys,json
d=json.load(sys.stdin); c={}
def w(o):
  if isinstance(o,dict):
    s=o.get("$source")
    if s: c[s]=c.get(s,0)+1
    for v in o.values(): w(v)
w(d); [print(f"{n:5d}  {k}") for k,n in sorted(c.items(), key=lambda x:-x[1])[:20]]'

# Federation peers status
curl -s http://localhost:3000/signalk/v1/api/sources | python3 -m json.tool | grep -A2 'powernet-pi-ble\|navnet-pi-bt'

# Subscription manager queue depth (high == backpressure)
curl -s http://localhost:3000/signalk/v1/applications/serverstatus 2>/dev/null  # may 404 — depends on SK version
```

## Cerbo GX / signalk-venus-plugin recovery (verified 2026-05-28)

### Symptom

Cruising-app dashboards show "⚠ CERBO STALE — shore / solar / DC load / AC load numbers may be wrong. (no change for Ns) Try power-cycling the Cerbo." `electrical.cerbo.dbusLive = false`, `dbusStaleSeconds` growing.

### Diagnostic chain (in order)

```bash
# 1. Is Cerbo MQTT publishing fresh values directly?
ssh doug@192.168.22.15 "timeout 5 mosquitto_sub -h 192.168.22.25 -p 1883 -t 'N/+/system/0/Dc/System/Power' -W 5 -v"
# If you see values streaming → Cerbo is fine, plugin is the problem.
# If silent → Cerbo MQTT broker wedged (rarer).

# 2. Does Cerbo DBus internal state match?
ssh doug@192.168.22.15 "sshpass -p transport ssh -o StrictHostKeyChecking=no root@192.168.22.25 'dbus -y com.victronenergy.system /Dc/System/Power GetValue'"
# If non-null → Cerbo's internal DBus is healthy.

# 3. What does SK have for the alarm-trigger path?
ssh doug@192.168.22.15 "curl -s 'http://localhost:3000/signalk/v1/api/vessels/self/electrical/venus/dcPower' | python3 -m json.tool"
# value=null with advancing timestamps → plugin is consuming MQTT but producing null deltas

# 4. Plugin error log
ssh doug@192.168.22.15 "sudo -u doug XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u signalk --since '5 min ago' | grep -iE 'venus|TypeError|MqttClient'"
```

### Known plugin bug — TypeError on null CustomName (patched 2026-05-28)

`signalk-venus-plugin@2.3.0` crashes on incoming MQTT messages when any device reports a null `CustomName` value. Stack trace ends with `TypeError: Expected the input to be 'string | string[]' at camelCase`. Once the crash fires, the MQTT message handler dies but the rest of SK keeps running — every venus-sourced SK path has a stuck stale timestamp from before the crash.

**Patch** (at `/opt/signalk/.signalk/node_modules/signalk-venus-plugin/dist/index.js` ~line 560):

```bash
ssh doug@192.168.22.15 "FILE=/opt/signalk/.signalk/node_modules/signalk-venus-plugin/dist/index.js
sudo cp \$FILE \$FILE.bak-\$(date +%Y-%m-%d)
sudo sed -i 's|customNames\\[senderName\\] = (0, camelcase_1.default)(message.value);|if (typeof message.value === \"string\" \\&\\& message.value.length > 0) { customNames[senderName] = (0, camelcase_1.default)(message.value); } else { customNames[senderName] = instance; }|' \$FILE"
# Then restart SK.
```

Upstream fix needed — the if/else `(typeof message.value === 'string')` guard should be PR'd to the plugin's GitHub. Until then, re-apply this patch after any plugin update.

### Cerbo SSH access (root, password)

Cerbo SSH is normally disabled. Doug enabled it via Settings → General → Access Level → Root on 2026-05-28 to recover from a stale-DBus situation while away from the boat. Credentials: `root@192.168.22.25` password `transport`.

```bash
ssh doug@192.168.22.15 "sshpass -p transport ssh -o StrictHostKeyChecking=no root@192.168.22.25 '<command>'"
```

Useful commands once in:
- `dbus -y com.victronenergy.system /Dc/System/Power GetValue` — read live DBus value
- `ls /service/` — Venus OS service list (flashmq, dbus-systemcalc-py, dbus-vebus-to-pvinverter, etc.)
- `svstat /service/<name>` — service status
- `svc -d /service/<name>; svc -u /service/<name>` — stop/start a service
- `reboot` — full Cerbo reboot (~30-60s downtime; autonomous BMS in Lynx Shunt hardware keeps batteries safe during reboot)

### Recovery procedure (escalating)

1. **Patch venus plugin null-CustomName crash** (above) if not already applied. Restart SK. Verify `electrical.venus.dcPower` has a real value with a recent timestamp.
2. **Restart SK plugin only** (if you have SK admin auth): `POST /skServer/plugins/signalk-venus-plugin/disable` then `/enable`. Cycles the MQTT connection.
3. **Restart SK entirely**: `systemctl --user restart signalk`. ~30s SK downtime. Triggers fresh MQTT subscribe.
4. **Reboot the Cerbo** via SSH: `sshpass -p transport ssh root@192.168.22.25 reboot`. ~60-90s Cerbo downtime. Use when DBus internal state itself is suspect (mosquitto_sub silent or values frozen at the broker).
5. **Power-cycle Cerbo via PowerNet circuit** — last resort if SSH is also broken. Requires the Cerbo to be on a controllable CLMD16 channel.

### Zombie SK process holding stale MQTT connection (recovered 2026-05-28)

If `systemctl --user restart signalk` reports success but `electrical.venus.*` values stay
frozen at constant numbers (timestamps advance, values don't change), there may be a
**zombie node process** from an earlier SK invocation still holding an MQTT connection
to Cerbo. The new SK process is reading from the broker but the zombie is corrupting
the broker's session state.

**Detection:**

```bash
ssh doug@192.168.22.15 "sudo ss -tnp 2>/dev/null | grep '192.168.22.25:1883'"
```

If you see MORE than one ESTAB connection, or one with a large `Recv-Q` (unread bytes
on the socket, e.g. 246132), that's a zombie. Check its PID's age:

```bash
ssh doug@192.168.22.15 "ps -o pid,ppid,user,etime,cmd -p <pid>"
```

Zombies have `PPID=1` (orphaned to init) and elapsed time predating the most recent
systemd-reported SK start. The current healthy SK process has PPID = the user-systemd
manager PID, not 1.

**Fix:** kill the zombie directly:

```bash
ssh doug@192.168.22.15 "sudo kill <zombie-pid>"
```

The current SK process's MQTT subscription will start receiving fresh broadcasts within
seconds. `electrical.cerbo.dbusLive` should flip to `true` within ~90s.

**Prevention:** when restarting SK, verify the OLD process actually died before
running other diagnostics. `systemctl --user show signalk -p MainPID` shows the
current PID; cross-check `ps -ef | grep 'signalk-server -c /opt/signalk'` for
extras.

### Known stale path that survives plugin restart

After today's patch + Cerbo reboot, **`electrical.batteries.lynxShunt.*` paths** stay stale even when other venus paths recover. The plugin's `battery/6/CustomName` resolution path doesn't recover after the initial crash window — but battery telemetry remains fresh via the **N2K/iKonvert-power path** (`electrical.batteries.0.*`). Consumers (dashboards, planner) should fall back to the N2K source for battery state. Not a data loss, just a duplicate stale path.

This is a secondary plugin bug — separate from the null-CustomName crash — and a candidate for the same upstream fix.

---

## Related

- `[[homelab-centralsk]]` — host hardware, network, services other than SK
- `[[homelab-boat-network]]` — N2K bus topology, why the two buses are separated
- `[[centralsk_bitrot_recovery]]` (memory) — SK SEGV-loop recovery via golden tarballs
- `[[mbb300]]` — Maretron MBB300C (separate read-only telemetry on NavNet bus)
- `[[stored-boat]]` — vessel-mode toggle and how it gates SK plugin enable/disable
