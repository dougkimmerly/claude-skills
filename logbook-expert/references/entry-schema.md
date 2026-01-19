# Logbook Entry Schema

## Complete Entry Structure

```yaml
# Required
datetime: "2024-01-15T14:30:00.000Z"  # ISO 8601 UTC

# Common fields
text: "Descriptive note about the event"
category: "navigation"  # navigation | engine | radio | maintenance
author: "doug"          # username or "auto" for automatic

# Position data
position:
  latitude: 49.123456    # decimal degrees
  longitude: -123.456789
  source: "GPS"          # GNSS source identifier

# Navigation data
heading: 250.5           # degrees true
course: 248.3            # degrees COG
speed:
  sog: 6.5               # knots (speed over ground)
  stw: 6.2               # knots (speed through water)
log: 1234.5              # nautical miles (cumulative)

# Weather data
wind:
  speed: 12.3            # knots
  direction: 315         # degrees true
barometer: 1013.5        # hPa (millibars)

# Observations (manual)
observations:
  seaState: 3            # WMO sea state code 0-9
  cloudCoverage: 5       # oktas 0-8
  visibility: 7          # fog scale 0-9

# Engine data
engine:
  hours: 450.5           # cumulative engine hours
  rpm: 2200              # current RPM

# Radio data
vhf: 16                  # VHF channel number

# Crew
crewNames:
  - doug
  - maggie

# Trip markers
end: true                # marks end of trip (optional)
```

## Categories

| Category | Use For |
|----------|---------|
| `navigation` | Position updates, course changes, arrivals/departures |
| `engine` | Engine start/stop, hours, maintenance |
| `radio` | VHF calls, channel changes, communications |
| `maintenance` | Repairs, equipment checks, system issues |

## Observation Codes

### Sea State (WMO Code 3700)

| Code | Description | Wave Height |
|------|-------------|-------------|
| 0 | Calm (glassy) | 0 m |
| 1 | Calm (rippled) | 0-0.1 m |
| 2 | Smooth | 0.1-0.5 m |
| 3 | Slight | 0.5-1.25 m |
| 4 | Moderate | 1.25-2.5 m |
| 5 | Rough | 2.5-4 m |
| 6 | Very rough | 4-6 m |
| 7 | High | 6-9 m |
| 8 | Very high | 9-14 m |
| 9 | Phenomenal | >14 m |

### Cloud Coverage (Oktas)

| Oktas | Description |
|-------|-------------|
| 0 | Clear sky |
| 1 | 1/8 or less |
| 2 | 2/8 |
| 3 | 3/8 |
| 4 | 4/8 (half) |
| 5 | 5/8 |
| 6 | 6/8 |
| 7 | 7/8 or more |
| 8 | Overcast |

### Visibility (Fog Scale)

| Code | Description | Range |
|------|-------------|-------|
| 0 | Dense fog | <50 m |
| 1 | Thick fog | 50-200 m |
| 2 | Moderate fog | 200-500 m |
| 3 | Light fog | 500-1000 m |
| 4 | Thin fog | 1-2 km |
| 5 | Haze | 2-4 km |
| 6 | Light haze | 4-10 km |
| 7 | Clear | 10-20 km |
| 8 | Very clear | 20-50 km |
| 9 | Exceptionally clear | >50 km |

## Validation

Entries are validated against JSON Schema definitions in `schema/openapi.yaml`. The validator uses dereferenced schemas for nested objects (position, speed, observations).

```javascript
// In Log.js
const validator = new Validator();
validator.validate(entry, entrySchema, { throwError: true });
```

## Unit Notes

**IMPORTANT:** Unlike SignalK (which uses SI units), the logbook stores human-friendly units:

| Field | Logbook Unit | SignalK Unit |
|-------|--------------|--------------|
| Speed | knots | m/s |
| Heading/Course | degrees | radians |
| Pressure | hPa | Pascals |
| Temperature | °C | Kelvin |
| Distance | nm | meters |

The `format.js` module handles conversions when creating entries from SignalK state.
