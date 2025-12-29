# SKipper Tips & Best Practices

## Page Organization

### Recommended Page Structure

**Navigation:**
- Compass, COG, SOG
- Position
- Depth
- Wind (if sailing)

**Engine:**
- RPM
- Temperatures (coolant, exhaust, oil)
- Pressures
- Hours

**Electrical:**
- Battery banks (voltage, current, SOC)
- Solar/charging
- Loads

**Tanks:**
- Fuel
- Water
- Holding

**Anchor:**
- Drop/raise buttons
- Position
- Scope
- Alarm status

**Weather:**
- Temperature
- Humidity
- Pressure (with history graph)
- Wind

---

## Multi-Device Strategy

### Phone (Quick Checks)
- 1-2 pages max
- Most critical data only
- Large controls for easy reading

### Tablet (Primary Use)
- Full page set
- Balanced layouts
- Touch-optimized buttons

### Helm Display (Dedicated)
- Navigation focused
- High contrast for sunlight
- Essential data only
- Enable DRM mode for reliability

### Cabin Display (Monitoring)
- Anchor page as default
- Engine room monitoring
- Systems status

---

## Performance Tips

### Reduce Update Load

- Don't put all data on one page
- SKipper only subscribes to visible paths
- Spread data across multiple pages

### History Graphs

- Limit data points (default is fine)
- Use InfluxDB for long-term history
- Reduce update frequency for non-critical data

### Resource Usage

- Close unused SKipper instances
- Use DRM mode on Raspberry Pi
- Web version uses more memory than native

---

## Authentication Best Practices

### Token Management

- Set timeout to "NEVER" for permanent connection
- Store pages on SignalK server for backup
- Each device needs its own authorization

### Security

- Use Admin permissions for full control
- Read-only mode available for display-only
- Enable security on SignalK server

---

## Troubleshooting

### Can't Find Server

1. Check mDNS is enabled on server
2. Verify same network/VLAN
3. Try manual IP entry
4. Check firewall rules

### Connection Drops

1. Verify "NEVER" timeout setting
2. Check WiFi stability
3. Look for SignalK server restarts
4. Check server logs

### Data Not Updating

1. Look for green dots (indicates fresh data)
2. Check path exists in SignalK
3. Verify binding is correct
4. Check for converter errors

### PUT Requests Fail

1. Verify Admin permissions
2. Check plugin supports PUT
3. Look for error messages
4. Test in SignalK Data Browser first

---

## Integration Tips

### With Anchor Alarm Connector

Your `signalk-anchorAlarmConnector` publishes:
- `navigation.anchor.setAnchor` - Trigger from SKipper
- `navigation.anchor.autoReady` - Display status
- `navigation.anchor.scope` - Show current scope

Create buttons that PUT to these paths.

### With Chain Counter (SensESP)

Display `navigation.anchor.rodeDeployed` with:
- TitleValue showing meters/feet
- VerticalBar showing against max rode
- History graph during anchoring

### With Custom Plugins

For any PUT-capable path:
1. Test PUT in SignalK Data Browser
2. Note exact path and value format
3. Create Button with PUT action
4. Test in SKipper

---

## Design Tips

### Readability

- Use AutoSize fonts when possible
- High contrast for outdoor use
- Limit text length in labels
- Test on actual device in real conditions

### Touch Targets

- Buttons should be at least 44x44 pixels
- Add spacing between touch targets
- Enable confirmation for critical actions

### Night Mode

- Red theme preserves night vision
- Low light theme available
- Test at night before relying on it

### Templates

- Start with templates when available
- Modify rather than build from scratch
- Save customized pages as your own templates

---

## Backup & Sync

### Storing UI on Server

1. Settings → Save UI
2. UI stored in SignalK server
3. Any SKipper instance can load it

### Sharing Across Devices

1. Create UI on easiest device (laptop)
2. Save to server
3. Load on other devices
4. Adjust per-device if needed

### Version Control

SKipper UI is JSON. For versioning:
1. Export UI configuration
2. Store in your git repo
3. Track changes over time
