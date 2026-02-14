# Arid Bilge SignalK Data Model

Complete data model for zone runtime tracking, system status, and analytics.

## SignalK Path Definitions

### Per-Zone Paths

Each of the 8 zones publishes the following paths. Zone names use camelCase.

| Path | Type | Unit | Description |
|------|------|------|-------------|
| `vessels.self.bilge.arid.{zone}.state` | boolean | — | `true` when zone is currently being serviced |
| `vessels.self.bilge.arid.{zone}.runHours` | float | hours | Cumulative runtime since last reset |
| `vessels.self.bilge.arid.{zone}.currentCycleSec` | integer | seconds | Duration of current/last activation |
| `vessels.self.bilge.arid.{zone}.lastActivation` | string | ISO 8601 | Timestamp of most recent activation start |
| `vessels.self.bilge.arid.{zone}.cyclesTotal` | integer | — | Total number of activations since last reset |

Zone name mapping:

| Zone # | camelCase Name | Full Name |
|--------|---------------|-----------|
| 1 | sailLocker | Sail Locker |
| 2 | frontCabin | Front Cabin |
| 3 | galley | Galley |
| 4 | portBilge | Port Bilge |
| 5 | genSet | GenSet |
| 6 | engine | Engine |
| 7 | steerage | Steerage |
| 8 | garage | Garage |

### System-Level Paths

| Path | Type | Values | Description |
|------|------|--------|-------------|
| `vessels.self.bilge.arid.systemState` | string | `cycling`, `idle`, `alarm` | Inferred from zone activity patterns |
| `vessels.self.bilge.arid.currentZone` | integer | 0-8 | Currently active zone number, 0 = none |
| `vessels.self.bilge.arid.vacuum.low` | boolean | — | Low Vacuum LED state |
| `vessels.self.bilge.arid.vacuum.high` | boolean | — | High Vacuum LED state |
| `vessels.self.bilge.arid.floodFault` | boolean | — | System Flood Fault LED state |

### Example SignalK Delta

```json
{
  "updates": [{
    "source": { "label": "arid-bilge-monitor", "type": "SensESP" },
    "timestamp": "2025-02-14T18:30:00Z",
    "values": [
      { "path": "bilge.arid.engine.state", "value": true },
      { "path": "bilge.arid.engine.runHours", "value": 47.3 },
      { "path": "bilge.arid.engine.currentCycleSec", "value": 142 },
      { "path": "bilge.arid.engine.lastActivation", "value": "2025-02-14T18:27:38Z" },
      { "path": "bilge.arid.engine.cyclesTotal", "value": 1247 },
      { "path": "bilge.arid.currentZone", "value": 6 },
      { "path": "bilge.arid.systemState", "value": "cycling" }
    ]
  }]
}
```

## Data Persistence (NVS)

Cumulative data must survive ESP32 reboots. Use ESP32 **NVS (Non-Volatile Storage)** — not SPIFFS or LittleFS. NVS is designed for frequent small key-value writes and handles wear leveling internally.

### NVS Keys

| NVS Key | Type | Description |
|---------|------|-------------|
| `z1_hours` through `z8_hours` | float | Cumulative runtime hours per zone |
| `z1_cycles` through `z8_cycles` | uint32 | Total cycle count per zone |
| `z1_last` through `z8_last` | string | ISO timestamp of last activation |

### Write Strategy

- **On zone deactivation:** Write updated hours and cycle count for that zone
- **Periodic backup:** Every 5 minutes while a zone is active, write current hours (protects against power loss mid-cycle)
- **Never on every loop():** NVS write frequency should be bounded to avoid unnecessary wear

SensESP's built-in `Configurable` system uses JSON files on SPIFFS/LittleFS for config. Our cumulative counters use NVS separately because:
1. NVS is purpose-built for frequent small writes
2. SPIFFS/LittleFS can corrupt on unexpected power loss during writes
3. NVS has built-in wear leveling at the page level

## SensESP Architecture

### Custom Transform: ZoneAnalyzer

A custom SensESP transform class that takes a boolean `DigitalInputState` and produces multiple SignalK outputs.

```
DigitalInputState (GPIO pin, inverted)
    │
    ▼
ZoneAnalyzer (custom transform)
    │
    ├──► SKOutputBool    → bilge.arid.{zone}.state
    ├──► SKOutputFloat   → bilge.arid.{zone}.runHours
    ├──► SKOutputInt     → bilge.arid.{zone}.currentCycleSec
    ├──► SKOutputString  → bilge.arid.{zone}.lastActivation
    └──► SKOutputInt     → bilge.arid.{zone}.cyclesTotal
```

### System State Inference

The `systemState` path is inferred by a separate transform that monitors all 8 zone states:

| Condition | Inferred State |
|-----------|---------------|
| Any zone active | `cycling` |
| No zone active for < 3.5 hours | `idle` (normal inter-cycle rest) |
| No zone active for > 4 hours | `idle` (possible issue or powered off) |
| Flood fault LED active | `alarm` |

### Update Intervals

| Data | Interval | Rationale |
|------|----------|-----------|
| Zone state (boolean) | 500ms | Fast enough to catch short activations |
| Run hours | 10s | Updated in memory continuously, published every 10s |
| Current cycle seconds | 1s | Useful for live monitoring |
| Cycle count | On change | Only increments on zone deactivation |
| System state | 1s | Derived from zone states |
| Status LEDs | 500ms | Alarm conditions should be caught quickly |

## Analytics Use Cases

### Water Intrusion Detection

By comparing zone cycle durations over time:

- **Wet zone:** Longer-than-average activation (pump dwelling to extract moisture)
- **Dry zone:** Short activation (pump quickly achieves target vacuum and moves on)
- **Trend analysis:** A zone that was always dry but starts showing longer cycles indicates a new leak

### Correlation with Other Systems

Cross-reference zone activation patterns in Grafana with:

| System | Correlation |
|--------|-------------|
| Watermaker | Does the engine room zone get wet after watermaker runs? (Brine discharge leak?) |
| Rain events | Weather data vs. sail locker zone activity |
| Sea state | Wave height vs. hull zones (port bilge, steerage) |
| AC system | Galley/cabin zones vs. AC condensation |
| Engine operation | Engine zone vs. engine run time (shaft packing drip rate) |
| Shore power | Condensation patterns when boat is on shore vs. hook vs. anchor |

### Example Grafana Queries

```sql
-- Zone activation durations over time (InfluxDB)
SELECT mean("currentCycleSec") FROM "bilge.arid.engine"
WHERE time > now() - 30d
GROUP BY time(1d)

-- Compare all zones side by side
SELECT last("runHours") FROM /bilge\.arid\..+\.runHours/
WHERE time > now() - 7d
GROUP BY time(1h)

-- Detect anomalous zone (cycle time > 2x rolling average)
SELECT "currentCycleSec" FROM "bilge.arid.portBilge"
WHERE "currentCycleSec" > (SELECT mean("currentCycleSec") * 2 FROM "bilge.arid.portBilge" WHERE time > now() - 7d)
```

### Alerting Thresholds (suggested)

| Alert | Condition | Severity |
|-------|-----------|----------|
| Zone running long | Single zone > 30 min continuous | Warning |
| Flood fault | `floodFault` = true | Critical |
| Low vacuum | `vacuum.low` = true for > 5 min | Warning |
| Zone trend change | 7-day rolling avg cycle time increases > 50% | Info |
| System offline | No data from ESP32 for > 10 min | Warning |
