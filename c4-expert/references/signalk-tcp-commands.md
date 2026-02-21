# SignalK TCP Commands - Control4 Integration

**Last Updated:** 2026-02-21
**Device:** Generic TCP Command Driver (ID: 1108)
**Target:** homesk.kbl55.com:50261 (192.168.20.19)
**HTTP Port:** 50260 on 192.168.20.181

## Connection Parameters

All commands use these standard parameters:

- **Action:** Send Generic TCP command
- **Encoding:** ASCII
- **IP Address:** signalk.kbl55.com (DNS resolves to 192.168.20.19)
- **Port:** 50261
- **Protocol:** TCP

## Communication Architecture

```
SignalK (.19) ───HTTP GET──→ C4 (.181:50260) /{commandName}
C4 (.181)     ───TCP JSON──→ SignalK (.19:50261)
```

**SignalK → C4 (HTTP):**
- SignalK sends commands TO C4 at 192.168.20.181:50260/{commandName}
- URL path is `/{commandName}` directly — no `/command/` prefix
- Used for: startSouth, stopSouth, startNorth, stopNorth, increaseHeat, etc.

**C4 → SignalK (TCP):**
- C4 sends status updates TO SignalK at homesk.kbl55.com:50261
- All commands documented below

## Snow Melt Per-Zone Commands (HTTP → C4)

Added 2026-02-21 to replace legacy startSnow/stopSnow.

| HTTP Command | C4 Event | Purpose |
|-------------|----------|---------|
| `startSouth` | Event 25 | Turn on driveway south relay |
| `startNorth` | Event 26 | Turn on driveway north relay |
| `startTent` | Event 27 | Turn on tent relay |
| `stopSouth` | Event 28 | Turn off driveway south relay |
| `stopNorth` | Event 29 | Turn off driveway north relay |
| `stopTent` | Event 30 | Turn off tent relay |

**Note:** The 25-minute stagger between south and north is handled in the plugin, not C4.

## Snow Melt Zone Control (6 commands)

### 1. Snow Start - Driveway North
```json
{"type": "snowStart", "loc":"drivewayNorth","data": PARAM{781,1133}}
```

### 2. Snow Stop - Driveway North
```json
{"type": "snowStop", "loc":"drivewayNorth","data": PARAM{781,1133}}
```

### 3. Snow Start - Driveway South
```json
{"type": "snowStart", "loc":"drivewaySouth","data": PARAM{781,1133}}
```

### 4. Snow Stop - Driveway South
```json
{"type": "snowStop", "loc":"drivewaySouth","data": PARAM{781,1133}}
```

### 5. Snow Start - Tent
```json
{"type": "snowStart", "loc":"tent","data": PARAM{781,1133}}
```

### 6. Snow Stop - Tent
```json
{"type": "snowStop", "loc":"tent","data": PARAM{781,1133}}
```

## Temperature Change Notifications (6 commands)

### 7. Temp Change - Basement
```json
{"type": "tempChange", "loc":"basement","data": PARAM{781,1133}}
```

### 8. Temp Change - Master
```json
{"type": "tempChange", "loc":"Master","data": PARAM{783,1133}}
```

### 9. Temp Change - Spare
```json
{"type": "tempChange", "loc":"Spare","data": PARAM{785,1133}}
```

### 10. Temp Change - Living
```json
{"type": "tempChange", "loc":"Living","data": PARAM{787,1133}}
```

### 11. Temp Change - Kitchen
```json
{"type": "tempChange", "loc":"Kitchen","data": PARAM{791,1133}}
```

### 12. Temp Change - Garage
```json
{"type": "tempChange", "loc":"Garage","data": PARAM{793,1133}}
```

## Full Temperature Status Response (7 commands)

### 13. Full Temp - Master
```json
{"type":"fullTempResponse","loc":"Master","data":{"hotSet":PARAM{783,1133},"coolSet":PARAM{783,1135},"temp":PARAM{783,1131},"humidity":PARAM{783,1138},"outside":PARAM{783,1137}}}
```

### 14. Full Temp - Spare
```json
{"type":"fullTempResponse","loc":"Spare","data":{"hotSet":PARAM{785,1133},"coolSet":PARAM{785,1135},"temp":PARAM{785,1131},"humidity":PARAM{785,1138},"outside":PARAM{785,1137}}}
```

