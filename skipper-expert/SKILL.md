---
name: skipper-expert
description: SKipper app configuration, UI design, and SignalK integration
triggers:
  - SKipper app
  - SKipper pages
  - SKipper controls
  - SKipper layouts
  - boat dashboard
  - SignalK display app
  - anchor alarm button
  - autopilot control UI
---

# SKipper Expert

SKipper is a highly customizable Signal K display application available for iOS, Android, Linux, Windows, macOS, and web browsers. It displays boat data from SignalK servers and can control PUT-capable devices.

## Quick Reference

| Resource | URL |
|----------|-----|
| Documentation | https://docs.skipperapp.net/ |
| Discord Support | https://discord.gg/C84EWhqNvM |
| GitHub Issues | https://github.com/SKipperDevelopers/support/issues |
| Live Demo | http://play.skipperapp.net/ |
| iOS App | App Store "SKipper App" |
| Android App | Google Play Store "SKipper" |

## Core Concepts

### Architecture

```
SKipper UI Hierarchy:
├── Home Screen (system page)
├── User Pages (unlimited)
│   └── Layouts (Grid, Stack, Group)
│       └── Controls (Content, Action, Layout)
│           └── Bindings (SignalK paths)
└── Settings (system page)
```

### Platforms

- **iOS/iPadOS**: Native app from App Store
- **Android**: Native app from Play Store  
- **Linux**: Debian packages (Raspberry Pi, AMD64, ARM)
- **Windows**: Installer available
- **macOS**: App Store (ARM Macs)
- **Web**: WASM/WebAssembly in any browser

### Key Features

- **Zones & Notifications**: Color-coded displays based on SignalK zones
- **PUT Requests**: Control relays, autopilot, anchor alarm via buttons
- **Multi-device sync**: Share pages across devices via SignalK server storage
- **Templates**: Pre-built page templates for common use cases
- **mDNS Discovery**: Auto-find SignalK servers on network

## Page Design Workflow

1. **Plan your data** - List SignalK paths you need to display
2. **Group by purpose** - Navigation, Engine, Electrical, Weather, etc.
3. **Choose layouts** - Grid for structured data, Stack for scrolling lists
4. **Select controls** - Match control type to data type
5. **Bind to paths** - Connect controls to SignalK data
6. **Apply converters** - Format data for display
7. **Set zones** - Color-code by value ranges

## Controls Quick Reference

### Content Controls (Display Data)

| Control | Best For | Shape |
|---------|----------|-------|
| TitleValue | Single numeric value with label | Rectangular |
| Label | Text, position, static info | Rectangular |
| HorizontalBar | Progress/level with bar | Wide rectangle |
| VerticalBar | Tank levels, vertical progress | Tall rectangle |
| Compass | Heading display | Square |
| Wind Gauge | Wind direction + speed | Square |
| Analog Gauge | RPM, pressure, classic look | Square |
| Digital Gauge | Modern arc-style numeric | Square |
| Liquid Gauge | Tank levels with animation | Square |
| Graph (History) | Trends over time | Rectangular |
| Modern Compass | COG, heading, wind, waypoint | Square |
| Vector Image | Custom programmable graphics | Any |

### Action Controls (Send Commands)

| Control | Use Case |
|---------|----------|
| Button | One-shot actions: drop anchor, tack, navigate to page |
| Toggle Button | On/off states: lights, pumps, switches |

### Layout Controls

| Control | Use Case |
|---------|----------|
| Grid | Structured rows/columns with proportional sizing |
| Stack | Scrollable list (vertical or horizontal) |
| Group | Titled section within a Stack |

## SignalK Integration

### Authentication

1. SKipper sends Access Request to SignalK server
2. Approve in SignalK Admin UI → Security → Access Requests
3. Set Authentication Timeout to "NEVER" for persistent connection
4. SKipper stores token for automatic reconnection

### PUT Requests (Control Devices)

SKipper can send PUT requests to control:
- **Relays**: `electrical.switches.*`
- **Autopilot**: Via Autopilot API v2 or legacy plugin
- **Anchor Alarm**: Drop, raise, set radius
- **Any PUT-capable path**: Custom plugins

### Zones

SignalK zones are respected automatically:
- **Normal/Nominal**: Green
- **Warning**: Orange  
- **Alert/Critical/Emergency**: Red

Use "Zone to Color" converter to apply zone colors to control properties.

## Common Patterns

### Anchor Alarm Control

1. Add Button control
2. Click action: "Anchor alarm"
3. Select action: "Lower anchor" / "Raise anchor" / "Set radius"
4. Enable confirmation to prevent accidents

### Autopilot Control

1. Add Button control
2. Click action: "autopilot"
3. Select action: "Tack", "Adjust heading", etc.
4. Use template page for complete autopilot UI

### Tank Levels

1. Use Liquid Gauge or VerticalBar
2. Bind to `tanks.*.currentLevel`
3. Set min=0, max=1 (or actual capacity)
4. Apply zones for low-level warnings

### Battery Monitoring

1. Use HorizontalBar with zones
2. Bind Value to `electrical.batteries.*.voltage`
3. Bind Stroke Color to same path with "Zone to Color" converter
4. Define zones in SignalK for voltage ranges

## Reference Files

For detailed information, see:

| File | Contents |
|------|----------|
| `references/controls.md` | All control types with properties |
| `references/layouts.md` | Grid, Stack, Group configuration |
| `references/converters.md` | Data formatting options |
| `references/actions.md` | Button actions and PUT requests |
| `references/installation.md` | Platform-specific setup |

## Tips

1. **Start with templates** - Modify existing templates rather than building from scratch
2. **Test with demo server** - Use demo.signalk.org to practice
3. **Design for device** - Different layouts for phone vs tablet vs desktop
4. **Use Icon Bar** - Enable commonly-used pages for one-tap access
5. **Sync pages** - Store UI in SignalK server to share across devices
6. **Confirmation dialogs** - Always enable for destructive actions (drop anchor, etc.)
