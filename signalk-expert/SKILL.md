---
name: signalk-expert
description: SignalK plugin development expertise for marine data systems. Use when developing SignalK plugins (JavaScript), working with SignalK paths and data models, subscribing to or publishing SignalK data, implementing PUT handlers, or integrating with SignalK servers. Covers delta/full models, SI units, WebSocket/REST APIs, and plugin lifecycle.
---

# SignalK Expert

Expertise for developing SignalK plugins and working with SignalK data.

## Quick Reference

### Data Models

**Delta Model** (most common - for streaming updates):
```json
{
  "context": "vessels.self",
  "updates": [{
    "source": {"label": "my-plugin"},
    "timestamp": "2025-12-02T10:30:00Z",
    "values": [
      {"path": "navigation.speedOverGround", "value": 3.5}
    ]
  }]
}
```

**Full Model** (complete state snapshot) - see [references/data-models.md](references/data-models.md)

### Units (Always SI)

| Measurement | Unit | Conversion |
|-------------|------|------------|
| Speed | m/s | knots × 0.514444 |
| Temperature | K | °C + 273.15 |
| Angles | rad | degrees × (π/180) |
| Distance | m | - |
| Pressure | Pa | PSI × 6894.76 |
| RPM | Hz | RPM / 60 |
| Ratios | 0-1 | percentage / 100 |

### Plugin Lifecycle

```javascript
module.exports = function(app) {
  const plugin = {
    id: 'my-plugin',
    name: 'My Plugin',
    
    start: function(options) {
      // Initialize - subscribe, setup timers
    },
    
    stop: function() {
      // Cleanup - unsubscribe, clear timers
    },
    
    schema: {
      type: 'object',
      properties: {
        // Configuration options
      }
    }
  };
  return plugin;
};
```

### Publishing Data

```javascript
app.handleMessage(plugin.id, {
  updates: [{
    values: [{
      path: 'navigation.speedOverGround',
      value: 3.5  // Always SI units!
    }]
  }]
});
```

### Subscribing to Data

```javascript
const unsubscribes = [];
app.subscriptionmanager.subscribe(
  {
    context: 'vessels.self',
    subscribe: [{ path: 'navigation.position' }]
  },
  unsubscribes,
  (err) => { if (err) app.error(err); },
  (delta) => {
    // Handle incoming data
    delta.updates.forEach(update => {
      update.values.forEach(v => {
        app.debug(`${v.path}: ${v.value}`);
      });
    });
  }
);

// In stop(): unsubscribes.forEach(f => f());
```

### PUT Handler (Receive Commands)

```javascript
app.registerPutHandler('vessels.self', 'navigation.anchor.setAnchor',
  (context, path, value, callback) => {
    // Validate
    if (!value.latitude || !value.longitude) {
      return callback({ state: 'COMPLETED', statusCode: 400, message: 'Missing coords' });
    }
    // Process
    setAnchor(value);
    return callback({ state: 'COMPLETED', statusCode: 200 });
  }
);
```

## Detailed References

- **[references/paths.md](references/paths.md)** - Common SignalK paths (navigation, environment, electrical, propulsion, tanks)
- **[references/data-models.md](references/data-models.md)** - Full vs Delta models, source handling
- **[references/api.md](references/api.md)** - WebSocket subscriptions, REST endpoints
- **[references/mcp-tools.md](references/mcp-tools.md)** - SignalK MCP server tools for live debugging

## Key Documentation

| Resource | URL |
|----------|-----|
| Specification | https://signalk.org/specification/latest/ |
| Path Reference | https://signalk.org/specification/1.5.0/doc/vesselsBranch.html |
| Plugin Dev Guide | https://demo.signalk.org/documentation/Developing/Plugins.html |
