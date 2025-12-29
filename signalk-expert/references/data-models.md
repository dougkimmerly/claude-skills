# SignalK Data Models

## Delta Model

Used for streaming updates. Most common format for plugins.

```json
{
  "context": "vessels.self",
  "updates": [
    {
      "source": {
        "label": "sensor-name",
        "type": "NMEA2000",
        "pgn": 127250,
        "src": "115"
      },
      "timestamp": "2025-12-02T10:30:00.000Z",
      "values": [
        {
          "path": "navigation.headingMagnetic",
          "value": 2.3456
        },
        {
          "path": "navigation.magneticVariation",
          "value": -0.0174
        }
      ]
    }
  ]
}
```

### Key Points

- `context`: Usually `vessels.self` for own vessel
- `source.label`: Identifies your plugin
- `timestamp`: ISO 8601 format, UTC
- Multiple values can share same update block
- Values are always in SI units

### Minimal Delta (for plugins)

```javascript
app.handleMessage(plugin.id, {
  updates: [{
    values: [
      { path: 'navigation.speedOverGround', value: 3.5 }
    ]
  }]
});
```

Server adds timestamp and source automatically.

## Full Model

Complete state snapshot. Used by REST API.

```json
{
  "version": "1.7.0",
  "self": "vessels.urn:mrn:imo:mmsi:123456789",
  "vessels": {
    "urn:mrn:imo:mmsi:123456789": {
      "mmsi": "123456789",
      "name": "My Boat",
      "navigation": {
        "speedOverGround": {
          "value": 3.5,
          "timestamp": "2025-12-02T10:30:00.000Z",
          "$source": "gps.GP",
          "meta": {
            "units": "m/s",
            "description": "Speed over ground"
          }
        }
      }
    }
  }
}
```

### Key Points

- Each value has `value`, `timestamp`, `$source`
- `meta` contains units and description
- `self` identifies own vessel
- Can contain multiple vessels (AIS targets)

## Source Priority

When multiple sources provide same path, server uses priority:

```javascript
// In plugin, set source priority
app.handleMessage(plugin.id, {
  updates: [{
    source: {
      label: plugin.id,
      priority: 1  // Lower = higher priority
    },
    values: [...]
  }]
});
```

## Meta Values

Publish metadata about your paths:

```javascript
app.handleMessage(plugin.id, {
  updates: [{
    meta: [{
      path: 'navigation.anchor.rodeDeployed',
      value: {
        units: 'm',
        description: 'Length of anchor rode deployed',
        displayName: 'Rode Out',
        zones: [
          { lower: 0, upper: 10, state: 'nominal' },
          { lower: 10, state: 'normal' }
        ]
      }
    }]
  }]
});
```
