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
- Shared infrastructure skills (`netbox`, `robot`, `health-monitor`, `discovery`, `secrets`, `imaging-expert`, `postgres-replication`)

**Project-scoped** — things tied to one repo's schema, workflow, or code paths:
- Fixer owns `issue-review` and `issues` because they're specifically about the `fixer.*` Postgres schema.

The test: if the skill would become wrong the moment someone opened it from a different project, it's project-scoped. If it'd still be correct, it's universal.

## How a universal skill is physically exposed

A universal skill reaches `~/.claude/skills/` in one of two physical forms. Choose by asking *does a repo own this skill?*

| Form | When | Backed up by |
|---|---|---|
| **Real file** under `~/.claude/skills/<name>/` | the skill has **no owning repo** — cross-cutting know-how (`adr`, `write-doc`, `knowledge-architecture`, `skills`, `netbox`, `secrets`, `robot`, `health-monitor`, `tailscale`, …) | `claude-skills` (commit it — ADR 0022) |
| **Symlink** `~/.claude/skills/<name>` → `<repo>/.claude/skills/<x>` | the skill is **owned by a repo** (ships with that code) but is broadly useful enough to load everywhere | the **owning repo** |

**Never expose a repo-owned skill by copying it.** A copy drifts the instant either side is edited. The 2026-06-26 audit found nine `homelab-*` real-dir copies that had silently diverged from the homelab repo (the repo had grown `references/`, `config/`, and setup docs the copies never received). All were converted to symlinks. The rule: **if a skill has a repo home, symlink it — never `cp`.**

**Symlink the whole skill _directory_**, not just `SKILL.md` — that carries any `references/`, `config/`, or backup files along (e.g. `homelab-centralsk` ships five reference docs).

### Naming / prefix rule

The exposed name = the symlink's directory name. (Skills with no `name:` frontmatter are named after their directory; an explicit `name:` must match it.)

- Skills from the **multi-skill `homelab` repo** get a **`homelab-` prefix** (`homelab-centralsk`, `homelab-dk400`, `homelab-c4`, `homelab-rogers-gateway`, …) — their bare names (`centralsk`, `dk400`, `c4`, `synology`) are generic and would collide.
- Single-skill repos and already-distinct names need **no prefix** (`hardware-roadmap`, `voice-assistant`, `central-signalk`).
- Real-file universals keep their own distinct name (`tailscale`, `netbox`, `secrets`).

### Same name, two skills — deliberate, not drift

A universal real-file skill and a project-scoped skill may share a name *on purpose*, at different altitudes. Keep them cross-referenced so they don't silently diverge:

- **`tailscale`** — universal real file = the deep cross-site failure-mode reference; `homelab/tailscale` = a thin `context: fork` operational pointer that links back to it.
- **`central-signalk`** — universal real file = cross-site SK *diagnostic* entry-point; `cruising-app/central-signalk` = the full vessel *install* reference. Each points at the other.

This is not a copy. A copy is identical content in two places (forbidden); these are distinct-altitude docs that reference each other (fine).

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

## Version control & backup (ADR 0022)

`~/.claude/skills` **is** a git repo: `git@github.com:dougkimmerly/claude-skills.git`, with a gitleaks pre-commit hook. It is a **single-machine backup of real-file universal skills** — not a shared library synced across clones. Two-tier model:

| Skill form | Backed up by | Commit where |
|---|---|---|
| **Real file** under `~/.claude/skills/` (e.g. `adr`, `netbox`, `lightroom`) | `claude-skills` | `cd ~/.claude/skills && git add … && commit && push` |
| **Symlink** into a project repo (`homelab-*`) | the **project repo** that owns the real file | commit in that project repo (git stores only the symlink here, not the target) |
| **Project-scoped** (`<repo>/.claude/skills/`) | its own repo | that repo |

- **Edit the real target, not the symlink** — and commit in *that file's* home repo. Committing a symlinked skill's change to `claude-skills` backs up nothing (only the link is tracked).
- **After authoring a new real-file universal skill, commit it.** `claude-skills` only protects what's committed; an authored-but-uncommitted skill lives on one SSD with no backup (this is how the `lightroom` skill went unprotected — see ADR 0022).
- **Never embed secrets** — the gitleaks hook will block the commit; point at SOPS (`secrets` skill) instead.

> This is deliberately *not* the archived round-one `claude-skills` (a shared marine-domain "expert skills" repo, abandoned for its clone/sync overhead). The current repo is a thin one-push backup mirror — no sync rules. ADR `fixer/docs/decisions/0022-version-control-claude-skills.md` records the full rationale.

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
