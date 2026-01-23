# Waveshare ESP32-S3-Relay with SensESP

ESP32-based relay controllers for auxiliary switching via SignalK, typically used for network infrastructure devices that need remote reboot capability.

## Hardware

### Waveshare ESP32-S3-Relay-6CH

| Specification | Value |
|---------------|-------|
| MCU | ESP32-S3 |
| Relays | 6× (10A @ 250VAC / 30VDC) |
| Contacts | Both NO and NC available |
| GPIO Pins | 1, 2, 41, 42, 45, 46 |
| Interface | WiFi (802.11 b/g/n) |
| Power | 7-36V DC or USB-C |

## Firmware

Uses SensESP framework (https://signalk.org/SensESP/) to connect to SignalK servers via WebSocket.

### Repository

https://github.com/dougkimmerly/WaveshareESP32-S3-Relay-SK

### Configuration (main.cpp)

```cpp
// Group name for SignalK paths
const String groupName = "reboot2";

// Relay definitions
RelayInfo relays[] = {
  // Pin  Name              NO     Reboot ms
  { 1,  "starlinkInverter", true,  60000 },
  { 2,  "cellModem",        false, 5000  },
  { 41, "pepRouter",        false, 60000 },
  { 42, "dataHub",          false, 60000 },
  { 45, "fleetOne",         false, 60000 },
  { 46, "relay6",           true,  60000 }
};
```

### Contact Type Strategy

- **NO (Normally Open)**: Device OFF when relay unpowered. Use for non-critical loads.
- **NC (Normally Closed)**: Device ON when relay unpowered. Use for critical network infrastructure so devices stay powered if ESP32 fails.

## SignalK Integration

### Data Paths

| Path | Type | Description |
|------|------|-------------|
| `electrical.{group}.{relay}.state` | bool | Current relay state |
| `electrical.commands.switch.{relay}` | string | Value listener for on/off |
| `electrical.commands.reboot.{relay}` | bool | Value listener for reboot trigger |

### PUT Request Values

| Value | Action |
|-------|--------|
| `"on"` or `true` | Turn relay ON |
| `"off"` or `false` | Turn relay OFF |
| `"reboot"` | Execute reboot sequence |

### Authentication

SignalK PUT requests require authentication:

```bash
# Get token
TOKEN=$(curl -s -X POST "http://host/signalk/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"signalk"}' | \
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Use token
curl -X PUT -H "Authorization: Bearer $TOKEN" ...
```

## Web Control Interface

### Location

SignalK webapp installed at: `~/.signalk/node_modules/waveshare-control/`

Accessible at: `http://{signalk-host}/waveshare-control/`

### Features

- Real-time relay state display via WebSocket
- ON/OFF/Reboot buttons for each relay
- Token-based authentication (prompts on first action)
- Auto-reconnect on connection loss
- Periodic polling for state updates

### Installation

```bash
# Create webapp directory
mkdir -p ~/.signalk/node_modules/waveshare-control/public

# Create package.json
cat > ~/.signalk/node_modules/waveshare-control/package.json << 'EOF'
{
  "name": "waveshare-control",
  "version": "1.0.0",
  "description": "Waveshare Relay Control Panel",
  "keywords": ["signalk-webapp"],
  "signalk": { "displayName": "Waveshare Control" }
}
EOF

# Copy index.html to public/
# Restart SignalK to load webapp
sudo systemctl restart signalk
```

## Reboot Sequence

The reboot sequence power-cycles a device for the configured duration:

1. For **NC relay**: Turn ON (opens contact, cuts power), wait, turn OFF (closes contact, restores power)
2. For **NO relay**: Turn OFF (opens contact, cuts power), wait, turn ON (closes contact, restores power)

Useful for:
- Recovering stuck modems/routers
- Automated network monitoring with SignalK plugin
- Remote power cycling of infrastructure devices

## Troubleshooting

### Device Not Appearing in SignalK

1. Check device is on network: `ping {device-ip}`
2. Access SensESP config UI: `http://{device-ip}/`
3. Verify SignalK server address is correct in device config
4. Check SignalK logs: `journalctl -u signalk -f`

### Data Disappears After Server Restart

SignalK prunes stale data (default 60 min). The Waveshare must reconnect and send updates. Either:
- Wait for device to send periodic updates
- Restart the Waveshare device
- Adjust `pruneContextsMinutes` in SignalK settings

### PUT Requests Return 401

Authentication required. Either:
- Use Bearer token in Authorization header
- Login via web interface first (stores cookie)

## Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    WiFi Network                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐       WebSocket        ┌───────────┐ │
│  │  Waveshare   │ ───────────────────────│  SignalK  │ │
│  │ ESP32-S3     │     electrical.        │  Server   │ │
│  │ 192.168.x.x  │     reboot2.*          │           │ │
│  └──────┬───────┘                        └─────┬─────┘ │
│         │                                      │       │
│    6 Relays                              REST/WS API   │
│    (network devices)                           │       │
│                                         ┌──────┴─────┐ │
│                                         │ Web Browser│ │
│                                         │ /waveshare │ │
│                                         │ -control/  │ │
│                                         └────────────┘ │
└─────────────────────────────────────────────────────────┘
```
