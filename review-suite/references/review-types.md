# Review types — the lenses, what each catches, how to run

Each lens finds a defect class the others structurally miss. Correctness alone (what most people
mean by "code review") leaves the other classes unexamined. Pick lenses by what the change touches.

For each: **what it catches**, **red flags to grep/look for**, **how to run it**.

---

## 1. Correctness & edge cases  *(always on)*
- **Catches:** wrong output, crashes, off-by-one, null/empty/boundary handling, wrong branch,
  race conditions, incorrect state transitions.
- **Red flags:** unhandled empty collection, loop variable used after the loop, integer vs float
  rounding, `==` on floats, missing `else`, TODO/FIXME, "can't happen" comments.
- **How:** read the logic against concrete inputs (empty, one, many, malformed, boundary). Reproduce
  the failure with a real input before reporting.
- **Cross-file / "seam" bugs (deep + whole-repo reviews):** a change can be locally correct but break
  a **caller**, a shared **contract/schema**, or an assumption **elsewhere in the codebase** — the
  highest-value bugs hide in the seams between files/services, invisible to a diff-only view (this is
  the measured edge of whole-codebase-indexing reviewers over diff-only ones). Trace each change to
  its callers and the contracts it must uphold; don't judge a diff in isolation.

## 2. Data-safety / destructive-op / migration  *(scrutinize hardest — irreversible)*
- **Catches:** deletes/moves/renames that can't be undone, non-atomic writes to canonical files
  (crash → corruption), migrations with no rollback, overwrites without collision handling, an
  "undo" that doesn't fully invert.
- **Red flags:** `rm`/`unlink`/`os.replace`/`rename`/`write_text` on canonical data without a
  temp+rename atomic pattern; delete-before-you-can-recompute; no backup before a rewrite; no
  provenance/guard before mutating an original.
- **How:** for every destructive path, ask "what if this is interrupted / the input is wrong / it
  runs twice." Require: atomic writes, backup-before-rewrite, idempotency, a reversible/undo path,
  and a guard that refuses to touch what it shouldn't.

## 3. Security  *(→ built-in `/security-review`)*
- **Catches:** injection (SQL/shell/path traversal), broken authz, exposed secrets, unsafe
  deserialization, SSRF, missing input validation at boundaries, supply-chain risk.
- **Red flags:** string-built SQL/shell, user input in file paths, secrets in code/logs/bundles,
  `eval`/`pickle`/`subprocess(shell=True)`, permissive CORS, auth checks client-side only.
- **How:** run `/security-review`; threat-model with STRIDE (Spoofing, Tampering, Repudiation, Info
  disclosure, DoS, Elevation). Validate only at system boundaries; trust internal calls.

## 4. Design & architecture conformance  *(code vs intent)*
- **Catches:** drift from accepted decisions (ADRs), violated invariants, an abstraction bypassed,
  a principle (offline-first, originals-sacred, one-home-per-knowledge) broken.
- **Red flags:** a call site that skips the module's own canonical helper; a request-time read of
  something that should be baked/cached; persisting a value the design says is volatile.
- **How:** read each accepted ADR / design doc, then check the code that governs it. When code and
  an *accepted* ADR disagree, it's usually a code bug (or a missing superseding ADR), not a doc fix.
  This is the lens the pure bug-hunt can't provide — pair it with the **doc-conformance audit**
  (code vs ADRs + manuals + skills + plans) at ship time.

## 5. Performance & efficiency
- **Catches:** O(n²) where O(n) is easy, N+1 queries, repeated work in a loop, unbounded memory,
  re-reading/re-serializing per item, blocking I/O on a hot path.
- **Red flags:** a scan inside a loop over the same collection, full re-serialization per element,
  missing index, `SELECT *` in a loop, re-observing/rewriting on every poll.
- **How:** find the hot paths and the largest realistic input; count the syscalls/queries per unit.
  Correctness first — don't report a micro-opt as a defect.

## 6. Resilience / failure-modes / offline degradation
- **Catches:** crashes/blank-states when a dependency is absent (network, drive, service), no
  graceful degradation, no retry/backoff, silent failure, partial-write on interrupt.
