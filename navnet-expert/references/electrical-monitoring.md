# Electrical Monitoring on NavNet

## Battery Bank Configuration

### Victron Smart Lithium Batteries

The boat uses Victron Smart Lithium batteries with built-in BMS, communicating via Bluetooth and VE.Direct.

**Battery IDs in SignalK**:
| ID | Description |
|----|-------------|
| 11, 12 | Bank 1 (House) |
| 21, 22 | Bank 2 |
| 31, 32 | Bank 3 |
| 41, 42 | Bank 4 |
| 51 | Starter battery |
| 61, 62 | Auxiliary |
| 239, 240, 338, 357 | Victron device addresses |
| 65L, JSE, 6ZT, RJN | Named batteries |

### Querying Battery Data

```bash
# All batteries
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/batteries

# Specific battery
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/batteries/11

# Voltage
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/batteries/11/voltage
```

### Battery Paths

| Path | Unit | Description |
|------|------|-------------|
| `electrical.batteries.{id}.voltage` | V | Battery voltage |
| `electrical.batteries.{id}.current` | A | Current (+ charging, - discharging) |
| `electrical.batteries.{id}.stateOfCharge` | 0-1 | SOC percentage |
| `electrical.batteries.{id}.temperature` | K | Battery temperature |
| `electrical.batteries.{id}.capacity.stateOfHealth` | 0-1 | Battery health |
| `electrical.batteries.averageVoltage` | V | Average across banks |
| `electrical.batteries.averageTemperature` | K | Average temperature |

## Solar Panel Configuration

### Victron SmartSolar MPPT Controllers

| ID | Location | Description |
|----|----------|-------------|
| archprt | Arch port | Port side arch panels |
| archstb | Arch starboard | Starboard arch panels |
| fwdprt (fwdPrt) | Forward port | Port side forward panels |
| fwdstb (fwdStb) | Forward starboard | Starboard forward panels |
| archInside | Arch inside | Interior arch panels |
| archOutside | Arch outside | Exterior arch panels |

### Solar Paths

| Path | Unit | Description |
|------|------|-------------|
| `electrical.solar.{id}.panelVoltage` | V | Panel input voltage |
| `electrical.solar.{id}.panelCurrent` | A | Panel current |
| `electrical.solar.{id}.panelPower` | W | Panel power output |
| `electrical.solar.{id}.chargingCurrent` | A | Charge current to battery |
| `electrical.solar.Power` | W | Combined power |
| `electrical.solar.totalPower` | W | Total all controllers |
| `electrical.solar.yieldToday` | Wh | Today's production |

### Querying Solar Data

```bash
# All solar
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/solar

# Total power
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/solar/totalPower

# Today's yield
curl http://192.168.22.16/signalk/v1/api/vessels/self/electrical/solar/yieldToday
```

## Power Tracking

### Daily Statistics

| Path | Description |
|------|-------------|
| `electrical.totalPowerUsed` | Lifetime consumption |
| `electrical.todayPowerUsed` | Today's consumption |
| `electrical.altPowerProducedToday` | Alternator production |
| `electrical.shorePowerProducedToday` | Shore power used |
| `electrical.shorePowerProducedTotal` | Lifetime shore power |
| `electrical.shuntPowerToday` | Shunt measurements |

### Calculated Values

| Path | Description |
|------|-------------|
| `electrical.calculated.*` | Derived power values |
| `electrical.production.*` | Production totals |

## Shore Power / AC

| Path | Description |
|------|-------------|
| `electrical.ac` | AC system status |
| `electrical.acIn` | Shore power input |
| `electrical.acOut` | Inverter output |
| `electrical.shorePower` | Shore power connection |

## Alternator

| Path | Description |
|------|-------------|
| `electrical.alternator.voltage` | Output voltage |
| `electrical.alternator.current` | Output current |

## Converter/Inverter

| Path | Description |
|------|-------------|
| `electrical.converter.*` | DC-DC converter |
| `electrical.venus.*` | Victron Venus GX data |

## Monitoring via WebSocket

```javascript
const ws = new WebSocket('ws://192.168.22.16/signalk/v1/stream?subscribe=none');

ws.onopen = () => {
  ws.send(JSON.stringify({
    context: 'vessels.self',
    subscribe: [
      { path: 'electrical.batteries.*.voltage', period: 5000 },
      { path: 'electrical.batteries.*.stateOfCharge', period: 10000 },
      { path: 'electrical.solar.totalPower', period: 5000 }
    ]
  }));
};

ws.onmessage = (event) => {
  const delta = JSON.parse(event.data);
  // Process battery/solar updates
};
```

## Alerts Configuration

Battery alerts configured in SignalK notifications:

| Alert | Threshold | Path |
|-------|-----------|------|
| Low voltage | < 12.0V | `notifications.electrical.batteries.*.lowVoltage` |
| High voltage | > 14.4V | `notifications.electrical.batteries.*.highVoltage` |
| Low SOC | < 20% | `notifications.electrical.batteries.*.lowStateOfCharge` |
