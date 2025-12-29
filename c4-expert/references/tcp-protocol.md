# Control4 TCP/HTTP Protocol

Working integration between SignalK and Control4 from the signalk-snowmelt plugin.

## Protocol Overview

| Direction | Protocol | Port | Format | Purpose |
|-----------|----------|------|--------|---------|
| External → C4 | HTTP GET | configurable | URL commands | Control devices |
| C4 → External | TCP | 50261 | JSON | Status updates |

## Sending Commands to C4 (HTTP GET)

**Format:** `GET http://{c4-ip}:{port}/command/{commandName}`

No payload, no authentication - simple URL triggers the action.

### Snow Melt Commands

| Command | Purpose |
|---------|---------|
| `startSnow` | Turn on all snow melt zones |
| `stopSnow` | Turn off all snow melt zones |
| `snowMeltStatus` | Request current status of all zones |

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
{ "type": "snowStart", "loc": "drivewayNorth", "data": null }
{ "type": "snowStop", "loc": "drivewaySouth", "data": null }
```

Zones: drivewayNorth, drivewaySouth, tent

**Full status response:**
```json
{
  "type": "snowMeltStatus",
  "data": {
    "drivewayNorth": true,
    "drivewaySouth": false,
    "tent": true
  }
}
```

## C4 Configuration Required

### For Receiving Commands (HTTP)
- Generic TCP Command driver (Chowmain) or similar
- Configured to listen on HTTP port
- Programming to map URLs to device actions

### For Sending Status (TCP)
- Generic TCP/IP Client driver
- Points to external system IP:50261
- Sends JSON messages on state changes

## Example Integrations

### curl
```bash
# Turn on snow melt
curl http://192.168.20.43:8080/command/startSnow

# Increase heat
curl http://192.168.20.43:8080/command/increaseHeat
```

### n8n HTTP Request
```
Method: GET
URL: http://192.168.20.43:8080/command/startSnow
```

### Home Assistant rest_command
```yaml
rest_command:
  c4_start_snow:
    url: http://192.168.20.43:8080/command/startSnow
    method: GET
  c4_increase_heat:
    url: http://192.168.20.43:8080/command/increaseHeat
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
4. **Hard-coded zones** - zone names are fixed in code
5. **Single-zone control** - temperature commands only affect basement

## Communication Flow Example

```
1. External system detects snow forecast
2. External → C4: GET http://c4-ip:8080/command/startSnow
3. C4 activates snow melt relays
4. C4 → External: TCP {"type":"snowStart","loc":"drivewayNorth"}
5. C4 → External: TCP {"type":"snowStart","loc":"drivewaySouth"}
6. External updates dashboard/state
```

## Source

Documented from signalk-snowmelt plugin (dougkimmerly/signalk-snowmelt).
See `plugin/index.js` for implementation details.
