---
name: review-suite
description: Tiered, multi-dimension code review, remediation, and ship-readiness auditing. Use when the user wants a code review, a quality/security/data-safety/design audit, a "is this ready to ship / release / hand off" check, to harden code before a release or migration, to FIX the findings, or to log an escaped/production bug for corrective action. On invoke it ESTABLISHES the review — scope (diff / subsystem / whole repo), level (L1 quick → L4 full ship audit), lenses (review types), and outcome mode (review-only vs review→fix) — runs it, adversarially verifies findings, produces a ranked punch list, and can continue into remediation (fix safe findings with a regression test + real-path verify each, hold the judgment calls). Includes an escaped-bug feedback loop and pairs with a rigorous testing pattern. Composes the built-in /code-review, /security-review, /verify plus a multi-agent adversarial workflow. Keywords: code review, audit, review level, fix, remediate, regression test, escaped bug, post-mortem, ship prep, release readiness, go/no-go, bulletproof, harden, pre-release, quality gate, definition of done, testing.
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
4. **OUTCOME mode** — **review-only** (produce the verified punch list; the human fixes) or
   **review → fix** (continue into remediation: auto-fix the safe findings, hold the judgment calls).
   See "Outcome & modes" below.

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
  accuracy** · **dependencies / supply-chain (CVEs, licenses)** · **accessibility / UX** ·
  **redundancy / duplication / dead-legacy** (two surfaces doing one job; a legacy control left in
  after its replacement shipped)

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

## Outcome & modes

The outcome is **never just a raw list**. Two modes, chosen at Step 0:

- **Review-only** — the deliverable is a **ranked, adversarially-verified, triaged** punch list:
  each finding is blocker→low, classified **fix-now vs hold**, carries a **file:line + failure
  scenario + fix direction**, and is **written into the project tracker** (ROADMAP / issues) so none
  are lost. The human does the fixing.
- **Review → fix** — the skill **continues into remediation** (below). The outcome is a *resolved
  state*: safe findings fixed + tested + verified, judgment calls held for the human.

## Remediation — continuing to the fix (the "review → fix" mode)

Triage every finding, then act:

1. **Classify:**
   - **fix-now** — mechanical, unambiguous, safe, testable (add a guard, atomic-write swap,
     off-by-one, a clear algorithm fix). Makes things *safer*, not riskier.
   - **hold** — needs a judgment/design call, or touches an **irreversible flow**
     (delete/migrate/sync) beyond a trivially-safe change. Surface with a recommendation; **never
     gamble on a destructive path unattended.**
2. **Fix each fix-now finding as its own unit:** make the change → **add/extend a regression test
   that FAILS before and PASSES after** → **verify on the real path** (drive the actual flow) →
   **commit** (one finding per commit, blocker / data-safety first).
3. **Re-verify:** L0 gates + the touched tests + the real flow. A fix isn't done until proven on
   reality (sandbox-green ≠ done).
4. **Track the holds** in the tracker with the fix direction, for a human decision.

This is exactly the loop that took the #49 audit to "9 fixed + 6 held." Run it autonomously (fix the
safe ones while the user's away) or stop at the list — the user picks at Step 0. Built-in
`/code-review --fix` and `/simplify` are the lightweight single-pass version (good for L1/L2); use
the full loop above for L3/L4.

## Feedback loop — when a bug escapes into the field

No review catches everything; the discipline is to **learn from every escape** so the same *class*
never ships twice. When a bug is found *after* shipping (a user report, a production incident), run
this intake — a **blameless post-mortem + corrective action** (invoke the skill with "log an escaped
bug"):

1. **Reproduce** it; write a **regression test that FAILS** on current code. This captures the bug
   permanently — it can never silently return.
2. **Fix** it → the test passes. Commit fix + test together.
3. **Root-cause the miss — which review LENS should have caught it?**
   - Lens exists but didn't fire → **strengthen it** (add the red flag / a real-data check) in
     `references/review-types.md`.
   - **No lens** covers this failure class → **add a new lens**.
   - A ship-gate gap → add a checklist item to `references/ship-readiness.md`.
4. **Commit the skill change** (`cd ~/.claude/skills && git add … && commit && push`).

Two durable memories come out of every escape: the **regression test** (memory for the *code*) and
the **new/strengthened lens** (memory for the *reviewer*). This ratchet is why mature codebases get
harder to break over time.

## Model & reasoning effort

A review is the **highest-stakes reasoning task** in the workflow — a missed data-safety bug ships.
Don't leave model/effort to session inheritance:

- **L3 / L4 reviewers and verifiers:** run on the **strongest reasoning model available** (Opus
  tier) at **high — or `max` ("ultrathink") for security- and data-safety-critical areas** —
  reasoning effort. In a multi-agent workflow, set `effort: 'high'` (or `'max'`) on the review +
  verify `agent()` calls, and **start the run from a session on the strong model** (agents inherit
  the orchestrator's model unless overridden).
- **L1 / L2:** the session's default model + effort is fine; bump effort for anything touching
  destructive flows or security.
- **Implementing mechanical fixes** (the remediation step for fix-now findings): a lighter/faster
  model is fine — the hard reasoning was the *finding*, not the one-line guard.
- Ultrathink is **not automatic** — you opt in per the above. Spend the tokens on review + verify;
  economize on mechanical fixes.

## Pairing with a rigorous testing pattern

Review and testing are **complementary layers, not substitutes**: review is judgment + discovery
(finds *new/unknown* defects); tests are the **durable, automated proof** that *known* behavior
stays correct. The rule that binds them: **every review finding and every escaped bug ends its life
as a test.** The full pattern — the testing pyramid, regression-first, real-path acceptance, the
runnable gate, and how it interlocks with this skill → **`references/testing-pattern.md`**.

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
