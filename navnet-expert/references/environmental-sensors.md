# Environmental Sensors on NavNet

## Bluetooth Temperature Sensors

The boat uses Govee/Inkbird-style Bluetooth temperature sensors integrated via the `bt-sensors-plugin-sk` plugin.

### Sensor Locations

| Sensor ID | Location | Path |
|-----------|----------|------|
| Main Cabin | Saloon | `environment.inside.mainCabin.temperature` |
| outside | Cockpit/exterior | `environment.outside.temperature` |
| fridge | Refrigerator | `environment.inside.fridge.temperature` |
| freezer | Freezer | `environment.inside.freezer.temperature` |
| engineroom | Engine compartment | `environment.inside.engineroom.temperature` |

### Querying Temperature Data

```bash
# All inside temperatures
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/inside

# Specific sensor
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/inside/fridge/temperature

# Outside temperature
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/outside/temperature
```

### Temperature Units

All temperatures in SignalK are in **Kelvin**:

```javascript
// Kelvin to Celsius
const celsius = kelvin - 273.15;

// Celsius to Kelvin
const kelvin = celsius + 273.15;

// Kelvin to Fahrenheit
const fahrenheit = (kelvin - 273.15) * 9/5 + 32;
```

## Wind Data

Wind data comes from the NavNet instruments via NMEA 2000.

### Wind Paths

| Path | Unit | Description |
|------|------|-------------|
| `environment.wind.speedApparent` | m/s | Apparent wind speed |
| `environment.wind.angleApparent` | rad | Apparent wind angle |
| `environment.wind.speedTrue` | m/s | True wind speed (calculated) |
| `environment.wind.angleTrueWater` | rad | True wind angle through water |
| `environment.wind.angleTrueGround` | rad | True wind angle over ground |
| `environment.wind.directionTrue` | rad | True wind direction |
| `environment.wind.speedOverGround` | m/s | Wind speed over ground |
| `environment.wind.averageSpeed` | m/s | Averaged wind speed |
| `environment.wind.maximumGust` | m/s | Max gust recorded |
| `environment.wind.gustPercentage` | 0-1 | Gust relative to average |

### Wind Unit Conversions

```javascript
// m/s to knots
const knots = ms * 1.94384;

// Knots to m/s
const ms = knots * 0.514444;

// Radians to degrees
const degrees = radians * (180 / Math.PI);
```

### Querying Wind Data

```bash
# All wind data
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/wind

# Apparent wind only
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/wind/speedApparent
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/wind/angleApparent
```

## Depth Data

Depth data from the NavNet depth transducer.

### Depth Paths

| Path | Unit | Description |
|------|------|-------------|
| `environment.depth.belowSurface` | m | Depth below water surface |
| `environment.depth.belowTransducer` | m | Depth below transducer |
| `environment.depth.belowKeel` | m | Depth below keel |
| `environment.depth.surfaceToTransducer` | m | Transducer offset (0.9m on this boat) |

### Querying Depth

```bash
curl http://192.168.22.16/signalk/v1/api/vessels/self/environment/depth
```

## Barometric Pressure

From instruments and the `signalk-barometer-trend` plugin.

### Pressure Paths

| Path | Unit | Description |
|------|------|-------------|
| `environment.outside.pressure` | Pa | Current barometric pressure |
| `environment.outside.pressureTrend` | Pa/s | Pressure change rate |

### Pressure Conversions

```javascript
// Pascal to millibar/hPa
const mbar = pascal / 100;

// Pascal to inches of mercury
const inHg = pascal * 0.0002953;
```

## Water Temperature

From the through-hull transducer.

| Path | Unit | Description |
|------|------|-------------|
| `environment.water.temperature` | K | Sea water temperature |

## Weather Forecast

From the `openweather-signalk` plugin using OpenWeather API.

### Forecast Paths

| Path | Description |
|------|-------------|
| `environment.forecast` | Weather forecast object |
| `environment.forecast.temperature` | Predicted temp |
| `environment.forecast.wind` | Predicted wind |
| `environment.forecast.description` | Conditions text |

## Celestial Data

Sun and moon data for navigation and planning.

### Paths

| Path | Description |
|------|-------------|
| `environment.sun.sunrise` | Sunrise time (ISO 8601) |
| `environment.sun.sunset` | Sunset time |
| `environment.sunlight` | Daylight duration |
| `environment.moon.phase` | Moon phase |
| `environment.moon.rise` | Moonrise time |
| `environment.moon.set` | Moonset time |

## Current Data

Ocean current from instruments or calculated.

| Path | Unit | Description |
|------|------|-------------|
| `environment.current.setTrue` | rad | Current direction |
| `environment.current.drift` | m/s | Current speed |

## Tide Data

From the `tides` plugin.

| Path | Unit | Description |
|------|------|-------------|
| `environment.tide.heightNow` | m | Current tide height |
| `environment.tide.nextHigh` | object | Next high tide |
| `environment.tide.nextLow` | object | Next low tide |

## Subscribing to Environmental Data

```javascript
const ws = new WebSocket('ws://192.168.22.16/signalk/v1/stream?subscribe=none');

ws.onopen = () => {
  ws.send(JSON.stringify({
    context: 'vessels.self',
    subscribe: [
      { path: 'environment.wind.*', period: 1000 },
      { path: 'environment.depth.*', period: 2000 },
      { path: 'environment.inside.*.temperature', period: 30000 },
      { path: 'environment.outside.*', period: 10000 },
      { path: 'environment.water.temperature', period: 10000 }
    ]
  }));
};
```

## Alerts

Environmental alerts configured in notifications:

| Alert | Threshold | Path |
|-------|-----------|------|
| Shallow depth | < 3m | `notifications.environment.depth.shallow` |
| High wind | > 15 m/s | `notifications.environment.wind.highWind` |
| Fridge temp | > 10°C | `notifications.environment.inside.fridge.highTemperature` |
| Freezer temp | > -10°C | `notifications.environment.inside.freezer.highTemperature` |
