---
name: powernet-expert
description: Maretron MPower digital switching expertise for marine electrical systems. Use when working with CLMD12/16 load controllers, CKM12 keypads, VMM6 rocker switches, NMEA 2000 switching PGNs (127500-127502), SignalK switch integration, or programming MPower devices with N2KAnalyzer. Covers switch instance/channel mapping, circuit control via SignalK, and digital switching network architecture.
---

# PowerNet Expert

Expertise for Maretron MPower digital switching systems and their integration with SignalK.

## Quick Reference

### MPower Device Family

| Device | Function | Channels | Max Load |
|--------|----------|----------|----------|
| **CLMD12** | 12-channel DC load controller | 4×5A, 6×10A, 2×12A | 75A total |
| **CLMD16** | 16-channel DC load controller | 4×25A, 12×12A | 125A total |
| **CKM12** | 12-button customizable keypad | 12 programmable buttons | - |
| **VMM6** | 6-position rocker switch | 6 Contura-style switches | - |
| **CBMD12** | Bypass module | Mechanical backup for CLMD12 | - |

### Key NMEA 2000 PGNs

| PGN | Name | Direction | Purpose |
|-----|------|-----------|---------|
| **127500** | Load Controller Connection State | TX | Reports channel status |
| **127501** | Binary Switch Bank Status | TX | Switch on/off states |
| **127502** | Binary Switch Control | RX | Command to change state |
| **127751** | DC Voltage/Current | TX | Electrical measurements |

### Switch Instance/Channel Mapping

NMEA 2000 organizes switches into banks of 28:

| Instance | Switch Range | Channels |
|----------|--------------|----------|
| 0 | Switches 1-28 | 1-28 |
| 1 | Switches 29-56 | 1-28 |
| 2 | Switches 57-84 | 1-28 |

### SignalK Switch Paths

```
electrical.switches.bank.{instance}.{channel}.state    # Switch state (0/1)
electrical.switches.bank.{instance}.{channel}.meta     # Metadata (name, etc.)
```

### Control Switch via REST API

```bash
# Turn on switch (instance 0, channel 5)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": 1}' \
  http://signalk-host/signalk/v1/api/vessels/self/electrical/switches/bank/0/5/state

# Turn off
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": 0}' \
  http://signalk-host/signalk/v1/api/vessels/self/electrical/switches/bank/0/5/state
```

### Recommended SignalK Plugins

| Plugin | Purpose |
|--------|---------|
| `pdjr-skplugin-switchbank` | Relay control via PUT requests, metadata injection |
| `signalk-n2k-virtual-switch` | Virtual switch emulation, responds to PGN 127502 |
| `signalk-to-nmea2000` | Send SignalK data back to NMEA 2000 network |

## Detailed References

- **[references/devices.md](references/devices.md)** - MPower device specifications and capabilities
- **[references/pgns.md](references/pgns.md)** - NMEA 2000 PGN details and field definitions
- **[references/switch-mapping.md](references/switch-mapping.md)** - Instance/channel conventions and planning
- **[references/plugins.md](references/plugins.md)** - SignalK plugin configuration for MPower
- **[references/programming.md](references/programming.md)** - N2KAnalyzer workflow and device setup
- **[references/waveshare-sensesp.md](references/waveshare-sensesp.md)** - ESP32 relay controllers with SensESP

## Network Architecture

PowerNet (digital switching) should be physically separated from NavNet (navigation) to:
- Isolate power distribution from navigation data
- Prevent switching traffic from affecting chart updates
- Allow independent troubleshooting

```
┌─────────────┐         ┌─────────────┐
│   NavNet    │         │  PowerNet   │
│ (Navigation)│         │  (MPower)   │
└──────┬──────┘         └──────┬──────┘
       │                       │
  Chartplotter            SignalK Server
  Instruments             CLMD12/16
  AIS, Radar              CKM12, VMM6
```

## Auxiliary Switching (SensESP/ESP32)

For network infrastructure and auxiliary loads not on NMEA 2000, ESP32-based relay controllers using SensESP provide SignalK integration.

### Waveshare ESP32-S3-Relay-6CH

| Spec | Value |
|------|-------|
| Relays | 6 (NO/NC configurable) |
| Framework | SensESP 3.x |
| Connection | WiFi → SignalK WebSocket |
| Control | PUT requests + value listeners |

### SignalK Paths (SensESP)

```
electrical.{group}.{relay}.state           # Relay state (true/false)
electrical.commands.switch.{relay}         # Value listener for on/off
electrical.commands.reboot.{relay}         # Value listener for reboot
```

### Control via REST API

```bash
# Turn on relay (with auth)
curl -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"value": "on"}' \
  http://signalk-host/signalk/v1/api/vessels/self/electrical/{group}/{relay}/state

# Reboot sequence (power cycle)
curl -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"value": "reboot"}' \
  http://signalk-host/signalk/v1/api/vessels/self/electrical/{group}/{relay}/state
```

### Web Control Page

A SignalK webapp at `/waveshare-control/` provides browser-based relay control.

## Caframo Fan Controllers (SensESP)

ESP32-based controllers for Caframo 12V fans with variable speed control via simulated button presses.

### Fan Controller Inventory

| Fan | Hostname | SignalK Path | Location |
|-----|----------|--------------|----------|
| Starboard Cabin | stbCabinFanControl.local | sensors.stbCabinfan/power | Starboard cabin |
| Port Cabin | prtCabinFanControl.local | sensors.prtCabinfan/power | Port cabin |
| Saloon | saloonFanControl.local | sensors.saloonfan/power | Saloon |
| Galley | galleyFanControl.local | sensors.galleyfan.power | Galley |
| Maggie | maggieFanControl.local | sensors.maggiefan/power | Maggie's cabin |

### Control API

All fan controllers expose an HTTP API on port 8081:

```bash
# Set fan speed (0=off, 1=low, 2=medium, 3=high)
curl -X PUT -H "Content-Type: application/json" \
  -d '1' \
  http://galleyFanControl.local:8081/setFanSpeed

# Simulate button press (cycles through speeds)
curl -X PUT -H "Content-Type: application/json" \
  -d '4' \
  http://galleyFanControl.local:8081/setFanSpeed
```

### How It Works

1. ESP32 monitors power draw via INA260 sensor
2. Determines current fan speed from power consumption
3. Calculates number of button presses needed to reach target speed
4. Simulates button presses via GPIO (momentary contact)
5. Reports power to SignalK for monitoring

### Power Thresholds (Speed Detection)

| Power Range | Detected Speed |
|-------------|----------------|
| < 2.3W | Off (0) |
| 2.3W - 4W | Low (1) |
| 4W - 5.5W | Medium (2) |
| > 5.5W | High (3) |

### Source Code

Fan controller firmware: `/Users/doug/Programming/dkSRC/boat/SenseESP/caframo/`

## Key Documentation

| Resource | URL |
|----------|-----|
| CLMD12 Manual | https://www.maretron.com/support/manuals/CLMD12UM_1.9.html |
| CLMD16 Manual | https://www.maretron.com/support/manuals/CLMD16UM_1.0.html |
| MPower Overview | https://www.maretron.com/products/digital-switching-mpower/ |
| switchbank Plugin | https://github.com/pdjr-signalk/pdjr-skplugin-switchbank |
| Waveshare Relay Board | https://www.waveshare.com/wiki/ESP32-S3-Relay-6CH |
| SensESP Docs | https://signalk.org/SensESP/ |
