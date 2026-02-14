# Arid Bilge ESP32 Integration Plan

Complete wiring and mounting plan for adding ESP32/SensESP monitoring to the Arid Bilge Series 4 system.

## Design Principles

1. **Non-invasive** — Piggyback taps only, no cutting or disconnecting existing Arid wiring
2. **Galvanic isolation** — Optocouplers keep ESP32 electrically separated from Arid 12V system
3. **Fail-safe** — If ESP32 fails or is removed, Arid system continues operating normally
4. **Inside the enclosure** — All new components mount inside the Arid enclosure on the front panel

## Components

### Required

| Component | Quantity | Purpose | Status |
|-----------|----------|---------|--------|
| 8-ch PC817 optocoupler module (AOICRIE) | 2 | Signal isolation (zones + status) | ✅ Ordered |
| ESP32 dev board (WROOM-32 or similar) | 1 | SensESP controller | ⬜ Needed |
| Buck converter (MP1584 or LM2596) | 1 | 12V→5V for ESP32 power | ⬜ Needed |
| Wire (22-24 AWG, stranded) | ~3m | Signal connections | ⬜ Needed |
| Red insulated crimp taps or solder splices | 8 | Piggyback onto hour meter wires | ⬜ Needed |
| Small standoffs or double-sided foam tape | 4-6 | Mounting boards to front panel | ⬜ Needed |
| Heat shrink tubing | Assorted | Insulating connections | ⬜ Needed |

### Nice to Have

| Component | Purpose |
|-----------|---------|
| Small prototype board / perfboard | Clean junction for wire management |
| JST or Dupont connectors | Disconnectable wiring harness |
| Ferrite bead on ESP32 power | Noise suppression |

## Wiring Plan

### Zone Signals (Optocoupler Board 1)

Each zone's colored wire on the front panel relays goes to 12V when that zone is active. We piggyback onto these wires and feed them to the optocoupler inputs.

```
Hour Meter Relay Contacts (inside front panel)
    │
    ├── Existing colored wire → Hour Meter Display (unchanged)
    │
    └── NEW piggyback wire → Optocoupler Board 1 Input
                                    │
                              PC817 LED side (anode)
                                    │
                              PC817 LED cathode → Arid GND (orange common wire)

Optocoupler Board 1 Output Side:
    ESP32 3.3V → Board VCC
    ESP32 GND  → Board GND
    Board OUT1-OUT8 → ESP32 GPIO pins (see table below)
```

**Optocoupler input wiring (12V Arid side):**

| Opto Input | Zone | Tap Wire Color | Arid Signal |
|------------|------|---------------|-------------|
| IN1 | Sail Locker | White | 12V when zone 1 active |
| IN2 | Front Cabin | Yellow | 12V when zone 2 active |
| IN3 | Galley | Orange | 12V when zone 3 active |
| IN4 | Port Bilge | Grey | 12V when zone 4 active |
| IN5 | GenSet | Brown | 12V when zone 5 active |
| IN6 | Engine | Green | 12V when zone 6 active |
| IN7 | Steerage | Blue | 12V when zone 7 active |
| IN8 | Garage | Purple | 12V when zone 8 active |
| GND (common) | — | Orange common wire | Arid 12V ground reference |

**Optocoupler output wiring (3.3V ESP32 side):**

| Opto Output | ESP32 GPIO | Pin Mode |
|-------------|-----------|----------|
| OUT1 | GPIO 4 | INPUT_PULLUP |
| OUT2 | GPIO 5 | INPUT_PULLUP |
| OUT3 | GPIO 13 | INPUT_PULLUP |
| OUT4 | GPIO 14 | INPUT_PULLUP |
| OUT5 | GPIO 16 | INPUT_PULLUP |
| OUT6 | GPIO 17 | INPUT_PULLUP |
| OUT7 | GPIO 18 | INPUT_PULLUP |
| OUT8 | GPIO 19 | INPUT_PULLUP |

### Status Signals (Optocoupler Board 2)

The three front panel LEDs (Low Vacuum, High Vacuum, System Flood Fault) are driven by PLC outputs. We tap the LED drive signals.

| Opto Input | Signal | Source |
|------------|--------|--------|
| IN1 | Low Vacuum | LED drive wire |
| IN2 | High Vacuum | LED drive wire |
| IN3 | System Flood Fault | LED drive wire |
| IN4-IN8 | Spare | Available for future use |

| Opto Output | ESP32 GPIO | Pin Mode |
|-------------|-----------|----------|
| OUT1 | GPIO 21 | INPUT_PULLUP |
| OUT2 | GPIO 22 | INPUT_PULLUP |
| OUT3 | GPIO 23 | INPUT_PULLUP |

### ESP32 Power Supply

```
Arid 12V DC (gray terminal block, fused)
    │
    └── NEW wire to buck converter input (+12V and GND)
            │
        Buck Converter (MP1584/LM2596)
        Input: 12V DC
        Output: 5V DC
            │
        ESP32 5V/VIN pin (or USB connector)
```

**Important:** Use a SEPARATE 12V feed from the same circuit, not tapped from inside the Arid power rail. This keeps fault domains isolated — if the buck converter shorts, it blows its own fuse, not the Arid system fuse.

## GPIO Pin Selection Rationale

