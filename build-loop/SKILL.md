---
name: build-loop
description: Run a milestone of standards-bearing coding as an unattended overnight batchq drain — plan → adversarial plan review → decomposition into paired small-context BUILD/REVIEW jobs → staged specs + one fire script → autonomous fix loop + bounded hold recovery → self-gating CLOSE that drafts (and adversarially reviews) the NEXT milestone's plan, stopping at a morning human merge session. Use when Doug says "run it overnight", "set up a build loop", "make it build itself", or when any multi-job build should verify against ADRs/specs without a human in the loop. Reference instance: ~/Programming/dkSRC/dk-w5 (docs/BUILD-LOOP.md + jobs-staged/) — first pilot fired 2026-08-09. NOT for one-off fixes or single jobs (plain sbmjob covers those); the chassis is the batchq skill.
---

# Build loop — unattended milestone coding with adversarial review at every link

Adapted from the Finn-loop shape (spec-as-contract → build → independent review →
human gate) onto batchq. **Reference instance: `~/Programming/dkSRC/dk-w5`** —
`docs/BUILD-LOOP.md` (conventions), `jobs-staged/` (spec templates, fire.sh,
hold-recovery prompt), `docs/plan-review.md` (plan-review method), 
`docs/CLAUSE-COVERAGE.md` (scoreboard shape). Copy from there; don't reinvent.

## The pipeline (each stage adversarially reviewed before the next)

1. **Plan** (interactive, strong model): Goal + explicit definition-of-done as a
   client call sequence + forcing-test exit checklist + components + Explicitly-OUT
   + decomposition table. Where the plan compresses a spec/ADR, QUOTE it — lossy
   paraphrase was the pilot's worst defect class.
2. **Adversarial plan review** (fresh session/job — author ≠ reviewer, always):
   four lenses (spec-conformance, evidence, estate-reality, sequencing/scope),
   hostile verifiers with stated strongest refutations. Author applies findings.
3. **Decompose into paired jobs**, staged in-repo (`jobs-staged/`), submitted by
   one `fire.sh`: per slice a BUILD job + a REVIEW job (parametrized template,
   instantiated at fire time). Specs written up front, blind — inter-slice
   contracts come from the plan, not from seeing prior output.
4. **Drain unattended.** Worker merges green builds (no human merge gate); each
   REVIEW audits the merged diff against the build's AC/NG/claimed clauses, runs
   the tests itself, and closes its own fix loop (writes fix pairs into the queue
   dir; cap 2 rounds, then HANDOFF + drain continues — fix-forward).
5. **CLOSE job** gates the milestone (all verdicts approved + forcing tests green
   + scoreboard reconciled). **Gate-and-remediate:** on INCOMPLETE with a
   mechanically actionable blocker (a job that exited without its contracted
   artifact → resubmit its spec with the hardened foreground warning; a diagnosed
   defect CLOSE can spec with concrete AC → author the scoped fix pair), CLOSE
   submits the jobs itself and re-drops its own max-stamp hold — budget max 3
   gate passes (`gate.count`, reset by fire.sh); anything it can't spec, or at
   cap → honest report + HANDOFF + stop. On COMPLETE → report + retro → chains
   the NEXT milestone's planning job AND its adversarial plan-review job, stops.
6. **Morning merge session** (interactive): human + strong model merge plan +
   review, decompose, fire the next milestone. One human session per milestone.

## Paid-for rules (each earned on the pilot; keep them)

- **Small jobs:** every job < ~100k-token fresh context; the spec ENUMERATES its
  exact read-set ("read the repo" is a spec defect); one component slice per job;
  decomposition is the submitting session's work — strong model writes rich specs,
  jobs execute cold on the queue default (sonnet).
- **Contract compilation:** never make jobs re-read the corpus. ADR/spec clauses →
  clause-tagged conformance tests (`test_0006_opaque_ids…`) + a CLAUSE-COVERAGE
  scoreboard (promotion only via that file, citing the test run). The research/
  evidence base is the REVIEWER's appellate court only.
- **Model tiering:** builds/reviews = queue default (sonnet); planning-grade jobs
  (CLOSE, M-plan, plan-review) = opus via the queue `model` file — the job's FIRST
  act deletes it so nothing inherits. Never fable on a queue.
- **Network prep:** batch guardrails block downloads — pre-pull pinned docker
  images from an interactive session and add a SCOPED tail.md exception
  (spec-pinned pulls/installs only). Decouple real secrets from the overnight path
  (throwaway env proves every clause; real deploy is a morning step).
