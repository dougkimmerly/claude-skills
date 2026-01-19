---
name: logbook-expert
description: SignalK Logbook plugin expertise for semi-automatic electronic logbook systems. Use when working with @meri-imperiumi/signalk-logbook - creating/editing log entries, understanding automatic triggers, querying the REST API, modifying the React webapp, extending the plugin, or troubleshooting logbook issues. Covers YAML storage format, entry schema, automatic logging triggers, and webapp components.
---

# SignalK Logbook Expert

Expertise for the @meri-imperiumi/signalk-logbook plugin - a semi-automatic electronic logbook for sailing vessels.

## Quick Reference

### Plugin Info

| Property | Value |
|----------|-------|
| **Package** | `@meri-imperiumi/signalk-logbook` |
| **Version** | 0.7.2 |
| **Author** | Henri Bergius (Meri Imperiumi) |
| **Repo** | https://github.com/meri-imperiumi/signalk-logbook |
| **License** | MIT |

### Data Storage

- **Location:** `~/.signalk/plugin-config-data/signalk-logbook/YYYY-MM-DD.yml`
- **Format:** YAML (human-readable, version-controllable)
- **Units:** Human-friendly (knots, degrees, hPa) - NOT SI units
- **Organization:** One file per day

### Entry Structure (YAML)

```yaml
datetime: "2024-01-15T14:30:00Z"
text: "Manual note about conditions"
category: "navigation"  # navigation | engine | radio | maintenance
author: "doug"          # or "auto" for automatic entries
position:
  latitude: 49.1234
  longitude: -123.5678
  source: "GPS"
heading: 250            # degrees true
course: 248             # degrees COG
speed:
  sog: 6.5              # knots
  stw: 6.2              # knots
log: 1234.5             # nautical miles
wind:
  speed: 12.3           # knots
  direction: 315        # degrees
barometer: 1013.5       # hPa
engine:
  hours: 450.5
vhf: 16
observations:
  seaState: 3           # WMO 0-9
  cloudCoverage: 5      # oktas 0-8
  visibility: 7         # fog scale 0-9
crewNames:
  - doug
  - maggie
```

### REST API

```
GET    /plugins/signalk-logbook/logs              → list dates
GET    /plugins/signalk-logbook/logs/{date}       → entries for date
POST   /plugins/signalk-logbook/logs              → create entry
PUT    /plugins/signalk-logbook/logs/{date}/{dt}  → update entry
DELETE /plugins/signalk-logbook/logs/{date}/{dt}  → delete entry
```

**Create Entry Example:**
```bash
curl -X POST http://192.168.22.16/plugins/signalk-logbook/logs \
  -H "Content-Type: application/json" \
  -d '{"text": "Departed marina", "category": "navigation", "ago": 0}'
```

### Automatic Triggers

| Trigger | Condition |
|---------|-----------|
| Trip start/end | Via signalk-autostate plugin |
| Hourly entries | While sailing or motoring |
| State changes | Anchoring, mooring, sailing, motoring transitions |
| Engine events | Start/stop when not already in motion |
| Autopilot changes | Mode transitions while underway |
| Sail changes | Reef/furl adjustments |
| Crew changes | Roster additions/removals |

### SignalK Paths Monitored

**Navigation:** position, COG, heading, SOG, STW, log, state
**Environment:** wind speed/direction, pressure, sea state, clouds, visibility
**Propulsion:** engine state, RPM, runTime
**Steering:** autopilot mode/active
**Sails:** inventory configuration
**Comms:** crewNames, VHF channel

### Architecture

```
plugin/
├── index.js        # Main plugin - API routes, subscriptions
├── Log.js          # YAML file I/O, CRUD operations
├── format.js       # SI → human units conversion
└── triggers.js     # Automatic entry triggers

src/components/
├── AppPanel.jsx    # Main container, state management
├── Logbook.jsx     # Table view
├── Timeline.jsx    # Card view (reverse chronological)
├── Map.jsx         # Geographic visualization (Pigeon Maps)
├── EntryEditor.jsx # Create/edit modal
├── EntryViewer.jsx # Read-only view modal
├── SailEditor.jsx  # Sail configuration
├── CrewEditor.jsx  # Crew roster manager
└── FilterEditor.jsx # Date range filter
```

### Key Methods (Log.js)

```javascript
// List available log dates
log.listDates() → ["2024-01-15", "2024-01-16", ...]

// Get entries for a date
log.getDate("2024-01-15") → [entry1, entry2, ...]

// Get single entry
log.getEntry("2024-01-15T14:30:00Z") → entry

// Write/update entry
log.writeEntry(entry)

// Delete entry
log.deleteEntry("2024-01-15T14:30:00Z")
```

### Unit Conversions (format.js)

```javascript
rad2deg(rad)  // Radians → degrees: (rad * 180) / Math.PI
ms2kt(ms)     // m/s → knots: ms * 1.94384
stateToEntry(state, text, author) // Transform SignalK state to entry
```

### Webapp Access

- **URL:** `http://<server>/@meri-imperiumi/signalk-logbook/`
- **Tabs:** Timeline (cards), Logbook (table), Map (track visualization)
- **Auth:** JWT from SignalK server

### 15-Minute Buffer

The plugin maintains a circular buffer of state data, allowing entries to be backdated up to 15 minutes via the `ago` parameter in POST requests.

## Detailed References

- **[references/entry-schema.md](references/entry-schema.md)** - Full entry schema, validation, observations
- **[references/triggers.md](references/triggers.md)** - Automatic trigger details and conditions
- **[references/api.md](references/api.md)** - Complete REST API with examples
- **[references/webapp.md](references/webapp.md)** - React components and extension points
- **[references/integration.md](references/integration.md)** - Node-RED, external apps, backup strategies

## Dependencies

| Package | Purpose |
|---------|---------|
| yaml | YAML file parsing/writing |
| circular-buffer | 15-min state history |
| jsonschema | Entry validation |
| timezones-list | Timezone selection |
| React + Reactstrap | Webapp UI |
| Pigeon Maps | Map visualization |

## Related Plugins

- **signalk-autostate** - Required for trip start/end detection
- **sailsconfiguration** - Optional sail inventory integration
- **signalk-autopilot** - Optional autopilot state tracking
