---
name: expert-network
description: Directory of local CC experts that can be queried for domain-specific knowledge. Use this skill to find which expert to ask when you need deep knowledge about a specific system (Control4, SignalK, homelab, etc.). Each expert has full codebase access and can provide implementation details that PM doesn't have. Experts self-register via the /register command.
---

# Expert Network

A self-maintaining registry of local CC experts available for domain-specific queries. Each expert is a CC instance with deep access to a specific codebase or system.

## Quick Reference

| Resource | Path |
|----------|------|
| **Expert Registry** | [registry.md](registry.md) - searchable by domain keywords |
| **Registration Template** | [templates/register.md](templates/register.md) - for new experts |

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
   │snowmelt │  │ homelab  │  │ anchor  │  │  more... │
   │ expert  │  │  expert  │  │  expert │  │          │
   └────┬────┘  └────┬─────┘  └────┬────┘  └────┬─────┘
        │            │             │            │
   [codebase]   [infra docs]  [codebase]   [self-register]
```

**Key Features:**
- **Self-maintaining** - CCs register themselves via `/register` command
- **Searchable** - Registry has domain keywords for PM to find experts
- **Full codebase context** - Each expert can read all files in their repo
- **Knowledge extraction** - Good answers become reusable skill references

## For PM: Finding & Querying Experts

### 1. Search the Registry

Check [registry.md](registry.md) for domain keywords matching your question.

Example: Need "C4 TCP protocol" → search for "C4" or "TCP" → find snowmelt expert

### 2. Queue a Task

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

Push to expert's handoff:
```
github:create_or_update_file
  repo: [expert-repo from registry]
  path: .claude/handoff/todo/TASK-XXX.md
```

### 3. User Runs CC

```bash
cd ~/path/to/expert-repo && claude
> msg  # CC checks for tasks
```

### 4. Fetch Response

```
github:get_file_contents
  repo: [expert-repo]
  path: .claude/handoff/complete/TASK-XXX/RESPONSE.md
```

### 5. Extract to Skills

Good responses should become permanent skill references - don't let knowledge stay buried in handoff archives.

## For CC: Registering as an Expert

### Prerequisites

Your repo needs v2 handoff structure:
```
.claude/
└── handoff/
    ├── todo/           # PM writes tasks here
    ├── complete/       # You write responses here
    └── archive/        # Old tasks
```

### Registration

1. Copy [templates/register.md](templates/register.md) to your `.claude/commands/register.md`
2. Run `/register` in your CC session
3. Your entry appears in [registry.md](registry.md)

### When to Re-register

- After adding significant new features
- When integrations change
- When your domain expertise expands

## Best Practices

### For PM (querying):
- **Be specific** - Ask concrete questions, not "tell me about X"
- **Request deliverables** - Specify format (markdown, code, etc.)
- **Provide context** - Explain why you need the info
- **Extract to skills** - Good responses should become skill references
- **One topic per task** - Don't overload with unrelated questions

### For CC (responding):
- **Include code locations** - Line numbers, function names
- **Document gotchas** - What will trip people up?
- **Give examples** - Show, don't just tell
- **Keep keywords updated** - Re-register when capabilities change

## Example Flow

**PM needs:** Control4 TCP protocol details

1. **Search registry** → "C4 TCP" matches snowmelt expert
2. **Queue task** → signalk-snowmelt handoff/todo/
3. **CC responds** → 16KB protocol documentation with code locations
4. **Extract** → Created c4-expert/references/tcp-protocol.md
5. **Result** → Knowledge now available to all future sessions

## Architecture Notes

The expert network is **decentralized by design**:
- No central controller - each expert is autonomous
- Registry is self-maintained - CCs update their own entries
- Knowledge flows outward - responses → skills → shared access
- PM is synthesizer - finds experts, extracts patterns, builds skills
