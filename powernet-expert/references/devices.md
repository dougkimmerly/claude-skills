# Maretron MPower Devices

## CLMD12 - 12-Channel DC Load Controller

### Specifications

| Spec | Value |
|------|-------|
| Channels | 12 |
| Channel Distribution | 4×5A, 6×10A, 2×12A |
| Total Capacity | 75A continuous |
| Input Voltage | 9-32 VDC |
| Fusing | Electronic (auto-resetting) |
| NMEA 2000 | Yes (LEN 4) |

### Channel Layout

| Channels | Rating | Typical Use |
|----------|--------|-------------|
| 1-4 | 5A | LED lights, instruments |
| 5-10 | 10A | Navigation lights, pumps |
| 11-12 | 12A | Larger loads, fans |

### Features

- Electronic circuit protection (no physical fuses)
- Auto-retry after overload
- Voltage and current monitoring per channel
- Programmable channel names
- Discrete I/O for external triggers
- Dimming support (channels 1-4)

## CLMD16 - 16-Channel DC Load Controller

### Specifications

| Spec | Value |
|------|-------|
| Channels | 16 |
| Channel Distribution | 4×25A, 12×12A |
| Total Capacity | 125A continuous |
| Input Voltage | 9-32 VDC |
| Fusing | Electronic (auto-resetting) |
| NMEA 2000 | Yes (LEN 5) |

### Channel Layout

| Channels | Rating | Typical Use |
|----------|--------|-------------|
| 1-4 | 25A | Windlass, thrusters, large pumps |
| 5-16 | 12A | General loads |

### Features

- All CLMD12 features plus:
- Higher capacity channels for heavy loads
- Better suited for larger vessels

## CKM12 - 12-Button Customizable Keypad

### Specifications

| Spec | Value |
|------|-------|
| Buttons | 12 |
| Display | None (LED indicators per button) |
| Mounting | Flush or surface |
| NMEA 2000 | Yes (LEN 1) |

### Button Programming

Each button can be programmed to:
- Toggle a single channel
- Toggle multiple channels (scene)
- Momentary control
- Dimmer control (press-and-hold)

### LED Indicators

- Off: Circuit off
- On: Circuit on
- Flashing: Fault condition

## VMM6 - 6-Position Rocker Switch

### Specifications

| Spec | Value |
|------|-------|
| Switches | 6 Contura-style rockers |
| Display | Backlit legends |
| Mounting | Standard Contura cutout |
| NMEA 2000 | Yes (LEN 1) |

### Features

- Drop-in replacement for traditional Contura switches
- Networked control (any switch can control any circuit)
- Customizable legends
- Backlight brightness control

## CBMD12 - Circuit Breaker Module (Bypass)

### Purpose

Provides mechanical backup for CLMD12 in case of:
- CLMD12 failure
- Network failure
- Programming issues

### Operation

- Normally passes through CLMD12 control
- Manual override switches for each channel
- Physical circuit breakers for protection

### Installation

Mount alongside CLMD12, wired in series with load outputs.

## Device Addressing

### Instance Numbers

Each device needs a unique instance number on the network:

```
CLMD12 #1: Instance 0 (Switches 1-12)
CLMD12 #2: Instance 1 (Switches 13-24)
CLMD16 #1: Instance 2 (Switches 25-40)
```

### Device Instance vs Switch Instance

- **Device Instance**: Identifies the physical device
- **Switch Instance**: Identifies the bank (0-28, 29-56, etc.)

Configure carefully to avoid conflicts!

## Wiring Considerations

### Power Input

- Use appropriate wire gauge for total load
- Install main fuse at battery
- Keep power leads short

### NMEA 2000

- Standard DeviceNet Micro connectors
- Proper termination (120Ω each end)
- Max backbone length: 100m
- Max drop length: 6m

### Load Outputs

- Size wire for individual channel capacity
- Use appropriate terminals
- Label everything!
