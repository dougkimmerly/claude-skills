# Arid Bilge Series 4 — System Internals

Complete hardware breakdown of Doug's Arid Bilge Series 4 8-zone system based on physical inspection and photos (February 2025).

## How It Works

The Arid Bilge is a vacuum-based dehumidification system. It does NOT pump water — it uses vacuum suction to draw moisture and humidity out of bilge compartments through small-diameter tubing.

### Operating Cycle

1. PLC energizes zone 1 solenoid valve (opens intake)
2. Vacuum pump runs, drawing air/moisture from zone 1 through tubing
3. Moisture collects in the central collection chamber (white PVC cylinder)
4. PLC monitors vacuum pressure switches to determine if zone is wet or dry
5. Wet zones: pump dwells longer (more moisture to extract)
6. Dry zones: pump moves on quickly
7. PLC advances to zone 2, then 3, etc. through all 8 zones
8. After cycling all zones, if all are dry: system idles for 3 hours
9. After idle period: cycle repeats

### Key Behavior for Monitoring

- Only ONE zone is active at a time (sequential cycling)
- Wet zones have noticeably longer activation times than dry zones
- The idle period between full cycles is approximately 3 hours when all zones are dry
- A "flood fault" condition triggers when vacuum cannot be achieved (water blocking the line)

## Internal Components

### PLC: DirectLogic 05 (D0-05DR-D)

The brain of the system. Made by Koyo/AutomationDirect.

| Spec | Value |
|------|-------|
| Model | D0-05DR-D |
| Power | 12-24V DC, 20W |
| Inputs | X0-X7 (8 discrete, 12-24V, 3-15mA) |
| Outputs | Y0-Y5 (6 relay outputs on base unit) |
| Serial Ports | 2 (RS-232, support Modbus RTU) |
| Label | "Version Ser. 4x8s Updated 11/20" |

The PLC inputs (X0-X7) receive signals from vacuum pressure switches that detect wet/dry status per zone. The PLC outputs (Y0-Y5) on the base unit control sequencing logic, the pump relay, the buzzer, and possibly the status LEDs.

**Note:** The PLC supports Modbus RTU over RS-232 but we do NOT know the ladder program, so we are not pursuing a Modbus integration. The optocoupler tap is simpler and requires no knowledge of the PLC internals.

### Relay Expansion: D0-08TR

Adds 8 relay outputs to the PLC for zone valve control.

| Spec | Value |
|------|-------|
| Model | D0-08TR |
| Outputs | 8 relay (normally open) |
| Rating | 1A @ 24VDC per point |
| Connection | Plugs directly into PLC expansion port |

Each relay output drives one solenoid valve. When the PLC activates zone N, it closes relay N on the D0-08TR, which sends 12V to that zone's solenoid valve.

### Solenoid Valves (8x)

NResearch 12VDC solenoid valves mounted on an aluminum bracket.

| Spec | Value |
|------|-------|
| Manufacturer | NResearch |
| Part Number | PN: 36xx (exact varies) |
| Reference | 1262151 |
| Voltage | 12VDC |
| Address | 267 Fairfield Ave, W. Caldwell |
| Connection | Yellow wire pairs from D0-08TR relays |

Each valve controls vacuum intake from one zone. When energized (12V applied via yellow wire), the valve opens and the pump draws air from that zone's tubing.

### Vacuum Pump

Central diaphragm vacuum pump (Schwarzer-style).

| Spec | Value |
|------|-------|
| Type | Diaphragm vacuum pump |
| Power | 12VDC |
| Location | Bottom of enclosure, mounted on base plate |

Single pump serves all 8 zones — only one valve is open at a time.

### Vacuum Pressure Switches (2x visible)

Black switches with COM / N.C. / N.O. terminals mounted above the collection chamber.

| Spec | Value |
|------|-------|
| Terminals | COM, N.C., N.O. (clearly labeled on housing) |
| Connection | Red crimp connectors, wired to PLC inputs X0-X7 |
| Wire colors | Red and blue wires to PLC |

These provide feedback to the PLC on vacuum levels to determine if a zone has water (vacuum drops when water blocks the line).

### Collection Chamber

White PVC cylinder in the lower section of the enclosure. Collected moisture drains or is manually emptied.

### Buzzer

Black buzzer mounted inside enclosure. Sounds on alarm conditions (flood fault, system errors).

## Front Panel

The front panel attaches via **Velcro strips** (black material visible at edges in photos) and is easily removable for access to internals.

### External Panel Features (IMG_7248)

