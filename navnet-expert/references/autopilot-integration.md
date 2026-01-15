# Autopilot Integration on NavNet

## Raymarine Evolution Autopilot

The boat uses a Raymarine Evolution autopilot system connected via NMEA 2000 (SeaTalk NG).

### SignalK Configuration

| Setting | Value |
|---------|-------|
| **Default Pilot** | raymarineN2K |
| **Hull Type** | sail |
| **Source** | autopilotApi, raymarineN2K |

## Autopilot Paths

### State & Control

| Path | Type | Description |
|------|------|-------------|
| `steering.autopilot.state` | string | standby, auto, route, wind |
| `steering.autopilot.engaged` | boolean | Whether AP is active |
| `steering.autopilot.mode` | string | Current mode |
| `steering.autopilot.defaultPilot` | string | Active pilot ID |
| `steering.autopilot.hullType` | string | sail, motor, etc. |

### Target Settings

| Path | Type | Description |
|------|------|-------------|
| `steering.autopilot.target.headingMagnetic` | rad | Target heading (magnetic) |
| `steering.autopilot.target.headingTrue` | rad | Target heading (true) |
| `steering.autopilot.target.windAngleApparent` | rad | Target AWA (wind mode) |

### Rudder Feedback

| Path | Type | Description |
|------|------|-------------|
| `steering.rudderAngle` | rad | Current rudder position |
| `steering.autopilot.autoTurn` | object | Auto-tack settings |

## Controlling the Autopilot

### Via REST API

```bash
# Engage autopilot (auto mode)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": "auto"}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/state

# Disengage (standby)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": "standby"}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/state

# Set heading (1.57 rad = 90 degrees)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": 1.57}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/target/headingMagnetic

# Adjust heading +10 degrees
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": 10}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/actions/adjustHeading

# Tack to port
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": "port"}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/actions/tack
```

### Via WebSocket

```javascript
const ws = new WebSocket('ws://192.168.22.16/signalk/v1/stream?subscribe=none');

ws.onopen = () => {
  // Subscribe to autopilot state
  ws.send(JSON.stringify({
    context: 'vessels.self',
    subscribe: [
      { path: 'steering.autopilot.*', period: 1000 },
      { path: 'steering.rudderAngle', period: 500 }
    ]
  }));
};

// Send command
function engageAutopilot(heading) {
  ws.send(JSON.stringify({
    context: 'vessels.self',
    updates: [{
      source: { label: 'my-app' },
      values: [
        { path: 'steering.autopilot.target.headingMagnetic', value: heading },
        { path: 'steering.autopilot.state', value: 'auto' }
      ]
    }]
  }));
}
```

## Autopilot Modes

| Mode | Description | Target Path |
|------|-------------|-------------|
| `standby` | Disengaged | - |
| `auto` | Hold heading | `target.headingMagnetic` |
| `wind` | Hold wind angle | `target.windAngleApparent` |
| `route` | Follow active route | Route waypoints |
| `track` | Track to waypoint | `navigation.destination` |

## Unit Conversions

All autopilot angles are in radians:

```javascript
// Degrees to radians
const radians = degrees * (Math.PI / 180);

// Radians to degrees
const degrees = radians * (180 / Math.PI);

// Examples
// 90° = 1.5708 rad
// 180° = 3.1416 rad
// 270° = 4.7124 rad
```

## Plugin Integration

### autopilot / autopilotApi

The SignalK autopilot plugin provides PUT handlers for controlling the Raymarine.

**Features**:
- State management (engage/disengage)
- Heading adjustment
- Tack commands
- Route following

### signalk-to-nmea2000

Converts SignalK PUT commands to NMEA 2000 PGNs for the autopilot.

**PGNs Used**:
- PGN 127237: Heading/Track Control
- PGN 65379: Seatalk Pilot Heading
- PGN 126208: Command Group Function

## Safety Considerations

1. **Always have manual override** - Physical autopilot controls should always be accessible
2. **Watch for alarms** - Monitor `notifications.steering.autopilot.*`
3. **Verify engagement** - Check `steering.autopilot.engaged` after commands
4. **Rate limiting** - Don't send commands too rapidly
5. **Authentication** - PUT handlers may require authentication

## Troubleshooting

### Autopilot Not Responding

```bash
# Check autopilot state
curl http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot

# Check data sources
curl http://192.168.22.16/signalk/v1/api/sources | grep -i autopilot

# Check logs
ssh doug@192.168.22.16 "journalctl -u signalk | grep -i autopilot"
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| PUT returns 401 | Not authenticated | Login or add auth token |
| PUT returns 404 | Handler not registered | Check autopilot plugin enabled |
| State doesn't change | NMEA 2000 not sending | Check signalk-to-nmea2000 plugin |
| Wrong heading | Unit mismatch | Ensure radians, not degrees |