### 15. Full Temp - Living
```json
{"type":"fullTempResponse","loc":"Living","data":{"hotSet":PARAM{787,1133},"coolSet":PARAM{787,1135},"temp":PARAM{787,1131},"humidity":PARAM{787,1138},"outside":PARAM{787,1137}}}
```

### 16. Full Temp - Kitchen
```json
{"type":"fullTempResponse","loc":"Kitchen","data":{"hotSet":PARAM{791,1133},"coolSet":PARAM{791,1135},"temp":PARAM{791,1131},"humidity":PARAM{791,1138},"outside":PARAM{791,1137}}}
```

### 17. Full Temp - Basement
```json
{"type":"fullTempResponse","loc":"Basement","data":{"hotSet":PARAM{781,1133},"coolSet":PARAM{781,1135},"temp":PARAM{781,1131},"humidity":PARAM{781,1138}}}
```
*Note: Basement does not include "outside" parameter*

### 18. Full Temp - Garage
```json
{"type":"fullTempResponse","loc":"Garage","data":{"hotSet":PARAM{793,1133},"coolSet":PARAM{793,1135},"temp":PARAM{793,1131},"humidity":PARAM{793,1138},"outside":PARAM{793,1137}}}
```

### 19. Full Temp - Outside
```json
{"type":"fullTempResponse","loc":"Outside","data":{"temp":PARAM{1106,1001},"humidity":PARAM{1106,1002}}}
```
*Note: Outside only includes temp and humidity*

## Snow Melt Events (3 commands)

### 20. Snow Melt Start Event
```json
{"type": "snowMeltStart", "loc":"Outside","data": "Melting event received by C4"}
```

### 21. Snow Melt End Event
```json
{"type": "snowMeltEnd", "loc":"Outside","data": PARAM{781,1133}}
```

### 22. Override Snow Event
```json
{"type": "overRideSnowEvent", "loc":"Outside","data": "Override snow melt on for 6 hours"}
```

## Temperature Response (1 command)

### 23. Temp Response - Basement
```json
{"type": "tempResponse", "loc":"basement","data": PARAM{781,1133}}
```

## Snow Melt Status (1 command)

### 24. Snow Melt Status - All Zones
```json
{"type": "snowMeltStatus", "loc":"Outside","data":{"drivewayNorth":PARAM{367,1000},"drivewaySouth":PARAM{368,1000},"tent":PARAM{369,1000}}}
```

## Parameter Reference

The `PARAM{xxx,yyy}` format represents Control4 device parameters:
- First number: Device ID
- Second number: Parameter ID

### Device IDs
- 367: Driveway North zone
- 368: Driveway South zone
- 369: Tent zone
- 781: Basement thermostat
- 783: Master thermostat
- 785: Spare thermostat
- 787: Living thermostat
- 791: Kitchen thermostat
- 793: Garage thermostat
- 1106: Outside weather station

### Common Parameter IDs
- 1000: Zone on/off state
- 1001: Temperature reading
- 1002: Humidity reading
- 1011: Low temperature
- 1020: Precipitation amount
- 1131: Current temperature
- 1133: Heat setpoint
- 1135: Cool setpoint
- 1137: Outside temperature
- 1138: Humidity level

## Composer Configuration Notes

**Total Commands:** 24 unique commands
**Total Occurrences:** 48 (each command appears twice in project XML)

When updating in Composer HE:
1. Composer HE does not allow editing existing action parameters
2. Must delete and recreate each action, or use Find & Replace if available
3. All actions use the same connection parameters (IP, Port, Encoding)
4. Only the JSON command text varies between actions

## Migration History

| Date | Change | Notes |
|------|--------|-------|
| 2026-01-12 | IP: 192.168.20.166 → homesk.kbl55.com (192.168.20.19) | Migrated to Docker container, using DNS hostname |
| 2026-02-21 | Replaced startSnow/stopSnow with per-zone commands | Added startSouth, stopSouth, startNorth, stopNorth, startTent, stopTent. 25-min stagger moved to plugin. |
| 2026-02-21 | Fixed HTTP URL path | Removed `/command/` prefix — commands at root path (`/startSouth` not `/command/startSouth`) |

## Related Documentation

- [TCP Protocol Details](./tcp-protocol.md)
- [Integrations Overview](./integrations.md)
- [Doug's System](./dougs-system.md)
