# Doug's Control4 System

> **Project Name:** 55Tenth
> **System Age:** 19 years (2006-2025)
> **Last Updated:** 2025-12-29 (extracted from project file)
> **Project Backups:** 27 snapshots preserved

## System Overview

| Property | Value |
|----------|-------|
| **Primary Controller** | Control4 EA-5 |
| **Secondary Controller** | Control4 EA-1 |
| **Software Version** | 3.4.3 (Build 727848) |
| **Project Version** | 101 |
| **Location** | Toronto, Ontario, Canada |
| **Coordinates** | 43.65°N, 79.38°W |
| **Time Zone** | America/Toronto |
| **Scale** | Celsius |
| **Voltage** | 120V nominal |

## Network Inventory

From homelab network scan (192.168.20.0/24):

| IP | Device | Model | Firmware | Notes |
|----|--------|-------|----------|-------|
| .41 | 8-Channel Amp | C4-8AMP1-B | 03.24.45 | 4-zone matrix, telnet debug |
| .42 | 16-Channel Amp | C4-16AMP3-B | 03.26.52 | 8-zone matrix, telnet debug |
| .43 | Main Controller | EA-5 | 3.4.3 | Primary brain |
| .44 | WattBox | TBD | — | Power management |
| .45 | Control4 Device | EA-1? | — | Secondary controller |
| .181 | Control4 Device | TBD | — | TBD |
| .190 | I/O Extender | IOX/Z2IO | — | SSH (Dropbear), SMB |

## Room-by-Room Inventory

### Master Bedroom
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Window Keypad | 6-button | Shade/light control |
| Bedroom Light | Dimmer | Main lighting |
| Bed Light | Dimmer | Reading light |
| Mirror Light | Dimmer | Vanity |
| Closet Light | Dimmer | Walk-in closet |
| Doug's Light | Dimmer | Individual control |
| Maggie's Light | Dimmer | Individual control |
| Sony XBR-65X900A | 65" TV | Main display |
| Fire TV | Master C4 Fire TV | Streaming |
| Sony DVP-NS55P | DVD Player | Physical media |
| Shades | Hunter Douglas | Multiple positions |

### Living Room
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Sony TV | Television | Main display |
| Fire TV | Streaming | Voice control |
| Shades | Hunter Douglas | Close/Half/Open/Sheer/TV Position |
| Multiple Dimmers | Lighting | Various zones |

### Kitchen
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Keypad | Control | Main control |
| Side Door Keypad | 6-button | Entry control |
| Counter Lights | Dimmer | Task lighting |
| Kitchen Lights | Dimmer | Main lighting |
| Pots Lights (2 zones) | Dimmer | Accent lighting |

### Dining Room
| Device | Type | Notes |
|--------|------|-------|
| Keypad | Control | Main control |
| Window Keypad | 6-button | Shade control |
| Table Lighting | Dimmer | Chandelier/pendant |
| Shades | Hunter Douglas | Close/Half/Open/Sheer |

### Spare Room
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Door Keypad | Control | Entry |
| Window Keypad | 6-button | Shade control |
| Fire TV | ADB OS 2 | Streaming |
| Shades | Hunter Douglas | Close/Half/Open/Sheer |

### Office (Basement)
| Device | Type | Notes |
|--------|------|-------|
| 6-Button Keypad | Control | Main control |
| Keypad Dimmer | Dimmer | Lighting |
| Motion Sensor | Nyce 3041 | Occupancy |
| Switch | On/Off | Auxiliary |
| Shades | Hunter Douglas | Window treatment |

### Basement (General)
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Back Door Sensor | Nyce 3011 | Security |
| Front/Back Primary | Zones | Area control |
| Kitchen Area | Zone | Wet bar/kitchenette |
| Temperature Monitor | Sensor | Climate monitoring |
| Shades | Hunter Douglas | Window treatment |

### Bathroom
| Device | Type | Notes |
|--------|------|-------|
| Keypad | Control | Main control |
| Fan Control | Switch | Ventilation |
| Lighting | Dimmer | Ambient |
| Floor Switch | Switch | Heated floor? |

### Garage/Driveway
| Device | Type | Notes |
|--------|------|-------|
| Thermostat | Residential V2 | Climate zone |
| Keypad | Control | Main control |
| Garage Door | Sensor + Control | Open/close status |
| Entry Door Lock | Yale Zigbee | Smart lock |
| Exterior Lighting | Switch/Dimmer | Security |
| Upstairs Garage | Zone | Storage/bonus room |

