# Switch Instance and Channel Mapping

## Understanding the Addressing Scheme

### Hierarchy

```
NMEA 2000 Network
└── Switch Instance (Bank)
    └── Channel (1-28 per instance)
        └── Physical Output on CLMD
```

### Instance Assignment Strategy

Plan your instance numbers before installation:

| Instance | Device | Physical Switches | Use Case |
|----------|--------|-------------------|----------|
| 0 | CLMD12 #1 | Channels 1-12 | Salon/galley lighting |
| 1 | CLMD12 #2 | Channels 1-12 | Cabin/head lighting |
| 2 | CLMD16 #1 | Channels 1-16 | Deck/nav/pumps |

### SignalK Path Format

```
electrical.switches.bank.{instance}.{channel}.state
```

Examples:
- `electrical.switches.bank.0.1.state` → Instance 0, Channel 1
- `electrical.switches.bank.2.15.state` → Instance 2, Channel 15

## Planning Your Circuit Map

### Documentation Template

Create a spreadsheet or document with:

| Instance | Channel | Circuit Name | Location | Amp Rating | Notes |
|----------|---------|--------------|----------|------------|-------|
| 0 | 1 | Salon Overhead | Salon | 5A | Dimmable |
| 0 | 2 | Galley Counter | Galley | 5A | Under-cabinet |
| 0 | 3 | Nav Station | Nav | 5A | Chart light |
| 0 | 5 | Anchor Light | Masthead | 10A | LED |
| 0 | 11 | Bilge Pump | Bilge | 12A | Auto + Manual |

### Naming Conventions

Keep names consistent for easier automation:
- Use location prefixes: `salon_`, `galley_`, `cabin_`, `deck_`
- Use function suffixes: `_overhead`, `_task`, `_accent`
- Example: `salon_overhead`, `galley_task`, `deck_courtesy`

## Keypad Button Mapping

### CKM12 Configuration

Each button on a CKM12 can control:
- Single channel (direct toggle)
- Multiple channels (scene)
- Channels on different CLMDs

| Button | Label | Action | Target Instance.Channel |
|--------|-------|--------|------------------------|
| 1 | All Off | Scene | 0.1-12 OFF |
| 2 | Day | Scene | 0.1,0.3,0.5 ON |
| 3 | Night | Scene | 0.2,0.4 ON (dim) |
| 4-12 | Individual | Toggle | Various |

### Scene Programming

Scenes trigger multiple channels simultaneously:

```
Scene: "Evening"
- Instance 0, Channel 1: ON (50% dim)
- Instance 0, Channel 2: ON (30% dim)
- Instance 0, Channel 5: OFF
- Instance 1, Channel 3: ON (100%)
```

## VMM6 Switch Assignment

### Typical Layout

| Position | Label | Instance.Channel |
|----------|-------|------------------|
| 1 | Nav Lights | 0.5 |
| 2 | Anchor Light | 0.6 |
| 3 | Deck Lights | 0.7 |
| 4 | Spreaders | 0.8 |
| 5 | Instruments | 0.9 |
| 6 | Bilge Pump | 0.11 |

## Multi-Device Coordination

### When Using Multiple CLMDs

1. **Assign unique instances** to each CLMD
2. **Document the mapping** thoroughly
3. **Test each channel** after programming
4. **Label the physical outputs** at the CLMD

### Cross-Device Scenes

A single keypad button can control channels across multiple CLMDs:

```
Button "All Lights Off":
- CLMD12 #1 (Instance 0): Channels 1-10 OFF
- CLMD12 #2 (Instance 1): Channels 1-8 OFF
- CLMD16 #1 (Instance 2): Channels 5-12 OFF
```

## SignalK Metadata

### Adding Channel Names

Use the switchbank plugin or custom plugin to inject metadata:

```json
{
  "electrical.switches.bank.0.1": {
    "meta": {
      "displayName": "Salon Overhead",
      "longName": "Salon Overhead Lights",
      "zone": "salon"
    }
  }
}
```

### Benefits of Metadata

- UI displays friendly names
- Grouping by zone in apps
- Easier automation rules

## Troubleshooting Mapping Issues

### Wrong Channel Responds

1. Verify instance number in CLMD configuration
2. Check for duplicate instance assignments
3. Confirm channel mapping in documentation

### Channel Not Responding

1. Check CLMD status LEDs
2. Verify channel is enabled in programming
3. Test with N2KAnalyzer direct control
4. Check SignalK logs for PUT errors

### Multiple Channels Respond

1. Scene accidentally programmed
2. Keypad button configured for multiple channels
3. Check N2KAnalyzer programming
