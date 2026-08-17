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

**The error-handler is NOT yet safe for unattended heavy drains (WEDGE 2026-08-11).**
The self-healing loop caused a MULTI-HOUR CPU/memory wedge on a shared host: a
persistent hold (a fix job that kept failing) made the error-handler re-fire
repeatedly, each invocation launching a full conformance suite (docker stacks), and
the stacks piled up until memory exhausted → swap thrash → box unreachable, needing a
physical power-cycle. The debounce added mid-crisis was insufficient. BEFORE re-arming
the error-handler for unattended runs, it needs: (a) a HARD per-job remediation cap
that actually stops re-invocation (a real cooldown/lock, not just a counter), (b) it
must NEVER stack conformance runs (check no other remediation/suite is already
running), and (c) a global concurrency ceiling on remediation+build docker stacks.
Until hardened, finish heavy milestones SEMI-ATTENDED: error-handler OFF, low
MAX_CONCURRENT (2), nudge-loop ON (safe — it only re-triggers the queue), operator
watching for holds. The nudge-loop and the estate build/review jobs were never the
problem; the error-handler's re-fire-under-persistent-hold was. **→ UPDATE (M5,
2026-08-17): unattended heavy drains became safe via an EXTERNAL host watchdog (the
in-box iTCO was proven dead) + the shared-stack churn fix — see "The two-operator
unattended run" below, which supersedes the "finish SEMI-ATTENDED" conclusion here.**

**The error-handler needs its own error handling.** It died mid-K8 on systemd
`start-limit-hit` — a persistent hold kept the `held/` dir non-empty, re-firing the
`.path` unit faster than the rate limit allowed, killing the watchdog exactly when
needed. Set `StartLimitIntervalSec=0` on the recovery `.service` (its own lock +
per-job budget guard runaway); reset-failed it if it ever trips.

**Make remediation VISIBLE** (2026-08-11): the error-handler runs as a systemd
process against a HELD job, so it's NOT in the monitor's running/ list — a hold under
active auto-repair looks identical to a wedged one. Have the recovery wrapper write a
live status into the MSGW (`AUTO-REMEDIATION ACTIVE — Xs elapsed, started HH:MM`,
heartbeat every ~15s) so the operator sees it working and for how long. Self-healing
must be legible, or the operator falls back to blind trust — the opposite of the goal.

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

## The two-operator unattended run — what wedged M5 five times and the rules that fix it (2026-08-17)

M5 ran the loop unattended with a second operator (a "driver" CC owning the JOBS +
a structure-owner CC — fixer — owning host safety). It wedged the host FIVE times
and stalled repeatedly. Every stall was one of a handful of classes; these are the
rules, most-corrective first.