### Theatre
| Device | Type | Notes |
|--------|------|-------|
| Keypad | Control | Scene control |
| Projector | Panasonic PT-AX100E | Main display |
| Receiver | Integra DTR-5.6 | Audio processing |
| AV Switch | Sony CAV-CVS12 | Input switching |

### Hallway
| Device | Type | Notes |
|--------|------|-------|
| Keypad | Control | Lighting/scenes |

### Front Door
| Device | Type | Notes |
|--------|------|-------|
| Keypad | Control | Entry scenes |

## Device Totals

| Category | Count |
|----------|-------|
| Dimmers | ~33 |
| Switches | ~11 |
| Keypads | 15+ |
| Thermostats | 6 |
| Shades (rooms) | 6 |
| Fire TV devices | 4+ |
| Motion Sensors | 1+ |
| Door/Window Sensors | 2+ |
| Smart Locks | 1 |

## Hunter Douglas PowerView Integration

**Hardware:**
- PowerView Gen3 Gateway
- PowerView Hub CIN
- PowerView Gen3 Shade drivers (v2)

**Rooms with Shades:**
- Master Bedroom
- Living Room
- Dining Room
- Spare Room
- Office (Basement)
- Basement

**Preset Positions:**
- Close
- Half
- Half-closed
- Half-shear
- Open
- Sheer
- TV Position (Living Room)

## Scheduled Automations (32 Events)

### Lighting - Sunset/Sunrise Relative
| Event | Time | Randomize | Notes |
|-------|------|-----------|-------|
| Back Lights | Sunset -15min | ±15min | Exterior |
| Front Light On | Sunset -15min | ±15min | Entry |
| Front Light Morning | Sunrise -75min | ±15min | Early morning |
| Front Light Off | 11:06 PM | ±22min | Night off |
| Outside Accent Lights On | Sunset | — | Landscape |
| Outside Accent Lights Off | Sunrise -15min | ±15min | Dawn off |
| Dawn | Sunrise +30min | — | Morning routine |

### Lighting - Fixed Time
| Event | Time | Notes |
|-------|------|-------|
| Lights Out | 11:15 PM (±53min) | All off |
| Bedtime LEDs | 9:15 PM | Keypad indicators |
| Morning LEDs | 6:45 AM | Keypad indicators |
| Garage Door Left ON LED | 9:16 PM | Alert indicator |

### Pond Pump Schedule
| Event | Time | Notes |
|-------|------|-------|
| Pond On | 5:30 AM | Morning cycle |
| Pond Off | 6:38 PM | Evening off |
| Pond ON Morning | 7:03 AM | Secondary |
| Pond OFF Morning | 8:30 AM | Secondary off |
| Noon Pond On | 12:30 PM | Midday cycle |
| Noon Pond Off | 1:46 PM | Midday off |

### Seasonal
| Event | Time | Notes |
|-------|------|-------|
| Christmas Lights On | Sunset | Holiday season |
| Christmas Lights Off | 12:04 AM | Night off |

### Away Mode (Vacation Simulation)
| Event | Time | Randomize | Days |
|-------|------|-----------|------|
| Away Basement Sunset | Sunset +90min | ±38min | Weekdays |
| Away Kitchen/Bed Sunset | Sunset +90min | ±48min | All |
| Away Spare Living | Sunset | ±45min | Selective |
| Away Random 04 | Sunrise -60min | ±59min | All |

### Daily Routines
| Event | Time | Randomize | Notes |
|-------|------|-----------|-------|
| Wake Up | 6:00 AM | — | Morning scene |
| Off to Work | 8:00 AM | ±30min | Departure |

### Maintenance/Reminders
| Event | Time | Frequency | Notes |
|-------|------|-----------|-------|
| Garbage Day | 4:31 PM | Weekly (Tue) | Reminder |
| Grey Box Next | — | Bi-weekly | Recycling |
| Blue Box Next | — | Bi-weekly | Recycling |
| Thaw Aircon | 1:15 AM | Seasonal | HVAC |
| Apple TV Video Update | 3:00 AM | Sundays | Maintenance |
| Component Auto Update | 2:34 AM | M-Sat | System |
| Component Forced Update | 3:07 AM | Tuesday | System |

## Audio System

