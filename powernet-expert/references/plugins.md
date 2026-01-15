# SignalK Plugins for MPower Integration

## pdjr-skplugin-switchbank

The most comprehensive plugin for MPower switch control.

### Installation

```bash
# Via SignalK App Store (recommended)
# Or manually:
npm install pdjr-skplugin-switchbank
```

### Features

- PUT handler for switch control
- Metadata injection (channel names)
- Switch state notifications
- Grouping and scenes

### Configuration

```json
{
  "enabled": true,
  "configuration": {
    "switchbanks": [
      {
        "instance": 0,
        "description": "Main Panel",
        "channels": [
          {
            "index": 1,
            "name": "Salon Overhead",
            "description": "Main salon ceiling lights"
          },
          {
            "index": 2,
            "name": "Galley Counter",
            "description": "Under-cabinet galley lights"
          }
        ]
      }
    ]
  }
}
```

### Controlling Switches

```bash
# Turn on
curl -X PUT http://host:3000/signalk/v1/api/vessels/self/electrical/switches/bank/0/1/state \
  -H "Content-Type: application/json" \
  -d '{"value": 1}'

# Turn off
curl -X PUT http://host:3000/signalk/v1/api/vessels/self/electrical/switches/bank/0/1/state \
  -H "Content-Type: application/json" \
  -d '{"value": 0}'
```

### GitHub

https://github.com/pdjr-signalk/pdjr-skplugin-switchbank

## signalk-to-nmea2000

Converts SignalK commands back to NMEA 2000 PGNs.

### Purpose

When you send a PUT request to change a switch, this plugin:
1. Receives the SignalK command
2. Converts to PGN 127502
3. Transmits on CAN bus
4. CLMD receives and actuates

### Installation

```bash
npm install @signalk/signalk-to-nmea2000
```

### Configuration

```json
{
  "enabled": true,
  "configuration": {
    "pgns": {
      "127502": true
    }
  }
}
```

### Verifying Operation

```bash
# Monitor CAN bus while sending command
candump can0 &
curl -X PUT http://host:3000/signalk/v1/api/vessels/self/electrical/switches/bank/0/1/state \
  -H "Content-Type: application/json" \
  -d '{"value": 1}'
# Should see PGN 127502 on CAN bus
```

### GitHub

https://github.com/SignalK/signalk-to-nmea2000

## signalk-n2k-virtual-switch

Creates virtual switches that respond to PGN 127502.

### Use Case

- Software-defined switches
- Automation triggers
- Testing without hardware

### Configuration

```json
{
  "enabled": true,
  "configuration": {
    "switches": [
      {
        "instance": 10,
        "channel": 1,
        "name": "Virtual Switch 1"
      }
    ]
  }
}
```

## Plugin Interaction Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ REST API    │────▶│ switchbank       │────▶│ signalk-to-n2k  │
│ PUT request │     │ (validates)      │     │ (converts)      │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                      │
                                                      ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ SignalK     │◀────│ n2k-signalk      │◀────│ CAN Bus         │
│ data model  │     │ (parses PGN)     │     │ PGN 127501      │
└─────────────┘     └──────────────────┘     └─────────────────┘
                                                      ▲
                                                      │
                                             ┌─────────────────┐
                                             │ CLMD12/16       │
                                             │ (actuates)      │
                                             └─────────────────┘
```

## Common Plugin Issues

### PUT Returns 404

- switchbank plugin not installed or not enabled
- Path format incorrect
- Check plugin is listed in features API

### Command Sent but Nothing Happens

- signalk-to-nmea2000 not installed
- CAN interface not configured
- CLMD not configured to accept network commands

### State Doesn't Update After Command

- n2k-signalk not parsing PGN 127501
- Network connectivity issue
- Check `candump can0` for traffic

## Recommended Plugin Stack

For full MPower integration:

1. **n2k-signalk** (built-in) - Reads NMEA 2000 → SignalK
2. **pdjr-skplugin-switchbank** - Adds PUT handlers + metadata
3. **signalk-to-nmea2000** - SignalK → NMEA 2000 commands

### Verification Checklist

```bash
# Check plugins are running
curl http://host:3000/signalk/v2/features | jq '.plugins[] | select(.enabled) | .id'

# Check switch paths exist
curl http://host:3000/signalk/v1/api/vessels/self/electrical/switches

# Test control
curl -X PUT http://host:3000/signalk/v1/api/vessels/self/electrical/switches/bank/0/1/state \
  -H "Content-Type: application/json" -d '{"value": 1}'
```
