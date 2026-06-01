---
name: skills
description: How to decide where a skill lives, when to create or update one, and how skills are accessed. Use when creating a new skill, moving an existing one, reorganizing the skill layout, or deciding whether content belongs in a skill at all.
---

# Skill Organization

This is the meta-skill. It captures how skills are laid out, maintained, and discovered so the system stays simple as more accrete.

## The one rule

**Skills are auto-discovered by Claude Code.** You don't register them anywhere. The system-reminder listing at session start is the source of truth for what's available. Don't build indexes or registries — they duplicate SKILL.md metadata and drift.

## Two locations, one question

| Location | Loaded when |
|---|---|
| `~/.claude/skills/<name>/SKILL.md` | Every CC session on this machine |
| `<repo>/.claude/skills/<name>/SKILL.md` | Only when CC is run inside that repo |

**The question to answer:** does more than one project need this skill?

- **Yes** → universal. Put it in `~/.claude/skills/`.
- **No** → project-scoped. Put it in that repo's `.claude/skills/`.
- **Unsure** → start universal. Moving it to a project later is cheap; the reverse is a pain because multiple CC sessions may have come to rely on its being globally available.

## What belongs in each

**Universal (`~/.claude/skills/`)** — things any CC session might need:
- Operating principles (`adr`, `write-doc`, `knowledge-architecture`, this skill)
- Shared infrastructure skills (`netbox`, `bitwarden`, `health-monitor`, `robot`, `discovery`, `mbb300`, `imaging-expert`)

**Project-scoped** — things tied to one repo's schema, workflow, or code paths:
- Fixer owns `issue-review` and `issues` because they're specifically about the `fixer.*` Postgres schema.

The test: if the skill would become wrong the moment someone opened it from a different project, it's project-scoped. If it'd still be correct, it's universal.

## When to create, update, or skip

After non-trivial work, ask three questions (from `~/.claude/CLAUDE.md`):

1. **Did a skill help me?** If something was stale or missing, update it now, in the same session.
2. **Was this a new-enough pattern?** Create a skill only if the knowledge is reusable across future sessions. A one-off fix with a good commit message is enough.
3. **Did the world change?** Update skills that describe the world (architecture, commands, where things live).

**Don't create a skill for:**
- Content that's already in code — read the code.
- Facts that change without anyone editing the skill — that's state, not skill content. Teach how to *query* it, not what the answer is right now.
- Trivia with no reuse potential — a commit message is cheaper and decays gracefully.

## File structure

```
skill-name/
├── SKILL.md              # Required. Triggers, diagnostics, action-first.
└── references/           # Optional. Deeper detail the SKILL.md points to.
    └── *.md
```

Frontmatter:
```yaml
---
name: skill-name
description: One line. This is what CC sees when deciding whether to invoke the skill — make it specific and keyword-rich.
---
```

The description is load-bearing. When another CC is asked to "fix the scheduler," the word `scheduler` in the `robot` skill's description is what makes it discoverable. Update the description first when scope changes.

## Maintenance

- **Edit SKILL.md in its home directory.** Never maintain a second copy "to keep in sync" — you will forget. If the skill is needed in two places, it's universal: move it to `~/.claude/skills/`.
- **Don't list skills in CLAUDE.md by file path.** They auto-appear in the session listing. CLAUDE.md can *mention* which skills exist and whether they're project-scoped vs universal, but hard-coded `.claude/skills/X/SKILL.md` paths break the moment a skill moves.
- **Don't restate SKILL.md content in CLAUDE.md or runbooks.** Point at the skill by name; trust CC will load it.

## Moving a skill

```bash
# Universal → project
mv ~/.claude/skills/X <repo>/.claude/skills/X

# Project → universal
mv <repo>/.claude/skills/X ~/.claude/skills/X

# Commit in the affected repo if moving from a tracked location.
```

No registry to update. New location shows up in the next session's reminder.

## Optional: version-controlling `~/.claude/skills/`

Nothing stops you:
```bash
cd ~/.claude/skills && git init && git remote add origin <repo>
```

No other tool assumes the directory is versioned. Start simple; add a repo only when you've felt the pain of losing a skill edit or want to share across machines.

A previous attempt (`claude-skills` as a shared repo for marine-domain skills) ended up archived because maintaining separate clones and sync rules became its own overhead. The current layout is deliberately flatter.

## Anti-patterns

- **Top-level skill registry/index.** Duplicates SKILL.md metadata, drifts, adds nothing the auto-listing doesn't already do.
- **Two copies kept in sync by hand.** If you've written a "keep these in sync" rule, that's a smell. Make the skill universal, not synced.
- **Deeply nested domain-expert skills.** If most skills in a shared repo are "expert on X domain," that content is probably reference material for a specific project, not a reusable skill. Put it in the project's docs.
- **Skills that hardcode state.** "The health check runs on port 8400" will be wrong someday. A skill teaches *how to find out* — diagnostics, commands, authoritative sources — not the current answer. See `write-doc`.

## When to consult this skill

- Creating a new skill: run through "what belongs in each" before picking a location.
- Another CC can't find a skill that exists: the skill probably isn't loaded in their working directory — it should be universal.
- Deciding whether to capture something you learned: run through "when to create, update, or skip."
- Noticing duplicate content across SKILL.md + CLAUDE.md + runbook: the skill is the source of truth; prune the others.
