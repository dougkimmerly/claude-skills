# Ship-readiness — the go/no-go checklist

The release gate: what must be true before a change ships / a release cuts / a product hands off.
Adapted so it works whether or not you have CI, and for offline/handed-off products (no server to
watch). This is the industry "Definition of Done" + "release checklist" made concrete.

Run this at **L4**. Anything unchecked is a **no-go** or an explicitly-accepted, written-down risk.

## 1. Automated gates green
- [ ] Formatter / linter clean.
- [ ] Type-check / compile clean.
- [ ] Full test suite passes (not just the touched files).
- [ ] Build/package succeeds.
- [ ] **SAST (Semgrep) + dependency audit** clean, or findings triaged (`references/automated-analysis.md`).
- *(No CI? Run these by hand and record it. CI just automates this list on every push — "shift-left".)*

## 2. Review complete
- [ ] Deep review (L3) run over the change / codebase; findings **adversarially verified**.
- [ ] Every **blocker** and **data-safety** finding **fixed** and re-verified on the real path.
- [ ] Remaining findings **triaged and tracked** (in the ROADMAP/issues) — nothing silently dropped.
- [ ] Security review done for anything touching **auth, secrets, user input, network, file paths,
      or deserialization**.

## 3. Data-safety
- [ ] Every destructive path (delete/move/rename/migrate/sync) is **reversible or backed-up first**.
- [ ] Canonical files are written **atomically** (temp + rename), never truncate-in-place.
- [ ] Any data migration has been **tested on a copy of real data** and has a **rollback**.
- [ ] Originals are guarded — nothing mutates source data without a provenance check.

## 4. Real-path verification
- [ ] The change was **driven end-to-end on the actual target** — real data, real app, freshly
      restarted (a running server/app serves *old* code until restarted — "commit ≠ deploy").
- [ ] Not just sandbox/mock-green. Sandbox-green with a fixture shaped unlike real data is a common
      false pass — verify against the real thing.

## 5. Docs match reality
- [ ] User-facing docs / manuals / skills describe **what the app actually does now** (run the
      **doc-conformance audit**: code vs ADRs + manuals + skills + plans).
- [ ] A retired feature isn't still documented; a new feature isn't undocumented.
- [ ] ADRs record any architecturally-significant decision made in this change.

## 6. Rollback & blast-radius
- [ ] There is a **way to undo** this if it's wrong in the field (revert, restore, feature flag).
- [ ] Blast radius understood — what breaks if this is wrong, and who's affected.
- [ ] For risky changes: consider **staged rollout / canary / feature flag** rather than all-at-once.

## 7. Observability / can-we-tell-it-broke
- [ ] There's a way to **detect** a field failure (logs, a health signal, a support/diagnostics
      bundle, a user-visible status). You can't review your way to 100% — you also need to catch
      and fix what escapes.
- *(Offline/handoff product? The equivalents are a health strip, a support-bundle the user can send,
  and clear error copy that names the fix.)*

## 8. Handoff-specific (when shipping to another operator)
- [ ] The receiver can run it on **their** environment (no dependency on your machine/network).
- [ ] First-run / error copy / dead-ends are clean.
- [ ] A **dry run** on a second machine / fresh environment passed.
- [ ] The "how to get help" and "how to apply an update" paths work and are documented.

---

## The decision
State it explicitly: **GO** (all gates green or risks written-down-and-accepted) or **NO-GO** (name
the blocking gate). Don't ship on "probably fine" — either it meets the bar or the gap is a
consciously-accepted, recorded risk.

## Extending
When something breaks *after* a ship that this list didn't catch, add the gate that would have
caught it. The checklist is a living record of every way you've been burned.
