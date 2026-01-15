# NavNet Data Sources

## Hardware Data Sources

### NavNet (Furuno Network Gateway)

Primary source for navigation instruments via NMEA 2000.

**Provides**:
- GPS position, SOG, COG
- Heading (magnetic/true)
- Depth
- Speed through water
- Wind data (apparent)
- Rate of turn

**PGNs**: 129025, 129026, 127250, 128267, 128259, 130306

### raymarineN2K (Autopilot)

Raymarine Evolution autopilot system on NMEA 2000.

**Provides**:
- Autopilot state
- Heading target
- Mode (standby, auto, track, wind)
- Rudder feedback

**Control via**:
```bash
# Engage autopilot
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": "auto"}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/state

# Set heading
curl -X PUT -H "Content-Type: application/json" \
  -d '{"value": 1.57}' \
  http://192.168.22.16/signalk/v1/api/vessels/self/steering/autopilot/target/headingMagnetic
```

### Victron SmartSolar MPPT VE

Solar charge controllers with VE.Direct/Bluetooth.

**Provides**:
- Panel voltage/current/power
- Battery voltage
- Charge state
- Yield today/total
- Error codes

**Devices**:
- Model 38438 (Arch panels)
- Model 16953 (Forward panels)

### Victron Smart Lithium Battery 12

Lithium battery BMS with Bluetooth.

**Provides**:
- Cell voltages
- State of charge
- Temperature
- Current
- State of health

## Plugin Data Sources

### signalk-logbook

Voyage logging and crew management.

**Paths created**:
- `communication.crewNames`
- Voyage waypoints and tracks

### derived-data

Calculates values from other sources.

**Provides**:
- True wind from apparent
- VMG calculations
- Heel angle from attitude
- Average values

### openweather-signalk

Weather data from OpenWeather API.

**Provides**:
- `environment.forecast`
- Current conditions
- Multi-day forecasts

### bt-sensors-plugin-sk

Bluetooth temperature sensors (Govee/Inkbird style).

**Sensors**:
| ID | Location | Path |
|----|----------|------|
| Main Cabin | Interior | `environment.inside.mainCabin.temperature` |
| outside | Ambient | `environment.outside.temperature` |
| fridge | Refrigerator | `environment.inside.fridge.temperature` |
| freezer | Freezer | `environment.inside.freezer.temperature` |
| engineroom | Engine room | `environment.inside.engineroom.temperature` |

### signalk-barometer-trend

Pressure trend analysis for weather.

**Provides**:
- 3-hour pressure trend
- Storm warnings

### tides

Tide predictions for current location.

**Provides**:
- `environment.tide.heightNow`
- High/low predictions
- Current station info

### fuelUse

Fuel consumption tracking.

**Provides**:
- `propulsion.engine.fuelUsed`
- `propulsion.engine.burnRate`
- Session tracking

### solarLogging

Historical solar production logging.

**Logs to**:
- Local storage
- Optional cloud sync

### envirolog

Environmental data logging.

**Logs**:
- Temperature readings
- Barometric pressure
- Humidity

### sheetsLog

Google Sheets integration for data logging.

**Exports**:
- Position logs
- Environmental data
- Battery status

## Source Priority

When multiple sources provide the same path, SignalK uses priority:

```javascript
// Higher priority sources win
1. NavNet (hardware)
2. raymarineN2K (hardware)
3. Victron (hardware)
4. derived-data (calculated)
5. Plugins (software)
```

## Querying Sources

```bash
# List all sources
curl http://192.168.22.16/signalk/v1/api/sources

# Get data with source info
curl http://192.168.22.16/signalk/v1/api/vessels/self/navigation/position
# Response includes "$source" field
```
