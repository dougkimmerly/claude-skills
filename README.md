# Claude Skills Repository

Shared skills for Claude orchestrators across marine systems.

## Purpose

This repository contains modular skills that any Claude instance (PM or CC) can pull in when needed. Skills follow Anthropic's skill format for progressive disclosure and efficient context usage.

## Available Skills

| Skill | Description | Used By |
|-------|-------------|--------|
| `signalk-expert` | SignalK plugin development, paths, APIs | signalk55, signalkDS, powernet, navnet |
| `sensesp-expert` | SensESP sensor development (C++) | Coming soon |
| `victron-expert` | Victron energy systems | Coming soon |

## Usage

### For PM (Web Claude)

Fetch skill files directly from GitHub when working on tasks:
```
github:get_file_contents owner:dougkimmerly repo:claude-skills path:signalk-expert/SKILL.md
```

### For CC (Claude Code)

Clone alongside your working repo:
```bash
cd ~/dkSRC
git clone git@github.com:dougkimmerly/claude-skills.git

# Reference when needed
cat ~/dkSRC/claude-skills/signalk-expert/SKILL.md
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
├── SKILL.md              # Core instructions (lean)
└── references/           # Detailed reference material
    ├── paths.md          # Data paths, schemas
    ├── patterns.md       # Code patterns, examples
    └── api.md            # API documentation
```

## Orchestrators Using This Repo

- **signalk55** - House SignalK server
- **signalkDS** - Distant Shores II main SignalK (future)
- **powernet** - Boat power monitoring (future)
- **navnet** - Boat navigation SignalK (future)