- **Red flags:** a feature that vanishes when its data source is unplugged instead of using a local
  cache; `except: pass`; no timeout on a network call; assuming a mount is present.
- **How:** run the flow with the dependency **removed** (drive unmounted, service down). It should
  degrade honestly ("connect the drive to play"), not disappear or crash.

## 7. Test coverage & quality
- **Catches:** untested branches, tests that assert nothing meaningful, tests that pass on a
  hand-built sandbox that wouldn't catch a real break (test-realism gap), missing regression for a
  fixed bug.
- **Red flags:** a test that mocks the very thing under test; fixtures shaped unlike real data; no
  test for the error path; coverage % as the only metric.
- **How:** for each risky change, ask "what test would fail if this broke?" — if none, that's the
  gap. Prefer real-data/real-path tests over mocks. Every fixed bug gets a regression test.

## 8. API / contract / backward-compat
- **Catches:** breaking a public signature/schema/format consumers depend on, silent behavior
  change, non-additive schema migration.
- **How:** diff the public surface; check every consumer; additive-only where others depend on it.

## 9. Readability / maintainability
- **Catches:** needless complexity, premature abstraction, dead code, misleading names, comments
  that narrate *what* instead of *why*.
- **How:** would a new maintainer understand this in 6 months? Prefer three clear lines to a clever
  one. (Built-in `/simplify` targets this class specifically.)

## 10. Docs & comments accuracy
- **Catches:** a manual/README/skill/comment that describes behavior the code no longer has — a
  handoff landmine for anyone following the docs.
- **How:** for user-facing products, verify each documented step against the running app. Fold into
  the ship-time doc-conformance audit.

## 11. Dependencies / supply-chain
- **Catches:** known-vuln versions (CVEs), abandoned/unmaintained deps, license incompatibility,
  transitive bloat, an unpinned version.
- **How:** run the ecosystem's audit tool (`npm audit`, `pip-audit`, `cargo audit`, Dependabot);
  pin versions; review any *new* dependency for necessity + provenance.

## 12. Accessibility / UX  *(user-facing changes)*
- **Catches:** keyboard traps, missing labels/alt text, contrast, dead-ends, confusing error copy.
- **How:** drive the UI; check against WCAG basics; read every error message as a new user.

## 13. Redundancy / duplication / dead-legacy  *(pairs with #4 design & #9 readability)*
- **Catches:** the **same function exposed twice** (two UI cards / buttons / pages / endpoints doing
  one job), a **legacy implementation left in place after its replacement shipped**, copy-pasted
  logic that has since drifted, duplicate routes/config, two sources of truth for one fact. This is
  the "we built the new one but never removed the old one" class — it accumulates silently and
  confuses users.
- **Example (real):** a ship's-log `/control` page showing **both** a new "Watch plan" card (W6) and
  the **old legacy "Watch rotation" card** — two controls for the same job; the legacy one should
  have been retired (or the two merged) when the new one landed.
- **Red flags:** two components with overlapping labels/purpose; a `vN` / `W6` / "new" feature sitting
  beside its predecessor; `_legacy` / `_old` / `_v1` names still wired into routes or nav; two
  endpoints returning the same data; the same render/logic block in ≥2 files; a feature flag
  permanently on with the old branch still present; a nav with two entries that land on the same task.
- **How:** for each **user-facing surface and each capability**, ask "does anything else already do
  this?" — map capability → implementation(s); where two serve one function, the superseded one
  should be **removed or merged** (this is "one home per knowledge" applied to code/UI). When a new
  version lands, **grep for the old one** (its name, route, component) and confirm it was retired.
  For logic, grep for duplicated blocks that should be one shared function. Flag each as
  **merge / remove-legacy / dedupe**, and name which of the two is the keeper.

---

## Extending this catalog
When a bug escapes review, identify which lens *should* have caught it. If none would, that's a new
lens — add it here with its catch/red-flags/how. That post-mortem → new-lens loop is how the review
gets sharper over time.
