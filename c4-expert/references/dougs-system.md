# Doug's Control4 System

> **System Age:** ~20 years (one of the longest-running C4 installations)
> **Last Updated:** 2025-12-29

## Network Inventory

From homelab network scan (192.168.20.0/24):

| IP | Device | Model | Firmware | Notes |
|----|--------|-------|----------|-------|
| .41 | 8-Channel Amp | C4-8AMP1-B | 03.24.45 | 4-zone matrix, telnet debug console |
| .42 | 16-Channel Amp | C4-16AMP3-B | 03.26.52 | 8-zone matrix, telnet debug console |
| .43 | Main Controller | TBD | TBD | Primary brain, most ports |
| .44 | WattBox | TBD | — | Telnet login (dealer creds), UPS integration potential |
| .45 | Control4 Device | TBD | — | No open ports |
| .181 | Control4 Device | TBD | — | TBD |
| .190 | I/O Extender | TBD | — | SSH (Dropbear), SMB |

## Amplifier Configuration

### C4-8AMP1-B (4-Zone Matrix) - 192.168.20.41

- **Specs:** 60W @ 8Ω, 120W @ 4Ω per channel
- **Inputs:** 4 analog + 2 digital
- **Outputs:** 4 stereo speaker zones
- **Features:** Full matrix switching, parametric EQ
- **Debug:** Telnet passive console (logs activity, no commands)

### C4-16AMP3-B (8-Zone Matrix) - 192.168.20.42

- **Specs:** 120W @ 8Ω, 220W @ 4Ω per channel
- **Inputs:** 8 analog
- **Outputs:** 8 stereo speaker zones
- **Features:** Full matrix switching, parametric EQ, volume limiting
- **Debug:** Telnet passive console

## Audio Zones with Playlist Support

Rooms configured with playlist cycling variables:

| Room | Variable Name | Keypad Location |
|------|---------------|-----------------|
| Basement Office | officePreset | Kitchen Keypad |
| Theater | theaterPreset | TBD |
| Wine Cellar | winecellarPreset | TBD |
| Front Porch | frontporchPreset | TBD |
| Living Room | livingroomPreset | TBD |
| Bathroom | bathroomPreset | TBD |
| Spare Room | spareroomPreset | TBD |
| Bedroom | bedroomPreset | TBD |
| Patio | patioPreset | TBD |

### Playlists Available

| Playlist | Genre/Mood |
|----------|------------|
| Quiet Music 01 | Ambient/Soft |
| Classical 01 | Classical |
| Christmas 01/02/03 | Holiday |
| Quiet Jazz 01 | Jazz |
| Evening Music 01 | Evening |
| Buffett 01 | Jimmy Buffett |
| Miles and Friends 01 | Jazz (Miles Davis) |
| Spa Only 01 | Spa/Relaxation |
| Sailing 01 | Sailing theme |
| Dinner Music 01 | Dinner party |

### Playlist Button Programming Pattern

Single tap cycles through playlists with LED color feedback:
```
IF officePreset = 0 → Red LED → "Buffett 01" → increment
IF officePreset = 1 → Lime LED → "Dinner Music 01" → increment  
IF officePreset = 2 → Blue LED → "Evening Music 01" → increment
IF officePreset = 3 → Silver LED → "Quiet Music 01" → increment
```

Double tap: Room off + reset variable to 0 + LED off

## Completed Projects

Based on historical todo list:

- [x] Fireplace switch/fan control
- [x] Awning setup
- [x] Projector door setup
- [x] Attic lift programming
- [x] Wall button playlist control (pattern documented above)
- [x] Various faceplate installs

## Active/Pending Projects

### High Priority
- Fresh air switch integration
- Attic fan switch + control
- Garage attic fan switches
- Basement cabinet fan replacement
- Furnace room fan replacement
- Sump pump Meross plug integration
- Water valve batteries + installation
- Pond speakers reconnection

### Medium Priority
- Chowmain weather driver
- Fire TV control (current driver slow)
- Motion detection → video capture when unoccupied
- Door unlock → video capture when unoccupied
- Water valve flood notification
- High water sump email alert
- Power outage/restore email notifications
- TuneIn fix (not working)
- Attic temp display in Navigator

### Future/Research
- NVR control learning
- WattBox control + UPS integration
- Car detection for parking spot availability
- Snow melt timer display (experience buttons)
- Weather-triggered snow melt scheduling
- HDMI audio from projector for internet outage
- Motor controller for beds
- Door locks integration
- Occupancy change from phone location

## Hardware Notes

### Snow Melt System
- Timer display desired via experience buttons
- Potential driver: Enhanced Countdown Timer by Domosapiens (DriverCentral)
- Schedule consideration: Start at 4am?
- Future: Weather-based triggering

### NVR
- IP: 10.0.0.129:10129
- Learning to control via C4 pending

### WattBox Integration Goals
- Hook to UPS for data
- Email notifications
- Safe shutdown sequence for power conservation

## Integration Points

### Current
- NVR at 10.0.0.129
- Meross plugs (sump pump planned)
- Water valves with sensors

### Planned
- Home Assistant integration
- Weather driver (Chowmain)
- Enhanced timer drivers

## System Quirks & Notes

- Front door switch activation unclear - not in keypad programming
- Maggie's cable stopped working (historical)
- Fire TV control extremely slow
- TuneIn not working

## Dealer Information

- **Original Installer:** TBD
- **Current Dealer:** TBD
- **OS Version:** TBD
- **4Sight Status:** TBD
- **Composer HE License:** TBD

## Document Sources

Additional documentation may exist in Doug's documents folder - CC task queued to search.
