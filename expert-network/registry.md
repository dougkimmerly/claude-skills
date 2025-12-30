# Expert Registry

Auto-maintained by CC experts. Each expert updates their own entry.

## Active Experts

| Expert | Repo | Domain Keywords | Capabilities | Handoff |
|--------|------|-----------------|--------------|---------|
| claude-broker | dougkimmerly/claude-broker | messaging, orchestration, multi-agent | Message routing, session spawning, dashboard API | `.claude/handoff/` |
| CC-framework | dougkimmerly/claude-project-framework | templates, standards, multi-agent, project setup | Framework templates, PM/CC coordination, project standards | .claude/handoff/ |
| snowmelt | dougkimmerly/signalk-snowmelt | weather, snow melt, thermostat, C4 TCP, temperature control | TCP protocol to C4, weather-based automation, zone control | `.claude/handoff/` |
| anchor-alarm | dougkimmerly/signalk-anchorAlarmConnector | anchor, GPS, SignalK, geofence, alarm | Anchor monitoring, GPS calculations, SignalK deltas | `.claude/handoff/` |
| chain-counter | dougkimmerly/SensESP-chain-counter | ESP32, SensESP, chain, windlass, hardware | Embedded C++, pulse counting, calibration | `.claude/handoff/` |
| homelab | dougkimmerly/homelab | infrastructure, Docker, network, deployment, Synology | Container orchestration, network topology, service deployment | `.claude/handoff/` |

## How to Register

CCs register themselves by updating this file. Add or update your entry in the table above.

### Registration Info

| Field | Description | Example |
|-------|-------------|---------|
| **Expert** | Short name (typically repo name without org) | `snowmelt` |
| **Repo** | Full GitHub repo path | `dougkimmerly/signalk-snowmelt` |
| **Domain Keywords** | What topics you know (for PM to find you) | `weather, snow melt, thermostat, C4 TCP` |
| **Capabilities** | What you can answer questions about | `TCP protocol, weather automation, zone control` |
| **Handoff** | Path to your handoff queue | `.claude/handoff/` |

### CC Registration Command

Add this to your `.claude/commands/register.md`:

```markdown
# Register Expert

Update your entry in the expert-network registry.

## Steps

1. Clone/pull claude-skills repo:
   ```bash
   cd ~/dkSRC
   git clone git@github.com:dougkimmerly/claude-skills.git 2>/dev/null || (cd claude-skills && git pull)
   ```

2. Read your CLAUDE.md to understand your domain

3. Update your entry in `claude-skills/expert-network/registry.md`:
   - If entry exists: update capabilities/keywords if changed
   - If new: add row to Active Experts table

4. Commit and push:
   ```bash
   cd ~/dkSRC/claude-skills
   git add expert-network/registry.md
   git commit -m "expert: Update [your-name] registration"
   git push
   ```

5. Confirm registration complete
```

### When to Register

- First time setting up a project with handoff capability
- After significant capability changes (new integrations, features)
- When domain expertise expands

## Querying Experts

PM searches this registry by domain keywords to find the right expert to ask.

**Example:** PM needs to know about "C4 TCP protocol"
1. Search registry for "C4" or "TCP" → finds `snowmelt`
2. Queue task to `dougkimmerly/signalk-snowmelt/.claude/handoff/todo/`
3. User runs CC, expert responds
4. PM extracts knowledge to appropriate skill

## Future: Structured Registry

For programmatic querying, a `registry.json` could complement this file:

```json
{
  "experts": [
    {
      "name": "snowmelt",
      "repo": "dougkimmerly/signalk-snowmelt",
      "keywords": ["weather", "snow melt", "thermostat", "C4 TCP", "temperature"],
      "capabilities": ["TCP protocol to C4", "weather-based automation", "zone control"],
      "handoff": ".claude/handoff/",
      "lastUpdated": "2025-12-29"
    }
  ]
}
```

This enables future tooling to auto-suggest experts based on query keywords.
