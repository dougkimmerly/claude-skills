---
name: c4-expert
description: Control4 home automation expertise for homeowner-level system management. Use when working with Control4 programming (Composer HE, When>>Then), lighting scenes, scheduling, multi-room audio, amplifier configuration, Zigbee troubleshooting, or integrating C4 with other systems (Home Assistant, MQTT). Covers the dealer-locked ecosystem from a homeowner perspective, finding workarounds, and maximizing system capabilities without Composer Pro access.
---

# Control4 Expert

Expertise for Control4 home automation from a homeowner perspective. Control4 is a dealer-centric ecosystem where homeowners have limited but expanding capabilities through Composer HE, When>>Then, and the mobile app.

## Homeowner Access Levels

| Tool | Access | Capabilities |
|------|--------|-------------|
| **Control4 App** | Free | Control devices, basic scene editing, favorites |
| **When>>Then** | 4Sight ($99/yr) | Simple if-then automations via web portal |
| **Composer HE** | $149 one-time | Full programming, agents, media management |
| **Composer Pro** | Dealer only | Add devices, drivers, system configuration |

## Quick Reference

### When>>Then Programming (customer.control4.com)

Simple automations without Composer HE:
- Trigger: Button press, time, sensor state, device state
- Action: Light control, scene activation, notifications
- Limitation: Cannot create complex conditionals or variables

### Composer HE Views

| View | Purpose |
|------|---------|
| **Monitoring** | See device states, test controls |
| **Media** | Manage music/video libraries, playlists |
| **Agents** | Configure Scheduler, Lighting Scenes, Macros |
| **Programming** | Event-action programming, conditionals |

### Programming Pattern (Events → Actions)

```
WHEN: [Event occurs]
  IF: [Conditional check] (optional)
  THEN: [Execute actions]
  ELSE: [Alternative actions] (optional)
```

**Common Events:**
- Keypad button press (tap, double-tap, hold)
- Time/schedule trigger
- Device state change
- Variable change

### Useful Agents

| Agent | Purpose |
|-------|---------|
| **Advanced Lighting** | Complex scenes with delays, ramps, tracking |
| **Scheduler** | Time-based events (sunrise/sunset, recurring) |
| **Macros** | Reusable action sequences |
| **Media Scenes** | Multi-room audio configurations |
| **Wakeup/Goodnight** | Morning/evening routines with gradual changes |
| **Announcements** | Play WAV files on events |

### Network Ports

| Port | Service |
|------|---------|
| 22 | SSH (controller) |
| 80 | HTTP web interface |
| 443 | HTTPS |
| 5020 | Director communication |
| 5021 | Composer connection |
| 9000 | Device control API |

## Doug's System

See [references/dougs-system.md](references/dougs-system.md) for:
- Controller and device inventory
- Network addresses (192.168.20.41-45, .181, .190)
- Audio zone configuration
- Integration points

## Detailed References

- **[references/composer-he.md](references/composer-he.md)** - Homeowner programming guide
- **[references/agents-programming.md](references/agents-programming.md)** - Scheduler, Advanced Lighting, Macros
- **[references/hardware.md](references/hardware.md)** - Controllers, amplifiers, Zigbee mesh
- **[references/integrations.md](references/integrations.md)** - Home Assistant, MQTT, third-party drivers
- **[references/troubleshooting.md](references/troubleshooting.md)** - Common issues and solutions

## Key Resources

| Resource | URL |
|----------|-----|
| Customer Portal | https://customer.control4.com |
| When>>Then | https://my.control4.com |
| Official Docs | https://docs.control4.com |
| C4 Forums (community) | https://www.c4forums.com |
| DriverCentral (3rd party) | https://drivercentral.io |
| Chowmain Drivers | https://chowmain.software |
