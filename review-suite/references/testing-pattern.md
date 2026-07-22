# Testing pattern — the durable safety net, and how it pairs with review

Review *finds* defects; tests *keep them dead*. This is the rigorous testing setup review-suite
assumes and feeds.

## The core relationship
- **Review** = discovery + judgment — finds **new/unknown** defects, once.
- **Tests** = durable automated proof — that **known** behavior stays correct, forever, on every change.
- **The binding rule:** *every review finding and every escaped bug ends its life as a test.* A fix
  without a regression test is a bug scheduled to return.

## The testing pyramid (shape of a healthy suite)
- **Many fast UNIT tests** — a function/module in isolation, milliseconds, run constantly.
- **Fewer INTEGRATION tests** — modules together with real DB/files, seconds.
- **Few E2E / ACCEPTANCE tests** — the whole system on real data + the real flow; slow, highest confidence.
- Push each test **as low as it can go while still being meaningful.** Anti-patterns: the "ice-cream
  cone" (mostly slow e2e, few units) and the all-mocks suite (green but proves nothing).

## Test-first / regression-first
- **Fixing a bug:** write the **failing** test FIRST (red) → fix (green). This proves the test
  actually catches the bug *and* the fix works. Never skip it.
- **Building a feature (TDD):** write the test for the wanted behavior → watch it fail → implement →
  pass → refactor.
- Even without strict TDD, **every fixed bug ships with its regression test.**

## Real-path / acceptance tests (the highest-confidence layer)
- Drive the **real system with real-shaped data** — never mock the thing under test.
- **Sandbox-green with a fixture shaped unlike real data is a false pass** (the classic escape — a
  test built a db with columns the real indexer never creates, so a real break shipped green).
- Restart long-lived servers/apps before verifying — **commit ≠ deploy**; a running process serves
  old code until restarted.
- *(This repo's incarnation: `accept_*.py` scripts that spin the real server / run the real indexer /
  use the real drive or fixture. Those ARE the acceptance layer and the ship gate.)*

## Test QUALITY over coverage %
- Coverage tells you what **ran**, not what's **checked**. A test that asserts nothing has 100%
  coverage and zero value.
- **The test for a test:** would it FAIL if the behavior broke? If not, delete or fix it.
- Don't mock the unit under test. Shape fixtures like real data. Test the **error path**, not just
  the happy path.

## The runnable gate (make it one command)
- **One command runs the whole suite.** That command is your **L0 gate** and your **ship gate**.
- Run it on **every change** (pre-commit hook), in **CI on every push** (shift-left), and **before
  every ship**.
- **No CI infra** (e.g. an offline / handed-off product)? A pre-commit hook + "run the suite by hand
  and record it" is the gate; the acceptance scripts are the proof.

## The regression corpus (the codebase's memory)
- Every fixed bug + every escaped bug → a **permanent test named for what it guards**.
- The suite becomes the accumulated memory of every way the code has been broken. **Never delete a
  regression test** because it's "old."

## Specialized tools (add by need)
- **Property-based / fuzz** for parsing / input-heavy code — generates edge cases you'd never list.
- **Characterization tests** for legacy/untested code — pin **current** behavior first, *then*
  refactor safely (a net under code you don't fully understand).
- **Contract tests** for APIs/schemas consumers depend on. **Snapshot tests** for structured output
  (with care — they rot if blindly re-baselined).

## How it interlocks with review-suite
- **Lens #7 (test coverage & quality)** checks tests exist and are *real*.
- **Remediation (review→fix):** every fix-now finding gets a regression test (red→green) before commit.
- **Feedback loop (escaped bug):** step 1 *is* writing the failing regression test.
- **Ship-readiness:** gate #1 = full suite green; gate #4 = real-path verification.
- So review **continuously feeds** the suite — findings and escapes both become tests. Over time the
  automated net catches the known classes, freeing review to hunt the *new* ones. That shift is the
  goal: a codebase that gets **harder to break** with every pass.

## Setting this up in a new repo (mini-checklist)
- [ ] A test runner + **one command** to run all tests.
- [ ] A **pre-commit hook** (or CI) that runs it on every change.
- [ ] **Linter + type-checker + formatter** in the same gate.
- [ ] At least one **real-path/acceptance test per critical flow**.
- [ ] A standing convention: **every bug fix ships with a regression test**.
- [ ] (If applicable) a **dependency-audit** tool in the gate.
