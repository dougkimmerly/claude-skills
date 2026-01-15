---
name: navnet-expert
description: NavNet SignalK navigation network expertise for Distant Shores II. Use when working with the NavNet SignalK server (192.168.22.16), navigation data integration, environmental sensors, Victron battery/solar monitoring, Raymarine autopilot, AIS, weather data, fuel tracking, or custom plugin development for the navigation network. Covers vessel-specific data paths, installed plugins, data sources, and integration patterns.
---

# NavNet Expert

Expertise for the NavNet SignalK server on Distant Shores II - the navigation network that handles GPS, instruments, environmental data, battery monitoring, and autopilot integration.

## Quick Reference

### Server Details

| Setting | Value |
|---------|-------|
| **Hostname** | DSIInav |
| **IP Address** | 192.168.22.16 |
| **Port** | 80 |
| **SignalK Version** | 2.19.1 |
| **WebSocket** | ws://192.168.22.16/signalk/v1/stream |
| **TCP** | tcp://192.168.22.16:8375 |

### Quick Commands

```bash
# SSH access
ssh doug@192.168.22.16

# Query API
curl http://192.168.22.16/signalk/v1/api/vessels/self

# Get position
curl http://192.168.22.16/signalk/v1/api/vessels/self/navigation/position

# Get wind data
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/wind
```

### Vessel Info

| Property | Value |
|----------|-------|
| **Name** | Distant Shores II |
| **MMSI** | 316029463 |
| **Call Sign** | CFN7093 |
| **LOA** | 15.11m (~49.5ft) |
| **Beam** | 4.2m |
| **Draft** | 3m max |
| **Air Height** | 20.42m |
| **AIS Type** | Sailing (ID 36) |

## Data Categories

### Navigation Paths

| Path | Description |
|------|-------------|
| `navigation.position` | GPS position (lat/lon) |
| `navigation.speedOverGround` | SOG in m/s |
| `navigation.speedThroughWater` | STW in m/s |
| `navigation.courseOverGroundTrue` | COG true in rad |
| `navigation.headingMagnetic` | Heading magnetic in rad |
| `navigation.headingTrue` | Heading true in rad |
| `navigation.magneticVariation` | Local variation in rad |
| `navigation.rateOfTurn` | ROT in rad/s |
| `navigation.attitude` | Pitch/roll/yaw |
| `navigation.gnss` | GPS satellite info |
| `navigation.trip` | Trip log data |
| `navigation.log` | Total log data |

### Environment Paths

| Path | Description |
|------|-------------|
| `environment.wind.speedApparent` | AWS in m/s |
| `environment.wind.angleApparent` | AWA in rad |
| `environment.wind.speedTrue` | TWS in m/s |
| `environment.wind.directionTrue` | TWD in rad |
| `environment.depth.surfaceToTransducer` | Depth offset |
| `environment.water.temperature` | Water temp in K |
| `environment.outside.temperature` | Air temp in K |
| `environment.outside.pressure` | Barometric in Pa |
| `environment.current` | Current set/drift |
| `environment.tide` | Tide height |
| `environment.sun` / `environment.moon` | Celestial data |
| `environment.forecast` | Weather forecast |

### Electrical Paths

| Path | Description |
|------|-------------|
| `electrical.batteries.{id}.voltage` | Battery voltage |
| `electrical.batteries.{id}.current` | Battery current |
| `electrical.batteries.{id}.stateOfCharge` | SOC (0-1) |
| `electrical.solar.{id}.panelPower` | Solar panel output |
| `electrical.solar.totalPower` | Total solar power |
| `electrical.solar.yieldToday` | Today's solar yield |

**Battery IDs**: 11, 12, 21, 22, 31, 32, 41, 42, 51, 61, 62, 239, 240, 338, 357, 65L, JSE, 6ZT, RJN

**Solar IDs**: archprt, archstb, fwdprt, fwdstb, archInside, archOutside

### Propulsion Paths

| Path | Description |
|------|-------------|
| `propulsion.engine.fuelUsed` | Total fuel used (m³) |
| `propulsion.engine.burnRate` | Current burn rate |
| `propulsion.engine.fuelThisSession` | Session fuel use |

### Tank Paths

| Path | Description |
|------|-------------|
| `tanks.fuel.{id}.currentLevel` | Fuel level (0-1) |
| `tanks.freshWater.{id}.currentLevel` | Water level |
| `tanks.blackWater.{id}.currentLevel` | Holding tank |

### Steering/Autopilot

| Path | Description |
|------|-------------|
| `steering.autopilot.state` | AP state (standby/auto) |
| `steering.autopilot.engaged` | AP engaged boolean |
| `steering.autopilot.mode` | AP mode |
| `steering.autopilot.defaultPilot` | raymarineN2K |

## Data Sources

### Hardware Sources

| Source | Description |
|--------|-------------|
| `NavNet` | Furuno NavNet network gateway |
| `raymarineN2K` | Raymarine autopilot on NMEA 2000 |
| `Victron SmartSolar MPPT VE` | Solar charge controllers |
| `Victron Smart Lithium Battery 12` | Lithium battery BMS |

### Plugin Sources

| Source | Description |
|--------|-------------|
| `signalk-logbook` | Voyage logging |
| `autopilot` / `autopilotApi` | Autopilot integration |
| `derived-data` | Calculated values |
| `openweather-signalk` | Weather data |
| `anchoralarm` | Anchor watch |
| `fusionstereo` | Entertainment system |
| `bt-sensors-plugin-sk` | Bluetooth temp sensors |
| `signalk-node-red` | Node-RED automation |
| `signalk-barometer-trend` | Pressure trend |
| `signalk-autostate` | State automation |
| `tides` | Tide data |
| `envirolog` | Environmental logging |
| `solarLogging` | Solar production logging |
| `fuelUse` | Fuel consumption tracking |
| `sheetsLog` | Google Sheets logging |

### BT Temperature Sensors

| Sensor | Location |
|--------|----------|
| `Main Cabin` | Interior temperature |
| `outside` | Ambient temperature |
| `fridge` | Refrigerator |
| `freezer` | Freezer |
| `engineroom` | Engine room |

## Custom Plugins Location

```
/mnt/usb/src/
├── envirolog/
├── fueluse/
├── openweather-signalk/
├── sheetslog/
└── solarlogging/
```

## Detailed References

- **[references/data-sources.md](references/data-sources.md)** - Complete source documentation
- **[references/electrical-monitoring.md](references/electrical-monitoring.md)** - Victron battery/solar details
- **[references/autopilot-integration.md](references/autopilot-integration.md)** - Raymarine autopilot control
- **[references/environmental-sensors.md](references/environmental-sensors.md)** - BT sensors, weather, depth

## Key Documentation

| Resource | URL |
|----------|-----|
| SignalK Specification | https://signalk.org/specification/latest/ |
| Victron VE.Direct | https://www.victronenergy.com/live/vedirect_protocol:faq |
| Raymarine SeaTalk NG | Raymarine documentation |