**Churn is the #1 killer, and the fix is the SHARED STACK — NOT an isolation
boundary.** `scripts/conformance.sh` brings up ONE shared compose stack
(`W5_CONFORMANCE_SHARED_PROJECT`) and runs every test against it: measured
**0 network / 0 container / 0 veth over a full 994s run**. The wedge comes from
running individual `test_*.sh` **standalone** — with no shared-project env each
brings up its OWN throwaway stack; ~20 in a row tripped the estate veth
circuit-breaker (all queues MSGW'd). **A nested-docker / netns "disposable
boundary" does NOT fix this** (M5 built one — ADR 0064 — and it failed the review):
the breaker meters the **netns-blind kernel veth log** (`journalctl -k | grep veth`),
so churn inside a nested daemon STILL counts (195 kernel lines during a 37s
in-boundary run while host `ip link` showed 0); and a nested boundary can't run the
suite green from a worktree (unmounted gitdir) or reach the host appliance. **Rule:
every test-running spec MANDATES `conformance.sh` and FORBIDS standalone `test_*.sh`;
a structural pre-flight that refuses a host compose-up unless the shared-project env
is set is the belt.** Don't reach for a fancy isolation boundary when the shared
stack already measures ~zero.

**Never fire host-wedging work unattended without a PROVEN external recovery
backstop.** The in-box hardware watchdog (iTCO) was assumed working and was NOT
(proven dead under test) — firing unattended caused wedge #5, hours dark. Only an
**external** watchdog on a *different* host (M5: an AMT master-bus-reset from the
pihole, capped at 2 fires then escalate) makes overnight safe. Verify the backstop
actually fires before trusting it; the plan's "attended G-track" constraint was
load-bearing, not a formality.

**Monitor LAN-DIRECT; never over a mesh/relay.** `ssh <host>` resolving to a
Tailscale name relayed through a DERP node showed `rx 0 / idle` — which IS the wedge
symptom, not a path blip. An hour was lost thrashing the relay while the box sat on
the same LAN. Pin `Host <host> → <LAN-IP>` in `~/.ssh/config`. "rx 0 / idle on the
mesh" = treat as a wedge, check LAN first, don't thrash.

**GO/HELD state is machine-readable, NOT prose.** A review job read a stale
"STAND-DOWN" HANDOFF entry (superseded 20 min earlier but not deleted) and ESCALATED
— dead-stopping the chain. Coordinate hold/release through a single-line flag file
(`STATUS`: `GO` / `HELD:reason:who:ts` / `READY:commit`) that JOBS and monitors read
FIRST; HANDOFF prose only narrates history. This is "never write prose that describes
state" applied to the operator seam. The structure-owner's holds are already
machine-readable (unit enabled/active, MSGW files) — give the driver's readiness the
same, and add a timer that auto-acts on `READY` so flow doesn't wait on a human relay.

**Silent stalls page no one — close them.** A review ESCALATE does NOT fire the tail
duty → the queue empties with no held job and no page. So do a tail-duty/marker miss
and a governance doc going stale. Make ESCALATE **ntfy a human**; make the monitor
treat "queue+running empty but milestone incomplete" as a resume trigger; keep a
hold-age escalator (MSGW older than ~2h → re-page).

**Recovery can be silently dead when you need it.** The recovery watchdog's caps are
correct (bounded per-job + nightly), but: (a) its **reset was coupled to `fire.sh`**,
which the resume path never runs → recovery stayed capped-dead after a re-enable —
decouple the reset, reset counts explicitly at resume; (b) the host **circuit-breaker
killed the recovery `.path` unit as a side effect** (an MSGW flood trigger-limit-hit
it) — the breaker should `reset-failed` what it trips.

**Operator roles: driver owns the JOBS, structure-owner owns the HOST.** The driver
runs/root-cause-fixes/finishes jobs to CLOSE; the structure-owner owns the watchdog,
breaker, and estate-wide holds. Both failure directions happened in one night:
over-reach (firing unattended → wedge) and over-defer (calling a job-fix "structure's
call"). A crash whose cause is in the job's design is ALWAYS the driver's to fix —
change the spec so it can't recur (a `find /` that hung → template guard; churn →
shared-stack clause; a 7× regen loop → bound it), never blind-retry. "Can't validate
while held ≠ can't fix while held" — prep the fix while the queue is frozen so the
slice is ready the instant it clears; but recommend, don't apply-blind, test-infra
changes you can't run.

**Run an adversarial review of the OPERATIONAL SETUP before resuming a stalled
unattended drain.** M5's did exactly this and caught a broken fix (the boundary)
before the next slice face-planted, plus dead recovery and stale-governance landmines.
The setup, not the jobs, is the schedule risk in a two-operator unattended run.

## Morning protocol

Read `JOBLOG.md` + `docs/reviews/*` verdicts + the CLOSE summary first; open full
logs only on surprise. If held: read `recovery.log` + the MSGW marker before
touching anything — the watchdog may have already tried its one move. Then the
merge session (step 6).

## Skill maintenance

This skill is PILOTING (first run fired 2026-08-09, dk-w5 milestone 1). After each
run, fold the CLOSE retro's lessons in here; when stable, propose the fix-loop +
recovery patterns upstream into the batchq engine + skill.
