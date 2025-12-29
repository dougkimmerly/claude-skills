# Standards Reference

Complete PROJECT-STANDARDS.md compliance guide.

## Self-Audit Checklist

### Repository
- [ ] Repo is PRIVATE (unless explicitly made public)
- [ ] `.gitignore` exists and excludes `.env`, `node_modules/`
- [ ] No secrets committed
- [ ] `README.md` exists

### Issue Tracking
- [ ] GitHub Issues enabled
- [ ] Roadmap items tracked as issues
- [ ] Test failures create issues with `test-failure` label
- [ ] PRs reference issues (`Fixes #N` or `Relates to #N`)
- [ ] Standard labels configured

### CLAUDE.md
- [ ] File exists at project root
- [ ] Under 150 lines / 4KB
- [ ] Has Quick Reference table
- [ ] Has Key Files table
- [ ] Has Critical Rules section
- [ ] Has Architecture diagram
- [ ] Has Commands table
- [ ] Has Context Files table
- [ ] Has PM GitHub Access table
- [ ] Has Entity Info table

### Framework Structure
- [ ] `.claude/commands/` directory exists
- [ ] `.claude/commands/implement.md` exists
- [ ] `.claude/commands/debug.md` exists
- [ ] `.claude/commands/review.md` exists
- [ ] `.claude/commands/test.md` exists
- [ ] `.claude/context/` directory exists
- [ ] `.claude/context/architecture.md` exists
- [ ] `.claude/context/domain.md` exists
- [ ] `.claude/context/patterns.md` exists

### Handoff System
- [ ] `.claude/handoff/` directory exists
- [ ] `.claude/handoff/todo/` directory exists
- [ ] `.claude/handoff/complete/` directory exists
- [ ] `.claude/handoff/archive/` directory exists

### Infrastructure (if applicable)
- [ ] `.claude/context/infrastructure.md` exists
- [ ] NO `compose.yaml` in project repo
- [ ] Compose file exists in machine repo
- [ ] CLAUDE.md Deployment section points to machine repo

## Common Violations and Fixes

### Missing Handoff System
**Problem:** No `.claude/handoff/` structure
**Impact:** CC can't communicate with PM
**Fix:**
```bash
mkdir -p .claude/handoff/{todo,complete,archive}
echo "# Task Queue\n\nPM writes tasks here as individual .md files." > .claude/handoff/todo/.gitkeep
echo "# Completed Tasks\n\nCC writes responses here." > .claude/handoff/complete/.gitkeep
echo "# Archived Tasks\n\nCompleted and archived tasks." > .claude/handoff/archive/.gitkeep
```

### Bloated CLAUDE.md
**Problem:** CLAUDE.md > 150 lines
**Impact:** Slow context loading every conversation
**Fix:** Move details to `.claude/context/` files:
- Architecture details → `architecture.md`
- Domain concepts → `domain.md`
- Code patterns → `patterns.md`
- Infrastructure → `infrastructure.md`

### Public Repository
**Problem:** Repo created as public by default
**Impact:** Violates private-by-default principle
**Fix:**
```bash
# Via GitHub web UI: Settings → Danger Zone → Change visibility → Private
# Or via gh CLI:
gh repo edit --visibility private
```

### Missing Issue Tracking
**Problem:** Roadmap in docs, not GitHub Issues
**Impact:** No single source of truth, hard to track progress
**Fix:**
1. Enable Issues on repo
2. Create labels: enhancement, bug, test-failure, tech-debt, documentation
3. Convert roadmap items to issues
4. Delete roadmap sections from docs

### Compose File in Project Repo
**Problem:** `compose.yaml` in project repo instead of machine repo
**Impact:** Violates infrastructure standards
**Fix:**
1. Move `compose.yaml` to machine repo (`homelab-synology/` or `homelab-casaos/`)
2. Update CLAUDE.md Deployment section to reference machine repo
3. Delete `compose.yaml` from project repo
4. Add to `.gitignore`: `compose.yaml`

## .gitignore Template

Required entries for all projects:

```gitignore
# Secrets - NEVER commit
.env
*.env
!.env.example

# Dependencies
node_modules/

# Build outputs
dist/
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store
```

## Test Failure Issue Template

When tests fail, create issue immediately:

```markdown
---
title: "[TEST] Brief description of failure"
labels: ["test-failure", "bug"]
---

## Test Failure

**Test:** `test_name` or test file path
**Date:** YYYY-MM-DD
**Commit:** SHA or branch

## Expected Behavior
What should happen

## Actual Behavior
What happened instead

## Logs/Output
```
Relevant output
```

## Reproduction Steps
1. Step one
2. Step two

## Initial Analysis
Root cause observations
```

## PM Audit Process

When PM audits a project:

1. **Fetch current state** via GitHub MCP:
   - `github:get_file_contents` for CLAUDE.md
   - `github:get_file_contents` for .gitignore
   - List `.claude/` structure
   - List `.claude/handoff/` structure
   - `github:list_issues` to check roadmap

2. **Compare against checklist** (above)

3. **Report findings:**
   ```markdown
   ## Project Audit: [name]

   **Date:** YYYY-MM-DD

   ### ✅ Compliant
   - Item 1
   - Item 2

   ### ❌ Non-Compliant
   | Issue | Impact | Remediation |
   |-------|--------|-------------|
   | X | Y | Z |

   ### 📝 Recommendations
   - Optional improvements
   ```

4. **Create remediation task** in `.claude/handoff/todo/` if needed

## Size Limits

| Metric | Target | Maximum | Reason |
|--------|--------|---------|---------|
| CLAUDE.md | ~100 lines | 150 lines | Loads every conversation |
| CLAUDE.md | ~3KB | 4KB | Context efficiency |
| Context files | ~50-100 lines | No hard limit | Loaded on-demand |

## Critical Rules

Things that WILL break if ignored:

1. **Never commit secrets** - `.env` files MUST be in `.gitignore`
2. **Private by default** - All repos PRIVATE unless explicitly public
3. **No compose in project** - Compose files ONLY in machine repos
4. **Handoff structure required** - PM and CC can't communicate without it
5. **Issues for roadmap** - Track all planned work in GitHub Issues
6. **CLAUDE.md must have Entity Info** - Broker can't route tasks without it
