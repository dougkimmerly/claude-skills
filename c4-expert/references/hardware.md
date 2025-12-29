# Control4 Hardware Reference

## Controllers

### Current Generation (CORE Series)

| Model | Use Case | Key Features |
|-------|----------|---------------|
| CORE 1 | Entry/secondary | PoE+, 4 IR/serial, 1 digital audio |
| CORE 3 | Mid-size | More I/O, better processing |
| CORE 5 | Large homes | 8 IR ports, 2 serial, HDMI out |

### Previous Generation (EA Series)

| Model | Use Case | Key Features |
|-------|----------|---------------|
| EA-1 | Entry/secondary | Basic controller |
| EA-3 | Primary | Good balance |
| EA-5 | Large installs | Maximum I/O |

### Legacy (HC Series)

No longer supported but still in many homes:
- HC-200, HC-250, HC-300
- HC-500, HC-800, HC-1000

**Note:** Very old systems may need dealer intervention for OS updates.

## Matrix Amplifiers

### C4-8AMP1-B (4-Zone)

| Spec | Value |
|------|-------|
| Power | 60W @ 8Ω, 120W @ 4Ω |
| Inputs | 4 analog + 2 digital |
| Outputs | 4 stereo zones |
| Features | Matrix switching, parametric EQ |
| Network | 10/100 Ethernet |

**Front Panel:**
- Input assignment per zone
- Volume/gain per zone
- Clip indicators
- Network status

### C4-16AMP3-B (8-Zone)

| Spec | Value |
|------|-------|
| Power | 120W @ 8Ω, 220W @ 4Ω |
| Inputs | 8 analog |
| Outputs | 8 stereo zones |
| Features | Matrix switching, parametric EQ, volume limiting |
| Network | 10/100 Ethernet |

### Amplifier Configuration

**Via Front Panel:**
1. Press Config button
2. Use Select Dial to navigate
3. Set input assignments per zone
4. Configure network (DHCP/Static)

**Via Composer:**
- Full EQ configuration
- Volume limits
- Zone naming
- Input assignments

### Telnet Debug Console

Both amps expose passive debug via telnet:
```bash
telnet 192.168.20.41 23
```
- Shows activity log
- No commands accepted
- Useful for monitoring

## Keypads & Switches

### Keypad Types

| Type | Buttons | Features |
|------|---------|----------|
| Configurable | 2-6 | LED customization, multi-tap |
| Wireless | 2-6 | Battery powered, Zigbee |
| LUX | Various | Modern design, premium |

### LED Customization

- On/Off colors (per button)
- Brightness levels
- Active state tracking

### Button Events

| Event | Trigger |
|-------|----------|
| Press | Single tap |
| Release | Button released |
| Single Tap | Quick press |
| Double Tap | Two quick presses |
| Triple Tap | Three quick presses |
| Hold | Press and hold |

### Switch/Dimmer Reset

9-9-9 sequence: Tap top 9×, bottom 9×, top 9× (pause between sets)

## Zigbee Mesh

### Architecture

- **Mesh Controller:** Zserver + ZAP on single controller
- **Router Nodes:** Powered devices (switches, keypads)
- **End Nodes:** Battery devices (remotes, sensors)

### Best Practices

1. **Controller Placement:**
   - Not in equipment rack
   - Central to device locations
   - Away from WiFi access points

2. **Mesh Density:**
   - More routers = stronger mesh
   - 15-20 devices per mesh controller
   - Avoid dead zones

3. **Interference:**
   - 2.4 GHz band (same as WiFi)
   - Keep away from microwaves, wireless phones
   - Zigbee channels 25-26 avoid most WiFi

### Zigbee Health (Composer Pro)

- Health grade: A-F based on signal/connectivity
- Device list with signal strength
- From/To failure rates (target: <50/hour)

### Troubleshooting

**Device not responding:**
1. Check power
2. Verify in Zigbee Health
3. Try 9-9-9 reset
4. Re-identify in Composer

**Mesh-wide issues:**
1. Restart Zserver
2. Check for interference
3. Power cycle mesh controller
4. Rebuild mesh (dealer required)

## Remotes

### SR-260

- Two-way Zigbee
- Color LCD
- Hard buttons + touch

### Halo Remotes

- Halo Touch: Touchscreen
- Halo Remote: Traditional buttons
- Dock charges and displays

### Remote Reset

SR-250/260: Remove batteries, hold Red 4 + 0 while reinserting

**"Waiting for Network":**
1. Try reset sequence
2. Re-identify to Zigbee mesh
3. Check mesh controller status

## I/O Extenders

Expand controller I/O:
- Contact inputs (door/window sensors)
- Relay outputs (garage, blinds)
- Serial/IR ports

### Common Uses

- Garage door control
- Fireplace relay
- Gate/access control
- Third-party sensor integration
