---
name: framework-expert
description: Claude project framework expertise for structured project setup, standards enforcement, and PM↔CC coordination. Use when creating new projects, auditing against standards, working with the handoff system, managing broker registration, or applying framework templates. Covers private-by-default repos, issue tracking, context management, and infrastructure patterns.
---

# Framework Expert

Expertise for working with the claude-project-framework system.

## Quick Reference

### Project Types

| Type | Stack | Use Case |
|------|-------|----------|
| `signalk` | JavaScript, Node.js | SignalK plugins |
| `sensesp` | C++, ESP32, PlatformIO | SensESP sensors |
| `homelab-service` | Docker Compose | Homelab services |
| `webapp` | JS/TS | Web applications |
| `cli` | Node.js | CLI tools |
| `generic` | Any | Other projects |

### Core Principles (Always Apply)

| # | Principle | Enforcement |
|---|-----------|-------------|
| 1 | **Private by default** | All repos PRIVATE unless explicitly "public" |
| 2 | **Single source of truth** | No duplication, one canonical location |
| 3 | **Standards are authoritative** | PROJECT-STANDARDS.md overrides local conventions |
| 4 | **Issues are roadmap** | Track all work in GitHub Issues |
| 5 | **Secrets never in Git** | Use .env files, .gitignore them |
| 6 | **Minimal context** | Load only what's needed |

### Required Repository Files

```
project-root/
├── CLAUDE.md                    # ✅ Entry point (<150 lines)
├── README.md                    # ✅ Human docs
├── .gitignore                   # ✅ Exclude secrets
├── .claude/
│   ├── commands/                # ✅ Workflow commands
│   │   ├── implement.md
│   │   ├── debug.md
│   │   ├── review.md
│   │   └── test.md
│   ├── context/                 # ✅ On-demand context
│   │   ├── architecture.md
│   │   ├── domain.md
│   │   └── patterns.md
│   └── handoff/                 # ✅ PM↔CC queues
│       ├── todo/                # PM writes tasks here
│       ├── complete/            # CC writes responses here
│       └── archive/             # Both archive completed work
```

### CLAUDE.md Required Sections

| Section | Purpose | Max Size |
|---------|---------|----------|
| Title + Description | What + tech stack | 1 line |
| Quick Reference | Build/test/deploy commands | Table |
| Key Files | Concept → file mapping | Table |
| Critical Rules | Things that break if ignored | Bullets |
| Architecture | ASCII diagram | 5-10 lines |
| Commands | /implement, /debug, etc. | Table |
| Context Files | Point to .claude/context/ | Table |
| PM GitHub Access | Owner, repo, branch | Table |
| Entity Info | Entity ID, broker URL | Table |

### Handoff System (PM ↔ CC)

**PM (Web Claude) writes tasks:**
```bash
# In project repo
.claude/handoff/todo/YYYYMMDD-HHMMSS-task-description.md
```

**CC (Claude Code) writes responses:**
```bash
# In project repo
.claude/handoff/complete/YYYYMMDD-HHMMSS-task-description.md
```

**Task Format:**
```markdown
# Task: [Brief description]

**Created:** YYYY-MM-DD HH:MM:SS
**Priority:** high|medium|low
**Type:** feature|bug|refactor|docs

## Context
Background information...

## Requirements
- Specific requirement 1
- Specific requirement 2

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

**Response Format:**
```markdown
# Response: [Task description]

**Completed:** YYYY-MM-DD HH:MM:SS
**Status:** success|partial|blocked

## Summary
What was done...

## Changes Made
- File 1: change description
- File 2: change description

## Testing
How it was verified...

## Notes
Any blockers or follow-up needed...
```

### Broker Registration

**CC entities register on startup:**
```bash
# Handled by .claude/hooks/prompt-submit.sh
curl -X POST http://localhost:9500/register \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "CC-projectname",
    "entity_type": "CC",
    "repo": "owner/repo-name",
    "directory": "/full/path/to/project"
  }'
```

**Check for tasks:**
```bash
# User runs: msg
# Hook fetches: http://localhost:9500/tasks/CC-projectname
# CC processes tasks from .claude/handoff/todo/
```

## Detailed References

- **[references/standards.md](references/standards.md)** - Complete PROJECT-STANDARDS.md rules
- **[references/handoff.md](references/handoff.md)** - PM↔CC coordination details
- **[references/templates.md](references/templates.md)** - Project templates and scaffolding
- **[references/broker.md](references/broker.md)** - Broker API and registration

## Key Commands

### Creating Projects

```bash
# As CC, user runs:
/new-project my-project signalk

# This creates:
# - GitHub repo (PRIVATE by default)
# - Local clone
# - Framework structure
# - CLAUDE.md from template
# - Initial commit
```

### Auditing Projects

```bash
# As PM (Web Claude):
# User asks: "audit this project against standards"

# PM fetches PROJECT-STANDARDS.md and checks:
# ✅ Private repo
# ✅ All required files exist
# ✅ CLAUDE.md size < 150 lines
# ✅ Handoff system configured
# ✅ Issues tracking roadmap
# ❌ Reports any violations
```

## Infrastructure Rules

**Authoritative:** [homelab STANDARDS.md](https://github.com/dougkimmerly/homelab/blob/main/STANDARDS.md)

### Compose File Location

| File Type | Location | Example |
|-----------|----------|---------|
| `compose.yaml` | Machine repo ONLY | `homelab-synology/service/` |
| `.env.example` | Machine repo | `homelab-synology/service/` |
| `Dockerfile` | Project repo | `project/Dockerfile` |
| Source code | Project repo | `project/src/` |

**Never put compose.yaml in project repos.**

### Machine Repos

| Machine | Repo | Compose Path |
|---------|------|--------------|
| Synology (.16) | `homelab-synology` | `/volume1/docker/homelab-synology/` |
| CasaOS (.19) | `homelab-casaos` | `/opt/homelab-casaos/` |

## Issue Tracking Standards

### Standard Labels

| Label | Use | Color |
|-------|-----|-------|
| `enhancement` | Roadmap features | `#a2eeef` |
| `bug` | Confirmed bugs | `#d73a4a` |
| `test-failure` | Test findings | `#fbca04` |
| `tech-debt` | Technical debt | `#d4c5f9` |
| `documentation` | Docs | `#0075ca` |

### Required Practices

- Roadmap items MUST be GitHub Issues
- Test failures → immediate issue creation
- PRs MUST reference issues: `Fixes #N` or `Relates to #N`
- Don't start work without tracking issue

## Key Documentation

| Resource | URL |
|----------|-----|
| Framework Repo | https://github.com/dougkimmerly/claude-project-framework |
| PROJECT-STANDARDS.md | https://github.com/dougkimmerly/claude-project-framework/blob/main/PROJECT-STANDARDS.md |
| Homelab Standards | https://github.com/dougkimmerly/homelab/blob/main/STANDARDS.md |
