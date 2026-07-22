---
name: review-suite
description: Tiered, multi-dimension code review and ship-readiness auditing. Use when the user wants a code review, a quality/security/data-safety/design audit, a "is this ready to ship / release / hand off" check, or to harden code before a release or migration. On invoke it ESTABLISHES the review — scope (diff / subsystem / whole repo), level (L1 quick → L4 full ship audit), and which review types (lenses) to run — then runs them, adversarially verifies findings, and produces a ranked punch list. Composes the built-in /code-review, /security-review, /verify plus a multi-agent adversarial workflow. Keywords: code review, audit, review level, ship prep, release readiness, go/no-go, bulletproof, harden, pre-release, quality gate, definition of done.
---

# Review Suite — tiered, multi-dimension review & ship-readiness

One skill for "review this / harden this / is this ready to ship." You pick **how much rigor**
(a level) and **which lenses** (review types); it runs them the right way, **adversarially
verifies** every finding against the real code + data, and hands back a **ranked, triaged punch
list**. Built from how real dev shops actually keep code bulletproof — automated gates, diff
review, deep audit, release checklist — not from one-size-fits-all.

## Step 0 — ESTABLISH the review first (always, with the user)

Never just start reviewing. Pin down three things — propose sensible defaults from the change's
risk, then confirm with the user in one line before running:

1. **SCOPE** — what's under review:
   | Scope | Use when |
   |---|---|
   | Working diff / a PR | reviewing a change in progress |
   | One subsystem / area | hardening a specific feature or risky module |
   | Whole codebase | pre-release / handoff / periodic deep audit |
2. **LEVEL** — how much rigor (the ladder below). Default from scope + risk; the user can dial up/down.
3. **TYPES** — which lenses (correctness is always in; add others by risk — see `references/review-types.md`).

Then **state the plan back** before running, e.g.:
> "L3 deep review of the *filing* subsystem — lenses: correctness + data-safety + design/ADR
> conformance — adversarially verified against the real index. ~N agents. Go?"

## The level ladder — the rigor dial

| Level | Trigger | What it runs | Method | Cost |
|---|---|---|---|---|
| **L0 — Automated gates** | ALWAYS, first | format · lint · type-check · build · existing tests | tooling, no agent | seconds |
| **L1 — Quick** | small / low-risk diff | `/code-review` single pass + run tests | one pass | minutes |
| **L2 — Standard** | a normal feature / PR | `/code-review` + `/verify` the flow + a security glance + test-coverage check | pass + real-path verify | ~10–20 min |
| **L3 — Deep** | risky / destructive / security-sensitive / core-path change | multi-dimension (correctness + data-safety + `/security-review` + design/ADR conformance + performance) with **adversarial verification**, against **real data** | multi-agent workflow (`references/multi-agent-workflow.md`) | ~20–40 min |
| **L4 — Ship / release-readiness** | before a release, handoff, or migration | L3 across the **whole codebase** + the **doc-conformance** audit (code vs ADRs/manuals/skills/plans) + the **ship-readiness checklist** | full audit + go/no-go | ~1 hr+ |

Always run **L0** before any higher level — a linter/type error wastes an agent's time. Each level
**includes** the ones below it.

## The two quality multipliers (what separates a real review from a glance)

1. **Adversarial verification.** Every finding gets an **independent skeptic** prompted to *refute*
   it — read the real code at the cited line, check the real data, default to "not a defect" unless
   it concretely reproduces. This kills plausible-but-wrong findings. For the highest stakes, use
   **≥3 skeptics with distinct lenses** (correctness / security / does-it-reproduce) and require a
   majority. **Do this on L2+ always** — it's the difference between a trustworthy list and noise.
2. **Real-path verification.** Drive the **actual** flow / app / data — not just tests, not just a
   reading. Sandbox-green ≠ done. (Built-in `/verify`; this is the industry's e2e/smoke-test
   discipline, and some repos bake it into acceptance scripts.)

## Review types (the lenses) — pick per risk

Correctness is always on. Add the rest by what the change touches. Full catalog + what each catches
+ how to run it → **`references/review-types.md`**.

- **correctness & edge cases** · **data-safety / destructive-op / migration** · **security**
  (→ `/security-review`) · **design & ADR/architecture conformance** · **performance & efficiency**
  · **resilience / failure-modes / offline degradation** · **test coverage & quality** ·
  **API / contract / backward-compat** · **readability / maintainability** · **docs & comments
  accuracy** · **dependencies / supply-chain (CVEs, licenses)** · **accessibility / UX**

## Methods (how the review is actually run)

- **Automated static analysis FIRST (shift-left).** Linters, type-checkers, formatters, SAST. The
  cheapest defects — never spend an agent on what a tool catches.
- **Diff single-pass** — `/code-review`, `/security-review` on the working change.
- **Whole-codebase multi-agent audit** — one reviewer per area, adversarially verified, synthesized
  into a ranked punch list. Recipe/template: **`references/multi-agent-workflow.md`**.
- **Real-path verify** — `/verify` drives the real flow.
- **Triage the output** — rank blocker→low; each finding carries **file:line + concrete failure
  scenario + fix direction**. Then split: **fix-now** (mechanical, safe, testable) vs **hold**
  (judgment / design / irreversible-flow) for the user. Never auto-"fix" a destructive-flow change
  on a guess.

## Output & follow-through

- A **ranked, verified punch list**, blocker / data-safety first, most-severe first.
- Each finding **classified** fix-now vs hold, with a one-line fix direction.
- If the project has a tracker (ROADMAP / issues / TODO), **write the findings there** as items so
  none are lost; if it doesn't, propose one.
- **Re-verify every fix on the real path** before calling it done.

## Ship-readiness (L4) — the go/no-go

The release gate. Full checklist (adapted for projects with/without CI, and for offline/handoff
products) → **`references/ship-readiness.md`**. Headline gates: automated gates green · deep review
clean or all findings triaged (blockers fixed) · destructive paths reversible/backed-up + rollback
plan · security review done for anything touching auth/secrets/input/network · **docs/manuals/skills
match shipped behavior** · **real end-to-end verification on the actual target** · a way to detect +
undo a failure in the field.

## How to improve this skill over time

This skill is meant to grow — that ratchet is itself a real-dev best practice:

- **Post-mortem → new check.** When a bug escapes a review, add the lens/checklist item that would
  have caught it (to `references/review-types.md` or `ship-readiness.md`). Highest-value habit here.
- **Tune the level defaults** and add **per-repo gates** (this repo's real commands, its acceptance
  pattern) as you learn your codebase's actual risks.
- **Add a new review type** when a whole failure *class* shows up that no existing lens covers.
- **Keep it diagnostic-first** — teach how to *find* defects (commands, lenses, verification), never
  a snapshot of current ones.
- Backed up in the `claude-skills` repo (ADR 0022): after editing, `cd ~/.claude/skills && git add
  review-suite && git commit && git push`.

## When to consult / invoke

- "Review this / do a code review / audit this / harden this."
- "Is this ready to ship / release / hand off?" → L4 + ship-readiness.
- Before a migration, release, or handoff → L4.
- A risky, destructive, or security-sensitive change → L3.
- An everyday feature/PR → L2. A tiny low-risk diff → L1.
