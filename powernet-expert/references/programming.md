# Programming MPower Devices with N2KAnalyzer

## Required Tools

### Maretron N2KAnalyzer V3

- Windows software (can run in VM/Parallels)
- Required for initial device setup
- Download from Maretron website (requires registration)

### Connection Options

| Gateway | Interface | Notes |
|---------|-----------|-------|
| **USB100** | USB to NMEA 2000 | Simplest, direct connection |
| **IPG100** | Ethernet to NMEA 2000 | Remote programming |

## Initial Device Setup

### Step 1: Physical Installation

1. Mount CLMD in accessible location
2. Connect power (observe polarity)
3. Connect to NMEA 2000 backbone
4. Verify network termination

### Step 2: Connect N2KAnalyzer

1. Launch N2KAnalyzer
2. Select connection type (USB100 or IPG100)
3. Connect to network
4. Devices should appear in device list

### Step 3: Set Device Instance

**Critical**: Each CLMD needs unique instance number.

1. Select device in N2KAnalyzer
2. Go to Configuration tab
3. Set "Device Instance" (0, 1, 2, etc.)
4. Write configuration to device

### Step 4: Configure Channels

For each channel:

1. **Enable/Disable**: Activate channels in use
2. **Channel Name**: Descriptive name (shows in diagnostics)
3. **Default State**: On or Off at power-up
4. **Lock State**: Prevent network changes
5. **Overcurrent Threshold**: Adjust if needed

## Programming CKM12 Keypads

### Button Configuration

Each button has:
- **Action Type**: Toggle, Momentary, Scene
- **Target**: Instance + Channel(s)
- **LED Mode**: Follow state, Always on, etc.

### Scene Programming

1. Create new scene
2. Add channels with desired states
3. Assign to button
4. Configure LED behavior

### Example: "All Off" Button

```
Button 1: "All Off"
Type: Scene
Targets:
  - Instance 0, Channels 1-12: OFF
  - Instance 1, Channels 1-12: OFF
LED: On when any target is ON
```

## Programming VMM6 Rockers

### Switch Assignment

1. Select VMM6 in device list
2. Configure each position:
   - Target Instance
   - Target Channel
   - Label text

### LED Backlight

- Follows switch state by default
- Can be configured for always-on

## Discrete I/O Configuration

### What are Discrete I/O?

CLMD devices have inputs for:
- External switches (physical override)
- Sensors (float switches, etc.)
- Triggers (motion sensors, etc.)

### Programming Discrete Inputs

1. Select CLMD in N2KAnalyzer
2. Go to Discrete I/O tab
3. Configure each input:
   - **Trigger Type**: Momentary, Maintained
   - **Action**: Toggle channel, Set ON, Set OFF
   - **Target**: Which channel(s) to affect

### Example: Float Switch for Bilge

```
Discrete Input 1:
  Type: Maintained
  High Action: Turn ON Channel 11 (Bilge Pump)
  Low Action: Turn OFF Channel 11
```

## Configuration Backup

### Exporting Configuration

1. Select device
2. File → Export Configuration
3. Save .n2k file

### Importing Configuration

1. Select device
2. File → Import Configuration
3. Select .n2k file
4. Write to device

**Important**: Keep backups of all device configurations!

## Firmware Updates

### Checking Version

1. Select device in N2KAnalyzer
2. View firmware version in device info

### Updating Firmware

1. Download latest from Maretron
2. File → Update Firmware
3. Select device and firmware file
4. Wait for completion (do not interrupt!)

## Troubleshooting Programming

### Device Not Appearing

1. Check CAN bus connections
2. Verify termination
3. Try different position on backbone
4. Check gateway connection

### Configuration Won't Write

1. Device may be locked
2. Try power cycling device
3. Check for firmware incompatibility

### Changes Not Taking Effect

1. Some changes require power cycle
2. Verify write completed successfully
3. Re-read configuration to confirm

## Best Practices

### Before Programming

- [ ] Document existing configuration
- [ ] Plan instance numbers
- [ ] Create circuit mapping spreadsheet
- [ ] Test network connectivity

### During Programming

- [ ] Program one device at a time
- [ ] Write configuration after each change
- [ ] Verify changes took effect
- [ ] Test each channel physically

### After Programming

- [ ] Export configurations to backup
- [ ] Update documentation
- [ ] Test all keypads and switches
- [ ] Verify SignalK sees all channels

## Integration with SignalK

### After N2KAnalyzer Programming

1. Restart SignalK server
2. Verify switches appear in API:
   ```bash
   curl http://host:3000/signalk/v1/api/vessels/self/electrical/switches
   ```
3. Test control via REST API
4. Configure switchbank plugin with channel names

### Matching N2KAnalyzer to SignalK

| N2KAnalyzer | SignalK Path |
|-------------|--------------|
| Instance 0, Channel 5 | electrical.switches.bank.0.5.state |
| Instance 1, Channel 12 | electrical.switches.bank.1.12.state |
