# NMEA 2000 PGNs for Digital Switching

## PGN 127500 - Load Controller Connection State

Reports the connection and status of each load controller channel.

### Transmission

- Rate: Every 250ms + on change
- Source: CLMD12, CLMD16

### Fields

| Field | Type | Description |
|-------|------|-------------|
| Sequence ID | uint8 | Message sequence |
| Connection ID | uint8 | Channel number |
| State | uint8 | See states below |
| Status | uint8 | Operating status |
| PWM Duty Cycle | uint8 | 0-100% for dimming |
| TimeON | uint16 | Seconds channel has been on |

### Connection States

| Value | State |
|-------|-------|
| 0 | Disconnected |
| 1 | Connected |
| 2 | Error |
| 3 | Locked Out |
| 4 | Programming |

## PGN 127501 - Binary Switch Bank Status

Reports the on/off state of up to 28 switches per instance.

### Transmission

- Rate: Every 15 seconds + on change
- Source: CLMD12, CLMD16

### Fields

| Field | Type | Description |
|-------|------|-------------|
| Instance | uint8 | Bank instance (0, 1, 2...) |
| Indicator 1-28 | 2 bits each | Switch states |

### Switch State Values (2 bits)

| Value | Meaning |
|-------|---------|
| 0 | Off |
| 1 | On |
| 2 | Error |
| 3 | Unavailable |

### Instance Mapping

| Instance | Switches |
|----------|----------|
| 0 | 1-28 |
| 1 | 29-56 |
| 2 | 57-84 |

## PGN 127502 - Binary Switch Control

Command to change switch states. This is what SignalK sends to control switches.

### Transmission

- Direction: Received by CLMD12, CLMD16
- Rate: On demand (command)

### Fields

| Field | Type | Description |
|-------|------|-------------|
| Instance | uint8 | Target bank instance |
| Indicator 1-28 | 2 bits each | Commanded states |

### Control Values (2 bits)

| Value | Meaning |
|-------|---------|
| 0 | Turn Off |
| 1 | Turn On |
| 2 | Reserved |
| 3 | No Change |

### Example: Turn on Switch 5, Instance 0

```
Instance: 0
Indicators 1-4: 3 (no change)
Indicator 5: 1 (turn on)
Indicators 6-28: 3 (no change)
```

## PGN 127751 - DC Voltage/Current

Reports electrical measurements from load controllers.

### Transmission

- Rate: Every 1.5 seconds + on change
- Source: CLMD12, CLMD16

### Fields

| Field | Type | Description |
|-------|------|-------------|
| SID | uint8 | Sequence ID |
| Connection Number | uint8 | Channel |
| DC Voltage | uint16 | Voltage × 0.01V |
| DC Current | int16 | Current × 0.1A (signed) |
| Temperature | uint16 | Kelvin × 0.01K |

### Calculating Values

```javascript
voltage = rawVoltage * 0.01;  // Volts
current = rawCurrent * 0.1;   // Amps
tempC = (rawTemp * 0.01) - 273.15;  // Celsius
```

## PGN 126208 - NMEA Command Group Function

Alternative method to control devices using standardized NMEA commands.

### Usage

Some SignalK plugins use this PGN instead of 127502 for broader compatibility.

### Command Format

Complex multi-field format - see NMEA 2000 specification for details.

## SignalK to PGN Mapping

### Reading Switch States (127501 → SignalK)

```javascript
// n2k-signalk converts PGN 127501 to:
electrical.switches.bank.{instance}.{channel}.state
```

### Controlling Switches (SignalK → 127502)

```javascript
// signalk-to-nmea2000 converts PUT request to PGN 127502
PUT /signalk/v1/api/vessels/self/electrical/switches/bank/0/5/state
{"value": 1}
// → PGN 127502 with instance=0, switch 5=ON
```

## Debugging PGNs

### Using candump

```bash
# View raw CAN traffic
candump can0

# Filter for switching PGNs
candump can0 | grep -E "1F214|1F215|1F216"
```

### PGN to CAN ID Conversion

```
CAN ID format: PPP PPPP PPSS SSSS SSSS (29-bit)
P = Priority (3 bits)
PGN = 18 bits
S = Source address (8 bits)

127501 (0x1F20D) → CAN ID includes this in the identifier
```
