---
name: adr
description: Record an Architectural Decision Record. Use when the user wants to document why a significant design or architectural choice was made — phrases like "write an ADR", "document this decision", "record the decision to...", "add a decision record", "capture why we chose X". Produces a numbered, dated markdown file following a consistent minimal template. Do NOT use for trivial choices, style preferences, or reversible refactors.
---

# ADR — Architectural Decision Record

## When to write one

Write an ADR when a choice is:
- **Architecturally significant** — changes how parts of the system fit together, or commits to an approach expensive to reverse.
- **Non-obvious** — the reason for choosing A over B isn't self-evident from the code alone.
- **Future-you-will-ask** — six months from now, someone will wonder why.

Do NOT write an ADR for:
- Style or naming preferences.
- Small reversible refactors.
- Choices fully captured by a well-written code comment.
- "We used X because that's what the team uses."

**Rough test:** if a reasonable engineer might in good faith reverse this decision without the context you have, write the ADR.

## Where ADRs live

`<project-root>/docs/decisions/NNNN-kebab-title.md`

- `NNNN` — zero-padded monotonically increasing number (`0001`, `0002`, `0013`). Never reused, never reordered.
- `kebab-title` — short slug (`db-replication-strategy`, `auth-provider-choice`).
- One decision per file.
- Create `docs/decisions/` if it doesn't exist.

ADRs that span repos (a decision about how repo A and repo B relate) live in whichever repo most naturally owns the decision — usually the one doing the orchestration, not the ones being orchestrated.

## Template

```markdown
# NNNN — <Short title>

- **Status:** Proposed | Accepted | Superseded by NNNN | Deprecated
- **Date:** YYYY-MM-DD
- **Supersedes:** NNNN  (omit if none)
- **Related:** NNNN, NNNN  (omit if none)

## Context

What forced this decision? State the problem before the answer. Include the constraints, goals, and tradeoffs in play. Be honest about unknowns.

## Decision

What did we choose? One sentence of plain language, then whatever structured elaboration an implementer would need to act from this.

## Consequences

What becomes true as a result? Include both:
- **Positive** — what this unlocks or makes easier.
- **Negative** — what we give up, what this forces us into later, what new problems it creates.

If the negatives require future work, name it plainly.

## Alternatives considered  (optional)

If there were serious contenders, list them briefly with why each was rejected. Omit when the decision is obvious given the context.
```

## Status lifecycle

- **Proposed** — drafted, not yet committed to. Open for discussion.
- **Accepted** — decision is current.
- **Superseded by NNNN** — a later ADR replaces this one. The later ADR MUST state `Supersedes: <this-number>`.
- **Deprecated** — no longer relevant, with no replacement.

**Accepted ADRs are effectively immutable.** Edit only for clarity: typo fixes, broken-link repairs, wording improvements. A change of direction is *always* a new ADR that supersedes the old one. This preserves the historical record of what was decided when.

## Cross-linking

When this ADR replaces an earlier one:
1. Put `Supersedes: 00NN` in this ADR's frontmatter.
2. Edit the earlier ADR's status to `Superseded by <this-number>`.
3. Leave the earlier ADR's body intact.

When this ADR relates to others without replacing them, list them in `Related:`.

## Process

1. **Claim the number** — `ls docs/decisions/` and take the highest `+ 1`. Zero-pad to four digits.
2. **Create the file** with status `Proposed`.
3. **Draft context and decision** together — context must justify the decision, not rationalize it after the fact.
4. **Confirm with the user** before setting status to `Accepted`. ADRs are decisions *together*, not a unilateral log.
5. **Commit** with message `ADR NNNN: <title>`. ADRs are part of the code's history.

## Common mistakes

- **Stating the decision without context.** "We chose Postgres" is useless in two years without "because of <the specific reason>."
- **Making consequences too positive.** Every decision has downsides. Omitting them signals the decision wasn't scrutinized.
- **Using an ADR for an implementation plan.** ADRs capture direction, not the steps to get there. Implementation belongs in tickets or runbooks.
- **Silently editing an Accepted ADR to reflect a later change.** That erases history. Supersede instead.
