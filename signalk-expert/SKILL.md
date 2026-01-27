---
name: signalk-expert
description: SignalK plugin development and server administration expertise for marine data systems. Use when developing SignalK plugins (JavaScript), working with SignalK paths and data models, subscribing to or publishing SignalK data, implementing PUT handlers, integrating with SignalK servers, or troubleshooting SignalK server issues. Covers delta/full models, SI units, WebSocket/REST APIs, plugin lifecycle, systemd service management, and common server problems.
---

# SignalK Expert

Expertise for developing SignalK plugins, working with SignalK data, and administering SignalK servers.

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

## Server Administration Quick Reference

### Essential Commands

```bash
systemctl status signalk          # Check service status
journalctl -u signalk -n 50       # View recent logs
sudo systemctl restart signalk    # Restart service
```

### Common Fixes

| Problem | Quick Fix |
|---------|-----------|
| Port 80 denied | `sudo setcap 'cap_net_bind_service=+ep' $(which node)` |
| Multiple instances | `ps aux \| grep signalk` then kill rogue PIDs |
| Permission denied on files | `sudo chown -R user:user /path/to/dir` |
| Plugin symlinks gone | Run restore script after App Store updates |
| Device "needs auth" despite token | Set `"acls": []` in security.json |

See [references/server-admin.md](references/server-admin.md) for detailed troubleshooting.

## Detailed References

- **[references/paths.md](references/paths.md)** - Common SignalK paths (navigation, environment, electrical, propulsion, tanks)
- **[references/data-models.md](references/data-models.md)** - Full vs Delta models, source handling
- **[references/api.md](references/api.md)** - WebSocket subscriptions, REST endpoints
- **[references/authentication.md](references/authentication.md)** - Device tokens, ACLs, troubleshooting auth failures
- **[references/mcp-tools.md](references/mcp-tools.md)** - SignalK MCP server tools for live debugging
- **[references/server-admin.md](references/server-admin.md)** - Systemd management, troubleshooting, CAN bus, plugin management

## Key Documentation

| Resource | URL |
|----------|-----|
| Specification | https://signalk.org/specification/latest/ |
| Path Reference | https://signalk.org/specification/1.5.0/doc/vesselsBranch.html |
| Plugin Dev Guide | https://demo.signalk.org/documentation/Developing/Plugins.html |