These pins were chosen because they all:
- Support INPUT_PULLUP (have internal pull-up resistors)
- Are safe during boot (won't affect ESP32 boot mode)
- Don't conflict with SPI flash (GPIO 6-11 avoided)
- Don't conflict with serial (GPIO 1, 3 avoided)
- Don't conflict with WiFi (ADC2 channels not needed since we're using digital inputs)

**Pins explicitly avoided:**
- GPIO 0 — Boot mode select (pulled LOW enters bootloader)
- GPIO 2 — Boot mode, also connected to onboard LED on many dev boards
- GPIO 6-11 — Connected to SPI flash
- GPIO 12 — MTDI, affects flash voltage on some boards
- GPIO 1, 3 — Serial TX/RX
- GPIO 34, 35, 36, 39 — Input only, NO internal pullup resistor

**Pins reserved for future use:**
- GPIO 25, 26, 27, 32, 33 — Available if additional sensors needed
- GPIO 15 — Available but can cause boot log output on serial

## Optocoupler Signal Logic

The PC817 optocoupler module has **active-low** output logic:

| Arid Zone State | Opto LED (input side) | Opto Transistor (output) | ESP32 GPIO Reading |
|----------------|----------------------|--------------------------|-------------------|
| **ACTIVE** (12V on wire) | LED ON | Transistor saturates → pulls output LOW | **LOW** (0) |
| **INACTIVE** (0V) | LED OFF | Transistor off → pulled HIGH by pullup | **HIGH** (1) |

In SensESP code, the `DigitalInputState` reading must be **inverted**:
- GPIO reads LOW → zone is ACTIVE
- GPIO reads HIGH → zone is INACTIVE

## Physical Mounting Plan

All new components mount on the **inside of the front panel**, alongside the existing hour meter relays.

```
┌──────────────────────────────────────────────┐
│ FRONT PANEL (inside view)                     │
│                                               │
│  ┌─────┐  ┌─────┐                            │
│  │Reset│  │Opto │ Optocoupler Board 2         │
│  │ SW  │  │ #2  │ (3 status signals)          │
│  └─────┘  └─────┘                            │
│                                               │
│  ┌─────────┐  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │
│  │  ESP32   │  │R1 │ │R2 │ │R3 │ │R4 │       │
│  │ Dev Board│  └───┘ └───┘ └───┘ └───┘       │
│  └─────────┘                                  │
│                                               │
│  ┌─────────┐  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │
│  │  Opto   │  │R5 │ │R6 │ │R7 │ │R8 │       │
│  │ Board 1 │  └───┘ └───┘ └───┘ └───┘       │
│  └─────────┘                                  │
│                                               │
│  ┌─────────┐                                  │
│  │  Buck   │                                  │
│  │Converter│                                  │
│  └─────────┘                                  │
│                                               │
│  ═══════════ Velcro strip ══════════════      │
└──────────────────────────────────────────────┘
```

The front panel detaches via Velcro. The only wire crossing the Velcro gap:
- 12V power feed (2 wires: +12V and GND) from main enclosure terminal block to buck converter
- Status LED signal wires (3 wires) if status LEDs are driven from the PLC side

Use a small connector (Molex or JST) at the Velcro gap so the panel can be fully detached for service.

## Commissioning Steps

### Phase 1: Verify Signals

1. With Arid system running, use a multimeter on each colored wire at the relay contacts
2. Confirm 12V appears when that zone is active, 0V when inactive
3. Identify the polarity (which wire is +12V, which is GND reference)
4. Document the actual voltage (may be 11-14V depending on battery state)

### Phase 2: Bench Test Optocoupler

1. Connect one optocoupler channel to a bench 12V supply
2. Connect output to ESP32 with INPUT_PULLUP
3. Verify: 12V in → GPIO reads LOW, 0V in → GPIO reads HIGH
4. Confirm the PC817 module's onboard LED lights when 12V applied

### Phase 3: Install Hardware

1. Mount buck converter, ESP32, and opto boards on front panel
2. Wire buck converter to 12V source (via connector at Velcro gap)
3. Wire 8 zone piggyback taps to Opto Board 1 inputs
4. Wire Opto Board 1 outputs to ESP32 GPIOs
5. Wire 3 status signals to Opto Board 2 inputs
6. Wire Opto Board 2 outputs to ESP32 GPIOs
7. Wire ESP32 3.3V and GND to both opto board output sides

### Phase 4: Software

1. Flash ESP32 with SensESP firmware
2. Configure WiFi and SignalK server connection
3. Verify zone signals appear in SignalK
4. Run through a full cycle and confirm all 8 zones report correctly
5. Verify cumulative hours tracking matches hour meter displays
6. Set up Grafana dashboards for trend analysis

## Verification Checklist

Before closing up the enclosure:

- [ ] All 8 zone signals read correctly (active = LOW on GPIO)
- [ ] 3 status signals read correctly
- [ ] ESP32 connects to WiFi reliably
- [ ] SignalK receives all data paths
- [ ] NVS persistence works (reboot ESP32, check hours survive)
- [ ] Arid system operates normally with ESP32 connected
- [ ] Hour meters still function (piggyback tap not loading the circuit)
- [ ] Front panel can be removed and reattached without snagging wires
- [ ] Connector at Velcro gap disconnects cleanly
- [ ] No wire pinching when panel is pressed onto Velcro
