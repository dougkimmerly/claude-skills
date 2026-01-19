# Automatic Entry Triggers

The logbook automatically creates entries based on SignalK data changes. Triggers are defined in `plugin/triggers.js`.

## Trigger Types

### 1. Trip Start/End

**Requires:** `signalk-autostate` plugin

```
navigation.state: "not-under-way" → "sailing" | "motoring"  → Trip Start
navigation.state: "sailing" | "motoring" → "not-under-way"  → Trip End
```

Trip end entries include the `end: true` marker.

### 2. Hourly Underway Logging

When vessel state is `sailing` or `motoring`:
- Creates entry every hour on the hour
- Captures current position, speed, wind, weather
- Interval managed in `plugin/index.js`

### 3. Navigation State Changes

| Transition | Entry Created |
|------------|---------------|
| → anchored | "Anchored" with position |
| → moored | "Moored" with position |
| → sailing | "Sailing" with sail config if available |
| → motoring | "Motoring" with engine state |
| anchored → | "Anchor up" |
| moored → | "Cast off" |

### 4. Engine Events

```
propulsion.*.state: "stopped" → "running"  → "Engine started"
propulsion.*.state: "running" → "stopped"  → "Engine stopped"
```

**Conditions:**
- Only logs when vessel is NOT already sailing/motoring
- Includes cumulative engine hours from `propulsion.*.runTime`
- Prevents redundant entries during normal sailing

### 5. Autopilot Changes

```
steering.autopilot.mode: changes while underway → Log entry
```

**Modes tracked:**
- `auto` - Heading hold
- `wind` - Wind angle hold
- `route` - Navigation/waypoint following
- `standby` - Disengaged

**Condition:** Only logs when vessel is underway (sailing/motoring)

### 6. Sail Configuration Changes

When `sails.inventory.*` changes:
- Reef count changes
- Furling ratio changes (continuous reefing)
- Sail set/drop events

**Requires:** `sailsconfiguration` plugin

### 7. Crew Changes

```
communication.crewNames: member added   → "Crew joined: [name]"
communication.crewNames: member removed → "Crew left: [name]"
```

## Implementation Pattern

Triggers use state comparison to avoid duplicate entries:

```javascript
// In triggers.js
let previousState = {};

function checkTrigger(path, value) {
  if (previousState[path] === value) return; // No change

  const oldValue = previousState[path];
  previousState[path] = value;

  // Determine if transition warrants an entry
  if (shouldLog(path, oldValue, value)) {
    createEntry(path, oldValue, value);
  }
}
```

## SignalK Paths Monitored

### Navigation
- `navigation.position`
- `navigation.courseOverGround`
- `navigation.headingTrue`
- `navigation.speedOverGround`
- `navigation.speedThroughWater`
- `navigation.log`
- `navigation.state`

### Environment
- `environment.wind.speedTrue`
- `environment.wind.directionTrue`
- `environment.outside.pressure`
- `environment.outside.cloudCoverage`
- `environment.water.surface.state`
- `environment.visibility`

### Propulsion
- `propulsion.*.state`
- `propulsion.*.revolutions`
- `propulsion.*.runTime`

### Steering
- `steering.autopilot.mode`
- `steering.autopilot.active`

### Sails
- `sails.inventory.*`

### Communications
- `communication.crewNames`
- `communication.vhf.channel`

## 15-Minute Buffer

State data is stored in a circular buffer for 15 minutes:

```javascript
const CircularBuffer = require('circular-buffer');
const buffer = new CircularBuffer(15); // 15 entries

// Each minute, snapshot current state
setInterval(() => {
  buffer.enq(getCurrentState());
}, 60000);
```

This allows backdating entries via the `ago` parameter (0-15 minutes).

## Customizing Triggers

To add custom triggers, modify `plugin/triggers.js`:

```javascript
// Example: Log when depth alarm triggers
app.subscriptionmanager.subscribe(
  {
    context: 'vessels.self',
    subscribe: [{ path: 'environment.depth.belowKeel' }]
  },
  unsubscribes,
  (err) => {},
  (delta) => {
    const depth = delta.updates[0].values[0].value;
    if (depth < 3.0) { // Less than 3 meters
      log.appendEntry(new Date().toISOString().split('T')[0], {
        datetime: new Date().toISOString(),
        text: `Shallow water warning: ${depth.toFixed(1)}m`,
        category: 'navigation',
        author: 'auto'
      });
    }
  }
);
```
