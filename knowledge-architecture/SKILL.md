---
name: knowledge-architecture
description: Deep reference on the four homes of knowledge — living, state, reference, experiential — and how they relate. Use when the user asks where information should live, how to organize documentation, how to resolve a conflict between two docs, or wants to understand knowledge-architecture principles in depth. Consult this when `write-doc`'s decision tree doesn't give a clear answer, or when thinking about cross-home relationships.
---

# Knowledge Architecture — the four homes in depth

All knowledge this system handles falls into one of four homes. Each has a different rate of change, a different authoritative source, and a different consumption pattern. Placing knowledge in the wrong home is the primary cause of documentation rot.

## The homes

### 1. Living knowledge

**What it is:** Configuration, architecture, design rationale, runbooks, READMEs — anything that evolves alongside the code or infrastructure it describes.

**Where:** Co-located in git with what it documents. If the doc describes a deployment, it lives in the deployment's repo. If it describes a service, the service's repo. Co-location means a change to reality and its doc ship in the same commit.

**How it stays true:** Code review. When a PR changes a file, reviewers check whether its doc needs updating. This is a *cultural* defense, not a technical one, and it's the weakest link — most stale docs are docs no reviewer thought to update.

**Good signs:** Last-modified dates track code changes. Descriptions are of *shape* (how things fit together) rather than *state* (what's running where). Links out to dashboards rather than copying values.

**Bad signs:** "As of <date>…" phrases. Specific hostnames, IPs, ports, versions in prose. Claims about "current" anything. Long sections that duplicate what's in another doc.

### 2. State

**What it is:** The current value of a fact. What's running, where, at what version, with what health, when it last ran, who's on call.

**Where:** Nowhere written. Query the authoritative system. If an inventory database knows where a service runs, that is the only source of truth — any document that repeats the fact is a copy that will drift.

**How it stays true:** It is the authoritative system by definition. The discipline is ensuring every state category has a clear authoritative source and a query or dashboard path to it.

**Typical authoritative sources:**
- Inventory DB — what exists, where, ownership, relationships.
- Orchestrator (container runtime, Kubernetes, systemd) — what's actually running now.
- Application state (job scheduler tables, issue trackers) — what's scheduled, what ran, what's next.
- Health monitoring — what's healthy, what's degraded.

**Anti-pattern:** Writing "the auth container runs on host `foo` at `10.0.0.1` port `443`." This is four state facts — all queryable. Writing them down commits you to updating this sentence whenever any of them changes. You will forget.

**The only acceptable doc mention of state is a pointer:** "See [inventory entry](link) for current details."

### 3. Reference

**What it is:** Stable information with long shelf life. Manuals, datasheets, purchase records, signed paperwork, photos, specifications. Doesn't change — or if a revision is issued, old and new both remain.

**Where:** A document store with tagging and search. Attached to the relevant entity in inventory where that helps discovery.

**How it stays true:** It's stable, so mostly "don't edit." If a manual revision is issued, add the new revision as a new document; don't overwrite.

**Boundary case — summaries of reference material:** Docs that *summarize* reference material ("here's what the manual says to do for X") are NOT reference. They're living (if they inform operations) or experiential (if they capture a judgment call about which parts matter).

**Critical rule:** *Reference stores ingest; they don't originate.* A living doc authored directly into a reference store has no git history, no review, no version control. It becomes orphan knowledge. Living docs must be born in git.

### 4. Experiential

**What it is:** The *why* behind decisions, rejected alternatives, lessons learned, tacit knowledge from working on the system. The hardest kind to capture because it has no natural home with the code or the state.

**Where:** Three sub-homes:
- **ADRs** for significant decisions — `docs/decisions/NNNN-title.md`. Use the `adr` skill.
- **Skills** for reusable operational know-how — `.claude/skills/NAME/SKILL.md`. Diagnostic-first, action-oriented. Universal skills in `~/.claude/skills/`; project-specific skills in `<project>/.claude/skills/`.
- **Memory** for session-to-session context about user preferences, ongoing projects, and feedback.

**How it stays true:** ADRs are immutable after acceptance; new ADRs supersede old ones. Skills are updated after every task touching their domain. Memory is verified against current state before use.

**The failure mode:** Experiential knowledge never captured. Happens when a task finishes and nobody pauses to ask "did I learn something that should persist?" The skill-maintenance habit guards this.

## How the homes relate

Every home connects; none repeat.

- An **ADR** captures the *why* for a decision. The **living doc** captures what the decision looks like in the code. The **state** reflects what's currently deployed as a result. All three exist; each points at the others where useful.

- A **reference** manual for a piece of equipment is linked from the **living** runbook for that equipment and surfaced on the **state** dashboard when the equipment is in an alarm condition.

- A **skill** that teaches how to investigate issue X references the **living** runbook for the affected service rather than duplicating its diagnostic steps. Skills teach the *approach*; runbooks are the reusable artifact.

- A **living** doc describing a replication strategy links to the **ADR** that chose that strategy. The ADR is the *why*; the living doc is the *how it works in practice*.

## Judgment calls

Most placements are clear. A few are not.

**"How do I set up X?"** — Depends on X. If X is code in your repo, setup is a living README. If X is external equipment, setup has two parts: the scanned quick-start (reference) and the operational steps (living runbook).

**Architecture diagrams** — Living. Describe shape, not state. Keep in git even when they're images; store the source file (`.drawio`, mermaid text) not just the render.

**"Why did we do X?"** — Experiential (ADR) if significant enough that someone might reverse it without your context. Living doc (comment or short section) if minor.

**"Who owns X?"** — State. Inventory should answer. Do not write "X is owned by Y" in a doc.

**"What version is X running?"** — State. Never write this in prose.

**Post-incident writeups** — Experiential. Capture the lessons as an ADR or skill update. The symptom-and-fix belongs in the issue tracker (state), not a prose doc.

**Onboarding guides** — Mix. What-to-read-and-in-what-order is living. "Here's the current state of the project" is state and should link rather than copy. "Here's why we organize things this way" is experiential and should link to ADRs.

## The enforcement gap

These principles stay true only with discipline — yours during authoring, the review process during PRs, and eventually a mechanical audit that scans docs for state-shaped content (embedded IPs, hostnames, ports, versions) and flags drift.

Until that audit exists, the only guardrail is asking the question *every* time before writing. This is what the `write-doc` skill exists to force.

## Physical placement: repos, skills, tools, and cross-cutting coupling

The four homes say *what kind* of knowledge something is; this says *which artifact* holds it and how artifacts that span homes interact. Full decision: **dkSRC workshop ADR 0040** (`~/Programming/dkSRC/docs/decisions/0040`). The gist:

- **Three units, one job each.** A **repo** owns a *thing* (code, schema, deployment, its ADRs — living knowledge). A **skill** owns the *know-how to operate a thing* (experiential). A **tool** is code in a repo that does the work. "Repo or skill?" is a false choice — most systems need both.
- **Earns its own repo** if it has *independent deployment*, *distinct authority + data-model*, or an *isolation boundary* (PII/security). Otherwise it's a feature of an existing repo. A capability housed in a repo whose *domain it doesn't share* is mis-homed (e.g. a data discipline inside an ops repo).
- **Skill placement:** default project-scoped (co-versioned, ships in the PR); go global (`~/.claude/skills`) only when operated from outside its repo or it's a cross-cutting discipline.
- **Cross-cutting concerns — prefer the loosest coupling that works:** **Contract** (a documented rule/schema each side implements; no shared code — e.g. a sensitivity policy, a filing taxonomy) → **Substrate** (a shared service/DB via API/schema convention) → **Library** (imported code; only when a second consumer needs the logic, not just the rule). Tighten only when the looser layer demonstrably fails. **A global skill + an ADR is how you hold a contract without code coupling.**