### Amplifiers
| Model | Zones | IP | Specs |
|-------|-------|-----|-------|
| C4-8AMP1-B | 4 stereo | .41 | 60W@8Ω, 120W@4Ω |
| C4-16AMP3-B | 8 stereo | .42 | 120W@8Ω, 220W@4Ω |

### Playlist Variables (Button Cycling)
| Room | Variable | Keypad |
|------|----------|--------|
| Basement Office | officePreset | Kitchen Keypad |
| Theater | theaterPreset | Theater Keypad |
| Wine Cellar | winecellarPreset | TBD |
| Front Porch | frontporchPreset | TBD |
| Living Room | livingroomPreset | TBD |
| Bathroom | bathroomPreset | TBD |
| Spare Room | spareroomPreset | TBD |
| Bedroom | bedroomPreset | TBD |
| Patio | patioPreset | TBD |

### Playlists Available
| Playlist | Genre |
|----------|-------|
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

### Music Services
- MyMusic (local library)
- MyMovies (local library)
- TuneIn Radio
- Stations/Channels
- Amazon Music (via Fire TV)

## Integrations

### Active Integrations
| Integration | Driver/Method | Status |
|-------------|---------------|--------|
| Hunter Douglas PowerView | Gen3 Gateway | ✅ Active |
| Chowmain Home Assistant | Gateway + Binary Sensor | ✅ Active |
| OpenWeather | Chowmain Agent | ✅ Active |
| WattBox | Power Management | ✅ Active |
| Amazon Voice | Voice Scene + Fire TV | ✅ Active |
| Apple TV | iTunes 2-Way (ExtraVeg) | ✅ Active |
| Yale Lock | Zigbee | ✅ Active |
| Sinope Water | Valves + Sensors (Zigbee) | ✅ Active |

### Drivers Installed
- Control4 Color Agent
- Control4 Daylight Agent
- Control4 Voice Coordinator Agent
- Data Analytics Agent
- DriverCentral Cloud
- Matterlink Multi-X Master
- Generic TCP Command
- Black Wire AVSwitch IR

## Security & Sensors

### Access Control
| Device | Type | Location |
|--------|------|----------|
| Yale Smart Lock | Zigbee | Garage Entry Door |

### Door/Window Sensors
| Device | Model | Location |
|--------|-------|----------|
| Back Door Sensor | Nyce 3011 | Basement |
| Garage Door Sensor | Contact | Garage |

### Motion Sensors
| Device | Model | Location |
|--------|-------|----------|
| Motion Sensor | Nyce 3041 | Basement Office |

### Water Management
| Device | Type | Notes |
|--------|------|-------|
| Water Sensors | Sinope Zigbee | Flood detection |
| Water Valves | Sinope Zigbee | Shutoff control |

## Controllers & Infrastructure

| Device | Role | Notes |
|--------|------|-------|
| EA-5 | Primary Controller | Main brain |
| EA-1 | Secondary Controller | Expansion |
| IOX | I/O Extender | Contact/relay expansion |
| Z2IO | Zigbee/Z-Wave Interface | Protocol bridge |
| Remote Hub | SR-250 Support | Remote control |
| AV Path Setter | EA-5 | Audio/video routing |

## Pending Projects

### High Priority
- Fresh air switch integration
- Attic fan switch + control
- Garage attic fan switches
- Sump pump Meross plug
- Water valve batteries
- Pond speakers reconnection

### Medium Priority
- Fire TV driver (slow performance)
- Motion → video capture when unoccupied
- Door unlock → video capture
- TuneIn fix (not working)
- Attic temp in Navigator
- Power outage email notifications

### Future/Research
- NVR control (10.0.0.129:10129)
- WattBox UPS integration
- Snow melt timer display
- Weather-triggered snow melt
- Motor controller for beds
- Additional door locks
- Occupancy from phone location

## System Quirks

- Front door switch activation unclear (not in keypad programming)
- Fire TV control extremely slow
- TuneIn not working
- Maggie's cable issue (historical)

## Project History

**27 Project Backups (2006-2025):**
- Most recent: `55Tenth20251011.c4p` (Oct 11, 2025) - 384 MB
- Contains: project.xml (3.3 MB), drivers (100+), media DB (18 MB)

**Evolution:**
- Original installation: ~2006
- Upgraded to EA-5/EA-1 architecture
- Added Hunter Douglas PowerView (~2020s)
- Added Chowmain Home Assistant integration
- Added Matterlink for Matter/Thread devices
