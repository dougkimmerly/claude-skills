# Register Expert

Register or update this project's entry in the expert-network registry.

## When to Run

- First time setting up handoff capability
- After adding significant new features or integrations
- When your domain expertise has expanded

## Steps

### 1. Clone/Update Skills Repo

```bash
cd ~/dkSRC
git clone git@github.com:dougkimmerly/claude-skills.git 2>/dev/null || (cd claude-skills && git pull)
```

### 2. Analyze Your Expertise

Read this project's CLAUDE.md and determine:
- **Expert name:** Short identifier (typically repo name)
- **Domain keywords:** Topics you know about (comma-separated, for PM searching)
- **Capabilities:** What questions you can answer
- **Handoff path:** Where your task queue lives

### 3. Update Registry

Edit `~/dkSRC/claude-skills/expert-network/registry.md`:

**If new expert:** Add a row to the "Active Experts" table
**If existing:** Update your row with any changes

Table format:
```markdown
| Expert | Repo | Domain Keywords | Capabilities | Handoff |
|--------|------|-----------------|--------------|---------|
| [name] | dougkimmerly/[repo] | [keywords] | [capabilities] | `.claude/handoff/` |
```

### 4. Commit and Push

```bash
cd ~/dkSRC/claude-skills
git add expert-network/registry.md
git commit -m "expert: Register/update [PROJECT_NAME]"
git push
```

### 5. Confirm

Report: "Registered [name] expert with keywords: [keywords]"

## Example Registration

For signalk-snowmelt:

| Expert | Repo | Domain Keywords | Capabilities | Handoff |
|--------|------|-----------------|--------------|---------|
| snowmelt | dougkimmerly/signalk-snowmelt | weather, snow melt, thermostat, C4 TCP, temperature control | TCP protocol to C4, weather-based automation, zone control | `.claude/handoff/` |

## Notes

- Only update YOUR entry - don't modify other experts
- Keep keywords searchable - think "what would PM search for?"
- Capabilities should be specific - what can you actually answer?
- This enables PM to find you when domain questions arise