## Error handling — the loop is a program; every anticipated failure gets a handler

The single biggest lesson (2026-08-10, a milestone that needed heavy manual
recovery): **treat the build loop like production code.** A human should be paged
only for the *genuinely unanticipated*; every known failure mode has an automated
handler. Design these in from the start:

**Prevent the mechanical class (so holds are rare):**
- **Commit LAST, not first.** The worker only sees exit-code + worktree-cleanliness,
  never test results. So: commit early to preserve progress → run the full suite →
  if GREEN, a FINAL `git add -A && commit` to capture anything the suite regenerated
  (mirrors, coverage) → clean tree merges. If RED, leave the tree dirty and name the
  failing test — do NOT leave a clean tree (that merges broken code into main and
  cascades into later slices). Committing *first* then running a suite that
  regenerates a tracked file is the #1 cause of false dirty-worktree holds (hit K6
  and K8).
- **Generated files checked into git churn the worktree.** Any suite that
  regenerates a committed artifact (a flat mirror, an index) must restore it —
  `trap 'git checkout -- <generated-paths>' EXIT` in the test runner so a *failed*
  suite still restores. Or don't commit generated files at all.
- **Hardened foreground rule in review specs** (backgrounding a slow suite + waiting
  for a notification that batch jobs never get killed two reviews). "THIS KILLED
  PREDECESSORS" phrasing, not a soft note.

**Auto-recover the rest (the error-handler watchdog):** a systemd `.path` unit on
`held/`+`MSGW` fires a headless **sonnet** agent that is a full CLASSIFIER, not a
one-trick preserver (`jobs-staged/hold-recovery-prompt.md` is the reference):
- **A. Transient** (API/network/timeout, no real work) → release (retry).
- **B. Dirty worktree, work complete** → run the suite foreground; GREEN → commit +
  merge + release (slice saved); RED → case C.
- **C. Real test failure** → commit work to branch, auto-author a FIX build+review
  pair (original spec + the failing test as added AC), supersede the original,
  release. **Test failures become fix-jobs automatically — no human.**
- **D. Review died without a verdict** → resubmit it with the hardened template.
- **E. Merge conflict** → trivial → merge; real → case F.
- **F. Unknown / unsafe / per-job budget exhausted** → fixer issue + HANDOFF + ntfy.
  **The only path to a human.**
Per-JOB budget (≤2 remediations/job, then escalate), not a global nightly cap.

**The error-handler needs its own error handling.** It died mid-K8 on systemd
`start-limit-hit` — a persistent hold kept the `held/` dir non-empty, re-firing the
`.path` unit faster than the rate limit allowed, killing the watchdog exactly when
needed. Set `StartLimitIntervalSec=0` on the recovery `.service` (its own lock +
per-job budget guard runaway); reset-failed it if it ever trips.

**Nudge-loop** (`nudge-loop.sh`): a background poke that re-triggers the queue when
the worker idles with jobs waiting — the inotify `.path` unit does NOT pick up
pre-existing files after a restart, which silently stalls a resumed drain.
- **FIFO stamps are second-granular** — sleep 1 between paired submits.
- **CLOSE is a max-stamp held job** (`99999999-…` filename dropped straight into
  the queue dir): fix pairs' real date stamps always sort ahead, so CLOSE cannot
  gate early and auto-releases when the queue is otherwise empty. Keep an in-spec
  ordering guard (requeue-self if queue non-empty) as the race backstop. (Pilot
  lesson: a normally-stamped CLOSE gated while 4 fix rounds were still queued.)
- **Foreground-verification clause in every spec**, verbatim (batchq standing rule).
- **An LDA relay file** (`docs/LDA.md`, AS/400 Local Data Area pattern): JOBLOG is
  the record, not a channel — every job reads the tiny capped LDA first and may
  append <=3 terse trap/tip lines for successors; CLOSE prunes it at the gate.
  (Pilot lesson: a builder logged a trap "for the next job" that the next job,
  correctly minding its read-set, never saw.)

## Morning protocol

Read `JOBLOG.md` + `docs/reviews/*` verdicts + the CLOSE summary first; open full
logs only on surprise. If held: read `recovery.log` + the MSGW marker before
touching anything — the watchdog may have already tried its one move. Then the
merge session (step 6).

## Skill maintenance

This skill is PILOTING (first run fired 2026-08-09, dk-w5 milestone 1). After each
run, fold the CLOSE retro's lessons in here; when stable, propose the fix-loop +
recovery patterns upstream into the batchq engine + skill.
