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
   contracts come from the plan, not from seeing prior output. **Bulk-submit the
   ready slices in dependency-stamp order — do NOT chain per-hop fire-duties** (see
   "Submission model" below; the queue already serializes).
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

## Submission model: bulk-submit in dependency-stamp order — do NOT chain per-hop fire-duties

The M5/M6 "each review fires the next slice via a tail duty" chain is **DEPRECATED**
(Doug, 2026-08-19). It put a precondition check on every hop, and a check that can't run
where the duty runs silently stalls the whole drain — M6 R0→R3 died overnight because a
review-duty ran `fire-*next.sh` from inside its job worktree, where the ADR-0068
system-manager gives NO user D-Bus, so `systemctl --user is-active w5recover.path`
returned "No medium found" and the fire aborted as "not armed". The queue already
serializes (one worker, lexical `ls|sort|head -1` FIFO), so chaining buys nothing over
bulk submission. Default model instead:

1. **Bulk-submit every READY slice up front, in dependency order.** FIFO runs them in
   stamp order, one after another, automatically. Independent slices submit together;
   dependent slices just get later stamps.
2. **Fix pairs stamp AHEAD of downstream — not at `date +now`.** A CHANGES-REQUESTED fix
   pair must sort immediately after the slice it fixes and BEFORE any already-queued
   downstream slice: stamp it off the failing slice's own base stamp + a `-fixN` suffix.
   Current-time stamps sort AFTER downstream → downstream reads un-fixed output (the
   freshness hazard the old chain existed to prevent). This is the whole reason the old
   design gated — solved by a stamp convention, not a fire-duty.
3. **Stop the chain by HOLDING THE QUEUE, only for a genuine must-halt.** Fix-forward +
   the 2-round cap mean most failures continue the drain; ADR 0068 turns host trouble
   into throttle/scope-kill, not a wedge. The rare true-stop (a heavy leg that would
   wedge the host if the next ran) is the failing review's last act: MSGW-hold the queue
   (`sbmjob -q <q> -release` to resume) or `-hold-queued` the specific downstream jobs.
4. **Defer-queue ONLY the genuinely-not-ready.** A clock-gated job (fires on a calendar,
   days out) or a rendezvous job (needs two independent tracks both done) is the only
   thing that legitimately stays OUT of the queue until its condition — dropped by an
   external timer or a single event-driven fire when the last key lands.

**The sandbox rule (root cause of the stall above):** any check a job spec or an
event-driven fire performs must be doable from a batchq job sandbox — clean env, no
`XDG_RUNTIME_DIR`, no user D-Bus under the system manager. Make bus/systemd checks
bus-tolerant (proceed on "no bus"; abort only on a definite negative from a REACHABLE
bus) or use a marker-file check instead. **Test the fire path by running it under
`env -i`, not by reading the engine** — M6's fire-readiness review read `worker.sh`/
`deploy.sh` but never ran a fire script from a sandbox, so it missed this entirely.

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

## Run 2 — batchq engine Phase 3 (2026-08-18, fixer) — new lessons

Second instance, first on a repo other than dk-w5: built the batchq **control plane**
into the engine repo. Drained 5/5 slices approved (one auto fix-round), then an
attended promote. Two lessons worth keeping:

- **Live-fire is load-bearing; offline stub-tests pass VACUOUSLY on host primitives.**
  A slice's "finding-1 fix" — pause systemd `RuntimeMaxSec` on freeze — had a green
  offline test that STUBBED `systemctl` and asserted the *call*. The attended live-fire
  found systemd flatly REJECTS `set-property RuntimeMaxSec` on a running scope: the fix
  was a silent no-op the whole time. **Rule: when a slice touches a host/kernel/systemd
  primitive (a unit property, a cgroup op, a scheduler behavior), a stubbed unit test
  proves the CALL, never the EFFECT.** Such slices need an explicit **attended live-fire
  gate** against the real primitive before the claim is trusted — bake it into the plan's
  acceptance, don't let a green stub-suite stand in for it. Add a spec NG: "a test that
  stubs the primitive it's validating proves nothing about the primitive."

- **Build-looping self-modifying infrastructure is safe via BRANCH isolation + an inert
  seam.** Building the batchq engine *with* batchq is a snake-eating-its-tail hazard. It
  was made safe by two independent layers: (1) a dedicated queue whose clone sits on a
  `phase3` branch — the live engine tracks `main` and `engine-sync` hardcodes
  `pull origin main`, so nothing on `phase3` can reach the running engine; (2) the
  `worker.sh.new` A/B seam so even merging `phase3→main` is non-activating until an
  attended rename. **The build-loop builds inert; a human promotes.** Generalizes to any
  self-hosting/estate-critical target: isolate the build on a branch the live system
  can't pull, keep an inert seam, and make activation a separate attended step. Verify
  the isolation claim (what does the live puller actually pull?) — don't assume.

## Skill maintenance

This skill has run on dk-w5 (milestones 1–6, 2026-08-09 →) and the batchq engine
(Phase 3, 2026-08-18 — first cross-repo run). After each run, fold the CLOSE retro's
lessons in here; when stable, propose the fix-loop + recovery patterns upstream into the
batchq engine + skill.

**DECIDED END-HOME (Doug, 2026-08-19): the build-loop graduates INTO the batchq engine.**
It currently lives inside dk-w5 as "the reference to copy" — that's a temporary mis-home
(a project wearing estate-wide clothes). **Trigger: when the dk-w5 build (M6/M7) is done**,
as part of the batchq **productization** pass, the reusable chassis + mechanics move into
`~/.batchq/engine`: templates (fire.sh, BUILD/REVIEW/CLOSE + review-template, plan-review
method, CLAUSE-COVERAGE/LDA shapes) and the engine-native mechanics (`recover.sh`,
`nudge-loop.sh`, the `w5recover.*` units, model-tiering, max-stamp CLOSE, `SYSTEM`/`sysjob`
— **`recover.sh`/`nudge-loop.sh`/`w5recover.*` SNAPSHOTTED to git 2026-08-19 at engine
`build-loop/reference-dk-w5/`; still live-wired from `~/.batchq/dk-w5/`, generalize+rewire at
productization**). dk-w5
keeps only its own instance. Until then, copy from dk-w5 but know the end-home is the
engine. Full note + the broader "sweep for other mis-homed pieces" mandate: engine
`PARKING_LOT.md` ("Productize batchq for portability").

**BANKED FOR M7 (Doug, 2026-08-19):** the "Submission model" section above supersedes the
per-hop fire-duty chain. M6 finishes on the now-fixed chain; **M7's plan + fire.sh adopt
bulk-submit-in-stamp-order + stamp-ahead fix pairs + hold-to-stop by default** — no tail
RELEASE-DUTY chain except the one legitimately-deferred rendezvous fire. CLOSE-M6's
M7-planning spec should cite this section.
