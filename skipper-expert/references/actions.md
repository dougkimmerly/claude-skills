# SKipper Button Actions Reference

## Signal K PUT Request

Send a value to any PUT-capable SignalK path.

### Value Types

**Boolean:**
```
Path: electrical.switches.anchorLight.state
Value: true / false
```

**Number:**
```
Path: steering.autopilot.target.headingMagnetic
Value: 180
```

**String:**
```
Path: steering.autopilot.state
Value: "auto"
```

**Toggle:**
Flips current boolean value.

**Increment:**
Adds to current numeric value.
```
Path: steering.autopilot.target.headingMagnetic
Value: +10 (adds 10 to current)
Value: -10 (subtracts 10)
```

---

## Autopilot Control

Integrates with SignalK Autopilot API v2.

### Available Actions

| Action | Description |
|--------|-------------|
| Engage | Enable autopilot |
| Disengage | Disable autopilot |
| Tack Port | Tack to port |
| Tack Starboard | Tack to starboard |
| Adjust Heading | Change heading by degrees |
| Set Mode | compass, wind, gps |
| Set Target | Specific heading value |

### Setup

1. Add Button control
2. Click action: "autopilot"
3. Select specific action
4. Set parameters (direction, amount, etc.)
5. Enable confirmation for safety

### Requirements

- SignalK Autopilot plugin installed
- Autopilot hardware connected to SignalK
- For KIP compatibility: disable V2 API in plugin config

---

## Anchor Alarm Control

Integrates with SignalK Anchor Alarm plugin.

### Available Actions

| Action | Description |
|--------|-------------|
| Lower anchor | Drop anchor, mark position |
| Raise anchor | Clear anchor position |
| Set radius | Define alarm radius |

### Best Practices

- **Always enable confirmation** for Lower/Raise
- Create dedicated Anchor page with:
  - Drop button
  - Raise button
  - Radius adjustment
  - Current position display
  - Alarm status indicator

### Related Paths

```
navigation.anchor.position.latitude
navigation.anchor.position.longitude
navigation.anchor.currentRadius
navigation.anchor.maxRadius
navigation.anchor.state
notifications.navigation.anchor
```

---

## SKipper Internal Actions

### Toggle Theme
Switch between light and dark mode.

### Set Theme
Force specific theme (light or dark).

### Go to Home
Navigate to Home screen.

### Go to Settings
Open Settings page.

### Toggle Icon Bar
Show/hide the icon bar.

### Load UI
Load saved UI configuration from SignalK server.

### Save UI
Save current UI configuration to SignalK server.

### Run Quick Action
Execute user-defined quick action.

---

## Page Navigation

Jump to any user-defined page.

**Use for:**
- Menu buttons
- Context-sensitive navigation
- Wizard-style workflows

---

## OS Command (Desktop Only)

Execute system command on Linux, macOS, or Windows.

**Examples:**
- Launch external application
- Run script
- System control

**Security note:** Only available on desktop platforms, not mobile.

---

## Open URL

Open web page in default browser.

**Use for:**
- Links to documentation
- External dashboards
- Related web apps

---

## Confirmation Dialogs

Enable for any action that:
- Could cause physical action (drop anchor, tack)
- Is difficult to reverse
- Has safety implications

**Configuration:**
- Enable/disable per button
- Custom confirmation message (optional)
- User must tap/click twice to execute

---

## Toggle Button Specifics

For boolean paths only.

### How it works
1. Displays current state (on/off)
2. Tap toggles the value
3. Sends PUT request with opposite value
4. Updates display when SignalK confirms

### Suitable Paths

```
electrical.switches.*.state
electrical.relays.*.state
navigation.lights.*.state
```

### Styling

- **Default:** Icon changes based on state
- **Switch:** Physical switch appearance
- **Toggle with Text:** Full label + toggle indicator
