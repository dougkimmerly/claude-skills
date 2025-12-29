---
name: expert-network
description: Directory of local CC experts that can be queried for domain-specific knowledge. Use this skill to find which expert to ask when you need deep knowledge about a specific system (Control4, SignalK, homelab, etc.). Each expert has full codebase access and can provide implementation details that PM doesn't have.
---

# Expert Network

A registry of local CC experts available for domain-specific queries. Each expert is a CC instance with deep access to a specific codebase or system.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    PM (Web Claude)                          │
│               Orchestrator / Knowledge Synthesizer          │
└─────────────────────┬───────────────────────────────────────┘
                      │ task queues (handoff/todo/)
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
   ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐
   │snowmelt │  │ homelab  │  │ anchor  │  │   c4     │
   │ expert  │  │  expert  │  │  expert │  │  expert  │
   └────┬────┘  └────┬─────┘  └────┬────┘  └────┬─────┘
        │            │             │            │
   [codebase]   [infra docs]  [codebase]   [system docs]
```

**Benefits:**
- Experts have **full codebase context** (CC can read all files)
- PM stays lightweight, queries experts on-demand
- Knowledge gets **extracted into skills** for reuse
- Experts can answer implementation questions PM can't

## Querying an Expert

### 1. Create a task in their handoff queue

```markdown
# TASK-XXX: [Brief title]

**Priority:** normal
**Created:** YYYY-MM-DD

## Context
[Why you need this information]

## Questions
1. [Specific question]
2. [Another question]

## Deliverable
[What format you want the response in]
```

### 2. Push to their repo's handoff/todo/

PM uses GitHub MCP:
```
github:create_or_update_file
  repo: [expert-repo]
  path: .claude/handoff/todo/TASK-XXX.md
```

### 3. Have user run CC against that repo

```bash
cd ~/path/to/expert-repo && claude
> msg  # CC checks for tasks
```

### 4. Fetch response from handoff/complete/

```
github:get_file_contents
  repo: [expert-repo]
  path: .claude/handoff/complete/TASK-XXX/RESPONSE.md
```

## Available Experts

| Expert | Repo | Domain | Handoff Path |
|--------|------|--------|--------------|
| **snowmelt** | dougkimmerly/signalk-snowmelt | Weather automation, C4 TCP integration, thermostat control | `.claude/handoff/` |
| **anchor-alarm** | dougkimmerly/signalk-anchorAlarmConnector | SignalK anchor monitoring, GPS calculations | `.claude/handoff/` |
| **chain-counter** | dougkimmerly/SensESP-chain-counter | ESP32/SensESP, chain counting, hardware integration | `.claude/handoff/` |
| **homelab** | dougkimmerly/homelab | Infrastructure, Docker, network topology, deployment | `.claude/handoff/` |

## Adding New Experts

Any repo with the v2 handoff structure can become an expert:

```
.claude/
└── handoff/
    ├── todo/           # PM writes tasks here
    ├── complete/       # CC writes responses here
    └── archive/        # Old tasks
```

Add the repo to this index when:
1. The repo has handoff infrastructure
2. CC has been used successfully against it
3. It contains domain knowledge worth querying

## Example: Querying Snowmelt Expert

**Task queued:**
```markdown
# TASK-001: Control4 TCP Integration Documentation

## Questions
1. What is the TCP command format?
2. What commands exist?
3. How is C4 configured to receive them?

## Deliverable
Document protocol for c4-expert skill
```

**Response received:**
- Full protocol documentation
- Code examples with line numbers
- Gotchas and limitations
- Integration examples for n8n, Home Assistant

**Outcome:**
- Created `c4-expert/references/tcp-protocol.md`
- Knowledge now available to all future sessions

## Best Practices

1. **Be specific** - Ask concrete questions, not "tell me about X"
2. **Request deliverables** - Specify format (markdown, code, etc.)
3. **Provide context** - Explain why you need the info
4. **Extract to skills** - Good responses should become skill references
5. **One topic per task** - Don't overload with unrelated questions

## Future Experts (Planned)

| Expert | Repo | Domain |
|--------|------|--------|
| music-library | TBD | Music organization, Last.fm integration, playlists |
| boat-systems | signalk55 (orchestrator) | Full boat SignalK setup, all marine integrations |
| automation | TBD | Custom automation system (replacing n8n) |
