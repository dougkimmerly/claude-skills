# Claude Skills Repository

Shared skills for Claude orchestrators across marine systems.

## Purpose

This repository contains modular skills that any Claude instance (PM or CC) can pull in when needed. Skills follow Anthropic's skill format for progressive disclosure and efficient context usage.

## Available Skills

| Skill | Description | Used By |
|-------|-------------|--------|
| `framework-expert` | Claude project framework, standards, PM↔CC coordination, broker | All framework-based projects |
| `signalk-expert` | SignalK plugin development (JS), paths, APIs, data models, server admin | signalk55, signalkDS, powernet, navnet |
| `sensesp-expert` | SensESP sensor development (C++), ESP32, PlatformIO | SensESP-chain-counter, rebootRelay01 |
| `skipper-expert` | SKipper app UI design, controls, layouts, SignalK integration | All SignalK projects |
| `powernet-expert` | Maretron MPower digital switching, CLMD12/16, CKM12, PGNs | powernet, any MPower installation |
| `victron-expert` | Victron energy systems | Coming soon |

## Usage

### For PM (Web Claude)

Fetch skill files directly from GitHub when working on tasks:
```
github:get_file_contents owner:dougkimmerly repo:claude-skills path:framework-expert/SKILL.md
github:get_file_contents owner:dougkimmerly repo:claude-skills path:signalk-expert/SKILL.md
github:get_file_contents owner:dougkimmerly repo:claude-skills path:sensesp-expert/SKILL.md
github:get_file_contents owner:dougkimmerly repo:claude-skills path:skipper-expert/SKILL.md
```

### For CC (Claude Code)

Clone alongside your working repo:
```bash
cd ~/dkSRC
git clone git@github.com:dougkimmerly/claude-skills.git

# Reference when needed
cat ~/dkSRC/claude-skills/framework-expert/SKILL.md
cat ~/dkSRC/claude-skills/signalk-expert/SKILL.md
cat ~/dkSRC/claude-skills/skipper-expert/SKILL.md
```

## Contributing

When you learn something new that should be shared:

1. Update the relevant skill's references
2. Commit with descriptive message
3. Push to main

All orchestrators benefit from accumulated knowledge.

## Skill Structure

Follows Anthropic's skill format:
```
skill-name/
├── SKILL.md              # Core instructions (lean, triggers on keywords)
└── references/           # Detailed reference material
    ├── paths.md          # Data paths, schemas
    ├── patterns.md       # Code patterns, examples
    └── api.md            # API documentation
```

## Current Skill Contents

### framework-expert
```
framework-expert/
├── SKILL.md
└── references/
    ├── standards.md      # PROJECT-STANDARDS.md compliance, audit checklists
    ├── handoff.md        # PM↔CC coordination protocol, task/response formats
    ├── broker.md         # Broker API, registration, task routing
    └── templates.md      # Project templates, scaffolding, customization
```

### signalk-expert
```
signalk-expert/
├── SKILL.md
└── references/
    ├── paths.md          # SignalK data paths (navigation, environment, etc.)
    ├── data-models.md    # Delta vs Full models
    ├── api.md            # REST & WebSocket APIs
    ├── mcp-tools.md      # SignalK MCP server tools
    └── server-admin.md   # Systemd, troubleshooting, CAN bus, plugins
```

### powernet-expert
```
powernet-expert/
├── SKILL.md
└── references/
    ├── devices.md        # CLMD12/16, CKM12, VMM6, CBMD12 specs
    ├── pgns.md           # PGN 127500-127502, 127751 details
    ├── switch-mapping.md # Instance/channel conventions, planning
    ├── plugins.md        # switchbank, signalk-to-nmea2000
    └── programming.md    # N2KAnalyzer workflow, configuration
```

### sensesp-expert
```
sensesp-expert/
├── SKILL.md
└── references/
    ├── producers.md      # Sensor input types (analog, digital, 1-wire)
    ├── transforms.md     # Data processing (linear, average, filter)
    ├── patterns.md       # C++ patterns for embedded
    ├── platformio.md     # Build config, GPIO reference
    └── debugging.md      # Serial monitor, common issues
```

### skipper-expert
```
skipper-expert/
├── SKILL.md
└── references/
    ├── controls.md       # All control types with properties
    ├── layouts.md        # Grid, Stack, Group configuration
    ├── converters.md     # Data formatting options
    ├── actions.md        # Button actions and PUT requests
    ├── installation.md   # Platform-specific setup
    └── tips.md           # Best practices and troubleshooting
```

## Orchestrators & Projects Using This Repo

| Project | Type | Skills Used |
|---------|------|-------------|
| signalk55 | Orchestrator | signalk-expert, skipper-expert |
| signalk-anchorAlarmConnector | Plugin | signalk-expert, skipper-expert |
| signalk-snowmelt | Plugin | signalk-expert |
| SensESP-chain-counter | Firmware | sensesp-expert, signalk-expert |
| signalkDS | Orchestrator (future) | signalk-expert, skipper-expert |
| powernet | Orchestrator (future) | signalk-expert, victron-expert |
| navnet | Orchestrator (future) | signalk-expert, skipper-expert |

## Support Links

| Skill | Documentation | Community |
|-------|---------------|-----------|
| SignalK | https://signalk.org/specification/ | Discord: Signal K |
| SensESP | https://signalk.org/SensESP/ | Discord: #sensesp |
| SKipper | https://docs.skipperapp.net/ | Discord: https://discord.gg/C84EWhqNvM |
