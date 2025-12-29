# SignalK Paths Reference

All paths use dot-notation: `category.subcategory.property`

## Navigation

| Path | Description | Unit |
|------|-------------|------|
| `navigation.position.latitude` | Latitude | degrees |
| `navigation.position.longitude` | Longitude | degrees |
| `navigation.speedOverGround` | Speed over ground | m/s |
| `navigation.speedThroughWater` | Speed through water | m/s |
| `navigation.courseOverGroundTrue` | COG true | rad |
| `navigation.courseOverGroundMagnetic` | COG magnetic | rad |
| `navigation.headingTrue` | Heading true | rad |
| `navigation.headingMagnetic` | Heading magnetic | rad |
| `navigation.magneticVariation` | Local variation | rad |
| `navigation.destination.waypoint` | Active waypoint | object |
| `navigation.gnss.satellites` | Satellite count | integer |
| `navigation.gnss.horizontalDilution` | HDOP | ratio |

### Anchor Paths

| Path | Description | Unit |
|------|-------------|------|
| `navigation.anchor.position` | Anchor drop position | {latitude, longitude} |
| `navigation.anchor.maxRadius` | Alarm radius | m |
| `navigation.anchor.currentRadius` | Current distance from anchor | m |
| `navigation.anchor.rodeDeployed` | Chain/rode deployed | m |
| `navigation.anchor.state` | Anchor state | string |

## Environment

| Path | Description | Unit |
|------|-------------|------|
| `environment.depth.belowSurface` | Depth below surface | m |
| `environment.depth.belowTransducer` | Depth below transducer | m |
| `environment.depth.belowKeel` | Depth below keel | m |
| `environment.wind.speedTrue` | True wind speed | m/s |
| `environment.wind.speedApparent` | Apparent wind speed | m/s |
| `environment.wind.angleTrue` | True wind angle | rad |
| `environment.wind.angleApparent` | Apparent wind angle | rad |
| `environment.wind.directionTrue` | True wind direction | rad |
| `environment.outside.temperature` | Air temperature | K |
| `environment.outside.humidity` | Relative humidity | 0-1 |
| `environment.outside.pressure` | Barometric pressure | Pa |
| `environment.water.temperature` | Water temperature | K |
| `environment.current.setTrue` | Current direction | rad |
| `environment.current.drift` | Current speed | m/s |
| `environment.tide.heightNow` | Current tide height | m |

## Electrical

| Path | Description | Unit |
|------|-------------|------|
| `electrical.batteries.{id}.voltage` | Battery voltage | V |
| `electrical.batteries.{id}.current` | Battery current | A |
| `electrical.batteries.{id}.stateOfCharge` | State of charge | 0-1 |
| `electrical.batteries.{id}.capacity.stateOfHealth` | Battery health | 0-1 |
| `electrical.batteries.{id}.temperature` | Battery temp | K |
| `electrical.chargers.{id}.current` | Charger output | A |
| `electrical.inverters.{id}.ac.power` | Inverter power | W |
| `electrical.solar.{id}.panelPower` | Solar panel power | W |
| `electrical.switches.{id}.state` | Switch state | boolean |

## Propulsion

| Path | Description | Unit |
|------|-------------|------|
| `propulsion.{id}.revolutions` | Engine RPM | Hz |
| `propulsion.{id}.temperature` | Engine temp | K |
| `propulsion.{id}.oilPressure` | Oil pressure | Pa |
| `propulsion.{id}.oilTemperature` | Oil temp | K |
| `propulsion.{id}.coolantTemperature` | Coolant temp | K |
| `propulsion.{id}.fuel.rate` | Fuel consumption | m³/s |
| `propulsion.{id}.exhaustTemperature` | Exhaust temp | K |
| `propulsion.{id}.runTime` | Engine hours | s |
| `propulsion.{id}.state` | Engine state | string |

## Tanks

| Path | Description | Unit |
|------|-------------|------|
| `tanks.fuel.{id}.currentLevel` | Fuel level | 0-1 |
| `tanks.fuel.{id}.capacity` | Tank capacity | m³ |
| `tanks.fuel.{id}.currentVolume` | Current volume | m³ |
| `tanks.freshWater.{id}.currentLevel` | Water level | 0-1 |
| `tanks.wasteWater.{id}.currentLevel` | Waste level | 0-1 |
| `tanks.blackWater.{id}.currentLevel` | Black water level | 0-1 |
| `tanks.liveWell.{id}.currentLevel` | Live well level | 0-1 |

## Notifications

| Path | Description | Value |
|------|-------------|-------|
| `notifications.{path}.state` | Alarm state | nominal/normal/alert/warn/alarm/emergency |
| `notifications.{path}.message` | Alarm message | string |
| `notifications.{path}.method` | Alert methods | [visual, sound] |

## Steering

| Path | Description | Unit |
|------|-------------|------|
| `steering.rudderAngle` | Rudder position | rad |
| `steering.autopilot.state` | AP state | string |
| `steering.autopilot.mode` | AP mode | string |
| `steering.autopilot.target.headingTrue` | AP target heading | rad |
