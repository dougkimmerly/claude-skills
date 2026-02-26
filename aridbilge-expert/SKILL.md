---
name: aridbilge-expert
description: Arid Bilge Systems Series 4 expertise for Doug's 8-zone vacuum dehumidification system and its ESP32/SensESP/SignalK integration. Use when working on the Arid Bilge monitoring project, wiring optocouplers to hour meter terminals, writing SensESP firmware for zone tracking, designing SignalK data paths for bilge analytics, or troubleshooting the PLC-based control system. Covers internal hardware (DirectLogic 05 PLC, D0-08TR relay expansion, NResearch solenoid valves), the hour meter tap strategy, optocoupler isolation, GPIO pin assignments, and the full SignalK data model for zone runtime analytics.
---

# Arid Bilge Expert

Expertise for Doug's Arid Bilge Series 4 8-zone vacuum dehumidification system aboard the boat, including the ESP32/SensESP integration project to push zone runtime data into SignalK.

## System Overview

The Arid Bilge Series 4 is a vacuum-based bilge dehumidification system. A single diaphragm vacuum pump draws moisture from 8 zones through solenoid-controlled intake valves. The PLC cycles through zones sequentially, dwelling on wet zones longer. When all zones are dry, the system idles for 3 hours before cycling again.

### Zone Map (Top to Bottom on Front Panel)

| Zone | Name         | Signal Wire Color | ESP32 GPIO | Opto Board 1 Ch |
|------|-------------|-------------------|------------|-----------------|
| 1    | Sail Locker | White             | GPIO 4     | IN1             |
| 2    | Front Cabin | Yellow            | GPIO 5     | IN2             |
| 3    | Galley      | Orange            | GPIO 13    | IN3             |
| 4    | Port Bilge  | Grey              | GPIO 14    | IN4             |
| 5    | GenSet      | Brown             | GPIO 16    | IN5             |
| 6    | Engine      | Green             | GPIO 17    | IN6             |
| 7    | Steerage    | Blue              | GPIO 18    | IN7             |
| 8    | Garage      | Purple            | GPIO 19    | IN8             |

### Status Signals (Optocoupler Board 2)

| Signal             | Source          | ESP32 GPIO | Opto Board 2 Ch |
|--------------------|-----------------|------------|-----------------|
| Low Vacuum LED     | Front panel LED | GPIO 21    | IN1             |
| High Vacuum LED    | Front panel LED | GPIO 22    | IN2             |
| System Flood Fault | Front panel LED | GPIO 23    | IN3             |

### SignalK Paths (Quick Reference)

```
vessels.self.bilge.arid.{zoneName}.state           # boolean - active now
vessels.self.bilge.arid.{zoneName}.runHours         # cumulative hours
vessels.self.bilge.arid.{zoneName}.currentCycleSec  # seconds this activation
vessels.self.bilge.arid.{zoneName}.lastActivation   # ISO timestamp
vessels.self.bilge.arid.{zoneName}.cyclesTotal      # activation count
vessels.self.bilge.arid.systemState                 # "cycling" / "idle" / "alarm"
vessels.self.bilge.arid.currentZone                 # 0-8, 0 = none active
vessels.self.bilge.arid.vacuum.low                  # boolean
vessels.self.bilge.arid.vacuum.high                 # boolean
vessels.self.bilge.arid.floodFault                  # boolean
```

Zone names in camelCase: `sailLocker`, `frontCabin`, `galley`, `portBilge`, `genSet`, `engine`, `steerage`, `garage`

## Integration Architecture

```
Arid PLC → D0-08TR relays → Hour Meter Relays (inside enclosure)
                                    │
                          colored signal wires
                                    │
                                    ▼
                        Hour Meter Terminals (on front panel)
                                    │
                    ┌───────────────┤
                    │               │
              (unchanged)     (piggyback tap)
                    │               │
                    ▼               ▼
              Hour Meters    8-ch PC817 Opto Board #1 → ESP32 GPIOs
                                                           │
              Status LEDs → 8-ch PC817 Opto Board #2 → ESP32 GPIOs
                                                           │
                                                       SensESP
                                                           │
                                                    SignalK Server
```

All signal taps are at the front panel (hour meter terminals + LED wires).
Only 12V power crosses the Velcro gap from main enclosure to front panel.

Power: 12V from Arid terminal block → Buck converter (12V→5V) → ESP32 USB/VIN

## Detailed References

- **[references/system-internals.md](references/system-internals.md)** - Complete hardware breakdown, PLC, valves, wiring colors, physical layout
- **[references/integration-plan.md](references/integration-plan.md)** - Full wiring plan, optocoupler connections, mounting, power supply, GPIO rationale
- **[references/signalk-data-model.md](references/signalk-data-model.md)** - SignalK path definitions, data types, analytics use cases, NVS persistence strategy

## Key Facts

| Item | Detail |
|------|--------|
| System | Arid Bilge Series 4, 8-port (Serial #20,438) |
| Label | "Version Ser. 4x8s Updated 11/20" |
| PLC | DirectLogic 05 (D0-05DR-D), Koyo, 12-24V DC, 20W |
| Relay Expansion | D0-08TR (8-point relay output module) |
| Solenoid Valves | NResearch, PN: 36xx, 12VDC (part 1262151) |
| Pump | Schwarzer-style diaphragm vacuum pump, 12VDC |
| Optocoupler Boards | 2x AOICRIE 8-channel PC817, 3.6-24V input, 3.6-30V output |
| ESP32 | TBD dev board (must have 11+ GPIO with internal pullup) |
| Buck Converter | MP1584 or LM2596, 12V→5V, for ESP32 power |
| Front Panel | Velcro-attached, removable — hour meters, reset, LEDs on exterior |
| Tap Points | Hour meter terminals + LED wires on front panel interior |
| Mounting | ESP32 + opto boards on inside of front panel |

## Key Documentation

| Resource | URL |
|----------|-----|
| Arid Bilge Systems | https://aridbilgesystems.com/ |
| Series 4 Product Page | https://aridbilgesystems.com/product/arid-bilge-systems-series-4/ |
| Series 4 Manual (2022) | https://aridbilgesystems.com/wp-content/uploads/2023/05/Series4manualupdate2022.pdf |
| DirectLogic 05 PLC | https://www.automationdirect.com/adc/shopping/catalog/programmable_controllers/directlogic_series_plcs_(micro_to_small,_brick_-a-_modular)/directlogic_05_(micro_brick) |
| D0-08TR Module | https://www.automationdirect.com/adc/shopping/catalog/programmable_controllers/directlogic_series_plcs/directlogic_05/discrete_expansion_i-z-o/d0-08tr |
| USCG Compliance | 33 CFR 183416 Ignition Protected |
