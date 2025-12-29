# SignalK MCP Server Tools

When working in repos with SignalK MCP configured, these tools provide live data access.

## Available Tools

### mcp__signalk__get_navigation_data

Get current navigation state:
- Position (lat/lon)
- Speed over ground
- Course over ground
- Heading
- Depth

**Use when:** Debugging position-related plugins, verifying GPS data.

### mcp__signalk__get_signalk_overview

Get server info and available data paths:
- Server version
- Available paths
- Connected sources

**Use when:** Discovering what data is available, checking server status.

### mcp__signalk__get_ais_targets

Get nearby AIS vessels:
- MMSI
- Name
- Position
- Course/Speed
- CPA/TCPA

**Use when:** Working with AIS-related features.

### mcp__signalk__get_system_alarms

Get active notifications/alarms:
- Alarm state
- Message
- Path

**Use when:** Debugging notification plugins, checking alarm state.

## When to Use MCP Tools

1. **During development:** Verify your plugin publishes correctly
2. **Before subscribing:** Check what paths/data exist
3. **Debugging:** See live values when something isn't working
4. **Testing:** Confirm expected state after commands

## Example Workflow

```
1. Check current state:
   -> mcp__signalk__get_navigation_data
   
2. Run your plugin code

3. Verify output:
   -> mcp__signalk__get_signalk_overview (check new paths)
   -> mcp__signalk__get_system_alarms (if alarm-related)
```

## Configuration

MCP server configured in `.mcp.json`:

```json
{
  "mcpServers": {
    "signalk": {
      "command": "npx",
      "args": ["-y", "signalk-mcp-server", "--host", "192.168.20.55", "--port", "3000"]
    }
  }
}
```
