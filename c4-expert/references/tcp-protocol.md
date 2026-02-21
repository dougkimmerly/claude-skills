# Control4 TCP/HTTP Protocol

Working integration between SignalK and Control4 from the signalk-snowmelt plugin.

**Last Updated:** 2026-02-21

## Protocol Overview

| Direction | Protocol | Port | Format | Purpose |
|-----------|----------|------|--------|---------|
| External → C4 | HTTP GET | 50260 | URL commands | Control devices |
| C4 → External | TCP | 50261 | JSON | Status updates |

## Sending Commands to C4 (HTTP GET)

**Format:** `GET http://{c4-ip}:{port}/{commandName}`

**Base URL:** `http://192.168.20.181:50260/`

No payload, no authentication - simple URL triggers the action.

**Important:** The URL path is `/{commandName}` directly — no `/command/` prefix.

### Snow Melt Commands - Per Zone

| Command | Purpose |
|---------|---------|
| `startSouth` | Turn on driveway south zone |
| `stopSouth` | Turn off driveway south zone |
| `startNorth` | Turn on driveway north zone |
| `stopNorth` | Turn off driveway north zone |
| `startTent` | Turn on tent zone |
| `stopTent` | Turn off tent zone |
| `snowMeltStatus` | Request current status of all zones |

**Stagger logic:** The plugin starts south immediately, then schedules north 25 minutes later to avoid power surge. This stagger is handled in the plugin (`startSnowMelt()` in index.js), not in C4.

### Snow Melt Commands - Legacy (deprecated)

| Command | Purpose | Notes |
|---------|---------|-------|
| `startSnow` | Turn on all snow melt zones | Had 25-min inline delay in C4 that blocked re-entry |
| `stopSnow` | Turn off all snow melt zones | Did not cancel pending delay timers |

**Note:** These legacy commands still exist in C4 but are no longer used by the plugin as of 2026-02-21. The inline delay in `startSnow` caused subsequent calls to be ignored while the delay was running.

### Temperature Commands

**Incremental:**
| Command | Effect |
|---------|--------|
| `increaseHeat` | +0.5°C (max 28°C) |
| `decreaseHeat` | -0.5°C (min 18°C) |

**Presets (based on outdoor temp):**
| Command | Outdoor Range |
|---------|---------------|
| `setTemp30` | >30°C |
| `setTemp25` | 25-30°C |
| `setTemp20` | 20-25°C |
| `setTemp15` | 15-20°C |
| `setTemp10` | 10-15°C |
| `setTemp5` | 5-10°C |
| `setTemp0` | 0-5°C |
| `setTemp_5` | -5 to 0°C |
| `setTemp_10` | -10 to -5°C |
| `setTemp_11` | <-10°C |

### Status Requests

| Command | Purpose |
|---------|---------|
| `tempRequestBasement` | Get basement thermostat setpoint |
| `fullTempRequest` | Get all zone temperatures |

## Receiving Status from C4 (TCP JSON)

C4 connects TO the external system (SignalK is the server on port 50261).

**Message Format:**
```json
{
  "type": "messageType",
  "loc": "location",
  "data": <varies>
}
```

### Temperature Messages

**tempChange / tempResponse:**
```json
{ "type": "tempChange", "loc": "basement", "data": 22.5 }
```

**fullTempResponse:**
```json
{
  "type": "fullTempResponse",
  "loc": "Master",
  "data": {
    "temp": 22.5,
    "humidity": 45,
    "hotSet": 23,
    "coolSet": 26
  }
}
```

Zones: Outside, Master, Spare, Living, Kitchen, Basement, Garage

### Snow Melt Messages

**Zone state change:**
```json
{ "type": "snowStart", "loc": "drivewayNorth", "data": 24 }
{ "type": "snowStop", "loc": "drivewaySouth", "data": 24 }
```

Zones: drivewayNorth, drivewaySouth, tent

**Full status response:**
```json
{
  "type": "snowMeltStatus",
  "loc": "Outside",
  "data": {
    "drivewayNorth": 0,
    "drivewaySouth": 0,
    "tent": 0
  }
}
```

## C4 Configuration

### Device: Generic TCP Command (Chowmain) - ID 1108

**IP:** 192.168.20.181
**HTTP Port:** 50260
**TCP Target:** homesk.kbl55.com:50261 (192.168.20.19)

### For Receiving Commands (HTTP)
- Generic TCP Command driver (Chowmain)
- Listens on port 50260
- Each command name maps to a driver event
- Events contain programming to control relays and send TCP status

### For Sending Status (TCP)
- Generic TCP/IP Client driver (binding 6001)
- Points to homesk.kbl55.com:50261
- Sends JSON messages on state changes and in response to status queries

## Example Integrations

### curl
```bash
# Turn on driveway south
curl http://192.168.20.181:50260/startSouth

# Turn on driveway north
curl http://192.168.20.181:50260/startNorth

# Stop all zones
curl http://192.168.20.181:50260/stopSouth
curl http://192.168.20.181:50260/stopNorth

# Query status
curl http://192.168.20.181:50260/snowMeltStatus

# Increase heat
curl http://192.168.20.181:50260/increaseHeat
```

### n8n HTTP Request
```
Method: GET
URL: http://192.168.20.181:50260/startSouth
```

### Home Assistant rest_command
```yaml
rest_command:
  c4_start_south:
    url: http://192.168.20.181:50260/startSouth
    method: GET
  c4_stop_south:
    url: http://192.168.20.181:50260/stopSouth
    method: GET
  c4_start_north:
    url: http://192.168.20.181:50260/startNorth
    method: GET
  c4_stop_north:
    url: http://192.168.20.181:50260/stopNorth
    method: GET
  c4_increase_heat:
    url: http://192.168.20.181:50260/increaseHeat
    method: GET
```

### Python TCP Client (receive status)
```python
import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind(('0.0.0.0', 50261))
sock.listen(1)

conn, addr = sock.accept()
while True:
    data = conn.recv(1024)
    if data:
        msg = json.loads(data.decode())
        print(f"C4: {msg['type']} - {msg['loc']}: {msg['data']}")
```

## Gotchas

1. **No acknowledgment** - HTTP commands are fire-and-forget
2. **No retry logic** - failed commands aren't retried
3. **No encryption** - relies on local network security
4. **URL path** - commands are at root path (`/startSouth`), NOT `/command/startSouth`
5. **Single-zone control** - temperature commands only affect basement
6. **C4 inline delays** - avoid delays in C4 event programming; they block re-entry. Handle timing in the external system instead.

## Communication Flow Example

```
1. Plugin detects snow forecast
2. Plugin → C4: GET http://192.168.20.181:50260/startSouth
3. C4 activates driveway south relay
4. C4 → Plugin: TCP {"type":"snowStart","loc":"drivewaySouth","data":24}
5. Plugin waits 25 minutes (setTimeout)
6. Plugin → C4: GET http://192.168.20.181:50260/startNorth
7. C4 activates driveway north relay
8. C4 → Plugin: TCP {"type":"snowStart","loc":"drivewayNorth","data":24}
9. Plugin updates SignalK state
```

## Source

Documented from signalk-snowmelt plugin (dougkimmerly/signalk-snowmelt).
See `plugin/index.js` for implementation details.