From top to bottom:
- **Series 4** header with "UP ↑" arrow
- **3 status LEDs** (right side): Low Vacuum, High Vacuum, System Flood Fault
- **8 hour meters** with zone labels (each shows HOURS with 1/10 resolution)
- **Reset Meters** button (resets all hour meters)
- **Black foam pad** (covers buzzer opening or unused display area)
- **Arid Bilge Systems branding**: "THE DRY BILGE MACHINE"
- **Compliance**: MEETS USCG 33 CFR 183416 IGNITION PROTECTED
- **Contact**: 954-328-9705, Deerfield Beach, Florida
- **Patent**: US Patent Number 6,837,174

### Internal Panel Components (IMG_7241-7247)

Eight micro relay sockets mounted in two columns on the inside of the front panel. These relays switch 12V to the hour meters when a zone is active.

Each relay has 3 screw terminals (numbered 1, 2, 3 on the molded housing). The wiring pattern:

**Common wires across all 8 relays:**
- **Green wire** (left side) — Reset circuit from front panel reset button
- **Orange wire** (left side) — Power rail (12V+ or GND common)
- **Brown wire** (top right) — Other power rail conductor

**Individual zone signal wires (from relay contact outputs):**

| Relay Position | Zone | Wire Color |
|---------------|------|------------|
| 1 (top) | Sail Locker | White |
| 2 | Front Cabin | Yellow |
| 3 | Galley | Orange |
| 4 | Port Bilge | Grey |
| 5 | GenSet | Brown |
| 6 | Engine | Green |
| 7 | Steerage | Blue |
| 8 (bottom) | Garage | Purple |

These colored wires carry 12V when their zone is active and connect to the corresponding hour meter on the external face of the panel.

**Also on internal panel:**
- Microswitch (top left, near rectangular cutout) — likely the "Reset Meters" button mechanism
- Gray multi-conductor cable — runs from the main enclosure (PLC area) to the relay coils, carrying the drive signals from the D0-08TR expansion module
- White zip ties organizing the wiring bundles

## Internal Wiring Summary

### Signal Flow

```
PLC D0-08TR relay outputs
    │ (gray multi-conductor cable)
    ▼
Front Panel Hour Meter Relays (8x micro relays)
    │
    ├── Relay coils driven by PLC via gray cable
    │
    └── Relay contacts switch 12V to hour meters
         │
         ├── Orange wire (common power rail) ─── to one contact on each relay
         │
         └── Individual colored wire per relay ─── to individual hour meter
              (White, Yellow, Orange, Grey, Brown, Green, Blue, Purple)
```

### Power Distribution (inside main enclosure, IMG_7239)

- **Gray terminal blocks** with fused terminals (amber/clear fuse holders visible)
- **GMA-3-R fuse** protecting the 12V input
- Yellow wires from terminal blocks → solenoid valves
- Red and black wires → power distribution
- Pink wires → additional power/signal routing

### Wire Color Code (inside main enclosure)

| Color | Function |
|-------|----------|
| Yellow | Solenoid valve power (12V switched by D0-08TR) |
| Red | Power (+12V) |
| Black | Ground |
| Pink | Auxiliary power/signal |
| White | Sensor/signal (vacuum switches to PLC inputs) |
| Gray cable | Multi-conductor, PLC → front panel relay coils |

## Photo Index

| Photo | Content |
|-------|---------|
| IMG_7236 | Solenoid valves (top view), yellow wires, NResearch labels visible |
| IMG_7237 | Solenoid valves (side view), aluminum bracket, clear tubing connections |
| IMG_7238 | Vacuum pressure switches (COM/NC/NO), collection chamber top, "ARID BILGE SYSTEMS, Inc." label |
| IMG_7239 | Terminal blocks with fused connections, yellow wire distribution, power wiring |
| IMG_7240 | Vacuum pump (Schwarzer diaphragm), solenoid valve array, buck converter area |
| IMG_7241 | Front panel interior — full relay row (8 relays), colored wires, reset switch |
| IMG_7242 | PLC close-up — DirectLogic 05, inputs X0-X7, version label |
| IMG_7243 | Relay close-up (bottom relays) — terminal numbers, wire colors |
| IMG_7244 | Relay close-up (middle relays) — orange/green/brown/blue/purple wires |
| IMG_7245 | Full front panel interior — all 8 relays, gray cable, reset switch |
| IMG_7246 | Full front panel interior (alternate angle) — wiring routing |
| IMG_7247 | Top relays close-up — terminal numbering visible (2, 3 labels) |
| IMG_7248 | **External front panel** — zone names, hour meters, status LEDs, branding |
