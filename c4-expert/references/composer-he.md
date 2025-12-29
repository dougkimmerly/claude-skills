# Composer Home Edition Guide

## Installation & Setup

1. Purchase license ($149) from dealer or customer.control4.com
2. Download from customer.control4.com (Windows only: 7/8/10/11)
3. Requires 4Sight subscription for remote access
4. Controller OS and Composer HE versions must match

## Connecting to Director

**Local Connection:**
1. Ensure PC and controller on same network
2. Launch Composer HE → Click "Local System"
3. Select controller from list → Connect

**Remote Connection (requires 4Sight):**
1. Launch Composer HE → Click "Remote System"
2. Enter customer.control4.com credentials
3. Select controller → Connect

## Monitoring View

Real-time device status and control:
- List View: All devices with status indicators
- Properties: Edit device settings (LED colors, ramp rates)
- Device Control: Test commands directly

**Status Colors:**
- Green = On/Active
- Red = Off/Inactive
- Yellow = Partial/Transitioning

## Programming View

### Event-Action Model

All programming follows: **When [EVENT] → Do [ACTIONS]**

**Event Sources:**
- Device events (button press, state change)
- Agent events (scheduler, timer)
- Variable changes
- System events (startup, connection)

**Action Types:**
- Device commands (on, off, set level)
- Agent commands (activate scene, start timer)
- Variable operations (set, increment)
- Delays (wait X seconds)

### Conditionals

Add logic with If/Then/Else:
```
WHEN: Front Door Keypad - Button 1 - Press
  IF: Time is between 6:00 PM and 11:00 PM
  THEN: Execute "Evening" Lighting Scene
  ELSE: Execute "Daytime" Lighting Scene
```

### Variables

Types available in Composer HE:
- **Boolean:** True/False
- **Number:** Integer or decimal
- **String:** Text values
- **Device:** Reference to another device

Variables enable complex logic:
- Track state across events
- Count occurrences
- Store user preferences

### Loops

Composer HE supports loops for repetitive actions:
- Loop X times
- Loop while condition true
- Include delays between iterations

## Media View

### Music Library
- Scan network shares for MP3, WMA, MP4, M4A, FLAC
- Add album artwork
- Create playlists
- Organize by artist/album/genre

### DVD/Blu-ray
- Disc changer management
- Media lookup service
- Manual entry for custom titles

## Agents View

Agents are pre-built automation components:

### Adding Agents
1. Click "Add" in Agents pane
2. Select agent type
3. Configure in agent properties
4. Program triggers in Programming view

### Agent Types Available in HE

| Agent | Purpose |
|-------|---------|
| Advanced Lighting | Complex scene control |
| Scheduler | Time-based automation |
| Timer | Countdown/repeating timers |
| Macros | Reusable action sequences |
| Media Scenes | Multi-room audio groups |
| Wakeup/Goodnight | Sleep/wake routines |
| Announcements | Audio notifications |
| Custom Buttons | Navigator UI buttons |

## Best Practices

### Project Backups
- File → Back Up As (local copy)
- Regular backups before changes
- Note: Media database backup optional (large)

### Organization
- Use descriptive names for scenes/macros
- Group related programming logically
- Document complex logic with comments (in macro names)

### Performance
- Avoid excessive delays in programming
- Use macros for repeated action sequences
- Test changes immediately after programming

## Limitations vs Composer Pro

| Feature | Composer HE | Composer Pro |
|---------|-------------|---------------|
| Add new devices | ❌ | ✅ |
| Install drivers | ❌ | ✅ |
| Configure connections | ❌ | ✅ |
| Edit programming | ✅ | ✅ |
| Manage media | ✅ | ✅ |
| Configure agents | ✅ | ✅ |
| System design changes | ❌ | ✅ |
| Zigbee configuration | ❌ | ✅ |
