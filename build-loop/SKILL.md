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
2. **THE PLANNING LOOP — staged multi-model adversarial refinement (Doug's
   standard, 2026-08-20; proven on the M7 plan: kill rates 28→33→38→58%,
   converged in 4 rounds).** Not one review — a chain, each round a LENS the
   prior round can't have:
   - **Round 1 (opus):** the four-lens first pass (spec-conformance, evidence,
     estate-reality live re-query, sequencing/scope), strongest-refutation
     discipline, refuted set recorded with kill rate. → **merge (opus)**.
   - **Round 2 (sonnet, merge-fidelity):** verify every round-1 finding
     applied; hunt half-applications and table-vs-prose drift (the class a
     first pass structurally cannot see). → **merge (sonnet)**.
   - **Round 3 (opus, deep structure):** adversarial gate-chain execution
     simulation (hostile scheduler over every reachable ordering),
     cold-builder spec-as-executed on the riskiest slices, ledger/clause
     arithmetic end-to-end. → **merge (opus)**.
   - **Round 4 (fable, final):** verify round 3; accretion audit (stale
     cross-references after N generations of edits); convergence judgment
     (rising kill rate + falling top-severity + closing defect families =
     converged; else say another round is needed); explicit fire-readiness
     verdict. → **merge (fable)**.
   Rules that make it work: **each merge runs on the SAME model as the review
   it applies** (the mind that found the issues applies them); merges are
   MECHANICAL — apply confirmed findings, take named recommendations, PARK
   every judgment call in a DECISIONS-PENDING doc, never rule; **every review
   round re-verdicts all parked decisions** (STANDS / NOW-DETERMINED with
   evidence / STALE with reason) so the pending list stays live; reviews run
   as cold-context queue jobs (model via the queue's `model` file, deleted as
   each round's first act). The human merge session then receives a CONVERGED
   plan + N review docs + a minimal live decisions list, and does RULINGS
   ONLY. Reference instance: dk-w5 `docs/m7-plan-review*.md` (the four
   documents) + `jobs-staged/fire-m7-planloop.sh` (the queue-native chain
   CLOSE invokes). Run it interactively for a first plan; wire it into CLOSE
   for every subsequent milestone.
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
   the NEXT milestone's planning job AND the full planning loop (stage 2's chain, via a planloop fire script), stops.
6. **Morning merge session** (interactive): human + strong model merge plan +
   review, decompose, fire the next milestone. One human session per milestone.
   **The human DECIDES; the interactive session EXECUTES** (Doug's ruling
   2026-09-10, dk-w5 M8 gate). Anything a plan marks "Doug's act", "operator
   act", or "driver session" — the kick, an admission call, a live-query
   bundle, the attended deploy — means: ask Doug one yes/no, then run it from
   the session. Never hand Doug a command to type. The batch-VM restrictions
   (no live appliance, no boat) bind JOBS; the interactive session on the LAN
   is the operator's hands and is not bound by them. Gate-0 prerequisites
   (quoting live facts, probing a remote surface, checking a mount HEAD) are
   the session's to do before it asks for the yes.

## Heavy-verification budgets: budget-refused is a RECORDED-CORRECT outcome (wedge #5 doctrine, 2026-08-22)

When a host carries a hard budget on a heavy verification workload (dk-w5's
reference: `conformance.sh` refuses unattended run #2+ per boot while docker
containment is unbuilt), a naive loop DEADLOCKS: every BUILD spec mandates the
heavy run, build #2 gets refused (exit 75), holds, and release-retry hits the
same budget forever. Neither escape is acceptable — an attended override runs
the exact workload the budget exists to prevent, and a host reboot to reset a
counter is disproportionate. The fix is doctrinal, in four pieces:

1. **BUILD specs**: "run the heavy suite once IF the budget allows; a
   budget-refusal (exit 75) is a RECORDED, CORRECT outcome — log the refusal
   line verbatim in your summary, ship on your slice-level targeted-test
   evidence (which must be green and recorded), never hold for the suite,
   NEVER override."
2. **REVIEW specs**: audit whichever evidence the budget allowed — the suite
   log when it ran, the targeted-test log + the refusal record when it
   didn't. Reviews NEVER run the heavy suite themselves (that's how the
   budget got eaten in the first place).
3. **ONE integration leg owns the full proof** (dk-w5: the E1a gate leg) —
   scheduled as the FIRST heavy run of its boot/budget window, or after a
   deliberate maintenance reset. Interim builds prove their slice; the gate
   proves the whole.
4. **Hold-recovery for a build that already held on the refusal**: commit its
   dirty notes on the job branch, merge (its targeted tests are the slice
   proof), park the held .job OUT of held/ before -release, re-spec the
   queued review per (2), release. Do NOT resubmit the build — the retry
   deadlocks on the same budget.

Write (1)-(3) into the repo's BUILD-LOOP doc + the review template so specs
inherit it; the budget guard itself is ~10 lines in the suite runner (counter
keyed on /proc/sys/kernel/random/boot_id in /var/tmp; exit 75; attended
override env var that logs a reason). Relax the budget only when the
underlying containment (the reason the budget exists) actually lands.

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

**SECOND, distinct root cause of the same `trigger-limit-hit` (diagnosed live 2026-08-19,
had failed ≥3×):** `recover.sh` writes a `MSGW.orig` backup of the marker during a
remediation and **leaves it behind on exit**; the `.path` unit's `PathExistsGlob=…/MSGW*`
then keeps matching that stale `.orig` → re-fires → `trigger-limit-hit` → **watchdog silently
`failed` on a live unattended drain** (no recovery net). Note `recover.sh` itself ignores
`.orig` (`grep -v '\.orig$'`) — only the *systemd glob* is wrong. Fixes: narrow the trigger to
exact `PathExists=…/MSGW` (not the glob), OR have recover.sh clean up its own `MSGW.orig` on
exit — plus the `StartLimitIntervalSec=0` above. **Manual re-arm:** `mv $Q/MSGW.orig $Q/done/…;
systemctl --user reset-failed w5recover.path && systemctl --user start w5recover.path` (a bare
reset-failed WON'T hold while the stale `.orig` still matches the glob). This lands in the engine
when the watchdog graduates (engine `build-loop/README.md`).

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

## Conformance/forcing churn vs the estate breaker (2026-08-19)

Conformance and forcing legs churn ~30–65 veth/min (ADR 0064's *legitimate* band) and
repeatedly tripped the estate churn-breaker (M5 ×2, M6 ×1). Fixer's interim fix: a
**sanctioned-window exemption** — a `CHURN_HEAVY=1` queue with a running job gets the
estate breaker's veth threshold raised to 90/min (keep the tag). Two limits survive it:
the estate ceiling is 90 (a real runaway still trips + re-MSGWs the estate, two-strikes),
and the **per-job veth guard in worker.sh is unchanged and exemption-blind** (kills a
single job sustaining >30/min for ~2 min — conformance/forcing bounce below it, but a
mis-converted drill won't). **The real fix is off-host isolation (a KVM VM, ADR 0064
W5-ISOLATE) — do NOT redesign the harness around the exemption; the VM removes the class.**
Full detail: the reference instance's `docs/BUILD-LOOP.md` "Drain SOP" §7.

## Run 3 — cruising-app friend-fleet redesign (2026-08-21) — planning loop + build drain on a NON-build-loop queue

First run of the full **planning loop** (stage 2) + build drain on a generic repo queue
(`cruising`) that had no build-loop scaffold. It worked — 5 planning rounds (kill rates
35→50→57→69→73 %, the invariant only closed at round 5), then S1–S4 built + reviewed, one
fix-forward round the paired review caught. Lessons:

- **Merge-hop self-chaining is UNRELIABLE on a tail.md that isn't build-loop-aware.** The
  planning-loop fire script chains each stage from the prior stage's LAST act (`bash
  fire-*.sh --next <succ>`). **REVIEW jobs ran that last act reliably; a MERGE job did not**
  — merge3 finished its edit, committed, and exited WITHOUT running its trailing `sbmjob`,
  so the chain silently stopped (queue DRAINED, no hold). The generic queue's welded "do ONE
  unit of work only, then exit" discourages the second submit. Reviews (which only READ + write
  one doc) apparently treat the chain call as part of their unit; merges (which EDIT the plan)
  treat themselves as done after the commit. **Mitigations:** (a) hand-fire the next stage on a
  DRAINED-but-incomplete wake — cheap, the watcher wakes you; (b) better for a cross-repo run,
  don't rely on merge-hop chaining at all — drive the merges from the session, or make the
  target queue's tail.md build-loop-aware first. Reviews chaining reliably ≠ merges will.
- **`fable` round 4 → use `opus` on a queue.** The reference `model_for` sets fable for round 4,
  but the batchq rule is "never fable on a queue"; a fire-readiness verdict wants a capable model
  anyway. Switched review4/merge4 to opus.
- **Merge jobs must delete the queue `model` override first-act too** (not just reviews) — else the
  last stage leaves a stale `opus`/`fable` model file that escalates the NEXT unrelated queue job.
- **The narrow "freeze" round earns its place.** Round 4 called S1 "READY after one edit"; the
  narrow round-5 verify found TWO more real S1 leaks (an ~11 h silent window, a pure-AIS
  regression) the edit missed. Do not skip the freeze round because round 4 sounds confident.
- **The paired REVIEW catches what the BUILD's own green tests miss via fixture artifacts.** S1's
  build passed 10 tests + 529 suite + a clean grep, but the review reproduced two defects hidden by
  fixture coincidences (a 1 h arrival window under the resume threshold; `passage_legs: []`). Bake
  the mechanical acceptance CHECK (here the D7.0 grep) into the BUILD, and have the REVIEW re-run it
  and reproduce the risky live cases with its OWN fixtures, not the shipped tests.

## Run 4 — batchq messaging plane / MSGQ M1 (2026-08-22, fixer) — new lessons

Two ADRs (0072 QSYSOPR + 0073 MSGQ) unified into one phased plan; the **unified planloop**
converged (4 rounds), then a **9-slice build drain went 9/9 APPROVED, one fix-forward, zero
holds, zero host-contention** — the cleanest drain yet. Lessons:

- **Merge-hop chaining CAN be made reliable — with imperative wording.** Run 3 concluded
  merges don't self-chain (they treat themselves as done after the commit). The fix that
  actually worked: reword the trailing call from `LAST ACT: bash fire-*.sh --next X` to
  **"MANDATORY FINAL STEP — this is an ACTION, not a note. Do NOT write this command into
  your summary and stop; RUN it with the Bash tool as your very last action, and do not end
  your turn until it prints 'queued'."** After that reword, every merge self-chained. So
  forceful "RUN-don't-describe" phrasing beats hand-firing; bake it into the fire template.
- **Cheap proof, NO docker — the big one (generalizes Doug's budget-refusal doctrine).** A
  milestone whose tests are **file/process-based** (not a conformance-suite) must NOT import
  the dk-w5 "one long-lived scratch stack" framing — it needs **zero containers**: the
  `tests/run-tests.sh` scratch-`~/.batchq` + fake-claude harness. Concentrate the one
  heavy/real-estate proof at the **attended CLOSE live-fire**. Payoff was decisive: the
  builds created **zero veth churn**, so they couldn't be a churn source and couldn't
  collateral-wedge — the whole "fire when the host is quiet" worry dissolved. Put a standing
  clause in the REVIEW template: **a slice test that spins up docker or runs the real estate
  is CHANGES-REQUESTED**; "deferred to CLOSE live-fire" is a *correct outcome, not a hold*.
- **Churn-collateral-kills are not the job's fault.** A cheap/read-only job on queue A gets
  exit-143'd by the **netns-blind per-job veth guard** during queue B's (dk-w5) *sanctioned*
  churn — the guard meters host-wide veth and attributes it to whatever's running. Recovery:
  a manual mini-QSYSOPR — wait for a churn **lull** (`journalctl -k | grep -c veth` low),
  set the correct model for the held stage, `-release`. A churn-kill is **NOT** a two-strikes
  re-decompose (the ADR-0063 FIX text's "resubmit identical" rule is for jobs whose OWN
  behavior churns). The sanctioned-window exemption covers the estate breaker but NOT the
  per-job guard — off-host isolation (ADR 0070) is the real fix.
- **"Inert file-seam on `main`" is WRONG for code that RUNS on merge.** That framing only
  fits a systemd unit you decline to enable. MSGQ's worker-emit + `sbmjob` changes execute
  the instant they merge — so inertness needs a **fail-safe runtime marker** (missing/
  unreadable ⇒ off; NEVER gate on the tracked `config`, a local mod there aborts
  `git pull --ff-only` estate-wide), and activation is a **separate seam** (create the marker
  + register the hooks). Two seams, not one. A planloop round caught this (r1) — worth
  checking on any run whose code isn't purely unit-gated.
- **Interim artifact to unblock a cross-phase dependency.** A phase-1 slice (S1c) referenced
  a later attended step's output (the `claude -p` probe result). Committing an **interim
  result file with the ruled default** made the cold job deterministic (no hold on the
  missing file); the real attended step overwrote it later. Cheaper than re-sequencing a
  fired drain.
- **Scope a UNIFYING planloop to the new surface only.** Merging two plans, the loop reviewed
  M1 + the shared-substrate contract + the M2 *delta*, and explicitly cited the already-
  converged M2 internals as **not to re-review** — spends rounds on the boundary, not on
  settled work.
- **Self-hosting dogfood is a live validator.** Building batchq's messaging plane *with*
  batchq, the submitter-identity feature went **live-but-inert on the engine mid-build** (the
  two-seam marker kept the emit off) — you literally see the built feature working (`from:
  unknown` on submits) before promote. Safe because inert; reassuring because real.

## Run 5 — proj-security master-plan review (2026-09-09/10) — planning loop with no build drain at all, on a doc-only milestone

First run where the "milestone" was a planning document, not code, and the loop never
reached a build/decompose/drain stage — Doug asked specifically for "the planning loop
found in the build loop skill," i.e. stage 2 alone. Four rounds (four-lens opus →
merge-fidelity sonnet → deep-structure opus → freeze fable), kill rates **0.355 → 0.538 →
0.423 → 0.75**, converged (no new defect family in round 4, rising kill rate + falling
severity). Then a fold pass applied the converged output across 12 live repo docs, and a
separate repo-wide consistency/trim pass followed. Lessons:

- **The four lenses translate cleanly from code to a planning doc, with no reframing
  needed beyond substituting the domain.** "Gate-chain execution simulation" became
  literally walking the plan's own dependency graph and hostile-scheduler-ing every legal
  execution order; "cold-builder spec-as-executed" became literally trying to run the
  riskiest CL/SQL commands in the doc as written (round 3 found a `SECAUDIT` deployment
  spec that would silently produce zero output rows — three commands between "run the
  SQL" and "schedule the job" existed only inside a source-file *comment*). "Ledger/clause
  arithmetic" became reconciling every count and cross-reference in the merged output.
  Nothing about the four-lens structure is code-specific; it's a general adversarial-review
  shape.
- **"Run it interactively for a first plan" (already in this skill) is the right call when
  no queue exists for the repo** — checked (`ssh <batchq-vm> "ls ~/.batchq/"`) before
  starting, found none registered for this repo, ran every round as a plain `Agent` call
  with a `model` override (opus/sonnet/opus/fable) instead of batchq queue jobs. No
  fire.sh, no LDA, no hold-recovery — just sequential foreground agent calls, each briefed
  cold (fresh agent, zero shared context) with the prior round's report as required reading.
  This is a legitimate, much lighter-weight mode of the loop for a single interactive
  session — don't reach for batchq machinery when there's no queue and no unattended
  requirement.
- **A must-fix that survives is often a wrong fact copied into 3+ documents, not a wrong
  fact in one place.** Round 1's single highest-value catch (`*NETCMN` does not audit
  telnet — `*NETTELSVR` does) was live-verified against a newly-attached RAG the draft's
  own citations predated; it had already propagated into four documents before the loop
  ran and a repo grep during the later cleanup pass found three MORE instances the fold
  had missed. **Grep the whole repo for a falsified claim's exact token after fixing the
  N places you found by reading** — reading finds most instances, grep after fixing finds
  the rest.
- **Round 2 (merge-fidelity) earns its place by auditing the auditor, not the artifact.**
  Its findings weren't new facts — they were "Merge 1 said it swept the repo for every
  instance of X and undercounted." Twice more in this run (Merge 2 auditing Merge 1, then
  a repo-cleanup pass finding what the fold still missed) the same pattern repeated: every
  round's sweep-completeness claim was itself incomplete, checkable, and worth a
  dedicated audit rather than trusting the round's own count.
- **Splitting a combined multi-pass diff into separate logical commits, after both passes
  already ran on the same live working tree with no snapshot in between, is possible but
  needs a specific technique — `git apply`/`git add -p` against the dirty tree does NOT
  work.** `git apply` matches hunks against the CURRENT index/working tree, which by
  definition no longer contains the "old" text a `git diff HEAD` hunk is searching for
  (it's already been replaced by the combined result) — every attempt to reapply a slice
  of that diff against the live tree fails with "patch does not apply," even when the hunk
  content demonstrably matches `git show HEAD:<file>` byte-for-byte. The fix: (1) `git diff
  -U0` (zero context) on each touched file — real edits from two independent passes are
  almost always on different lines/paragraphs, so a 0-context diff usually splits them into
  non-overlapping hunks even when a 3-context diff would have merged them into one; (2)
  categorize each hunk by content against what you know each pass did; (3) extract one
  pass's hunks into a patch file and apply it with the standalone **`patch --fuzz=0`**
  command (not `git apply`) against a **detached copy** of `git show HEAD:<file>` — `patch`
  doesn't care about git's index state, only the file it's pointed at; (4) copy that
  reconstructed "pass 1 only" content into the real file, stage, commit; (5) restore the
  saved final (both-passes) content, stage the rest, commit. **Verify with `git diff --stat
  <commit-before-split>..<HEAD>` and confirm it exactly matches the original combined
  diff** — this catches any hunk-categorization mistake immediately. Where a hunk
  genuinely contains both passes' edits on the same line (pass 2 edited text pass 1 had
  just written), perfect separation isn't well-defined — attribute the whole hunk to
  whichever pass dominates it and disclose the approximation rather than chase perfection.
- **Read the doc's own convergence signal, don't just trust the stated round count.** The
  freeze round (4) was told it was "the final round" but was explicitly instructed to say
  so if it wasn't and to name what a round 5 would need — it found zero must-fix, and gave
  an actual reasoned verdict (kill rate direction + no new defect family) rather than
  rubber-stamping "done" because it was told it was last.

## Run 6 — bosun M1/M3/M6a/M7 drain (2026-09-12) — the review contract's one-word ambiguity

First run on the `bosun` queue; seven paired slices + a max-stamp CLOSE, fixture-only
(the batch VM reaches nothing but itself, so zero docker, zero network, zero veth —
Run 4's "cheap proof" framing applied cleanly and the whole churn worry dissolved
again). Two lessons, and the first cost a whole gate pass:

- **"Write the fix pair into the queue directory" is ambiguous, and half the reviewers
  read it as STAGE.** S1's and S2's reviewers submitted with `sbmjob` and their fixes
  ran; S3–S7's reviewers wrote their pairs into the repo's `jobs-staged/` and stopped.
  The drain then DRAINED with a green 186-test suite and **five real defects live on
  `main`** — an event that would never fire, a promise broken weeks early, a poller
  recovering 9× too slowly from the exact failure it exists to prevent, dead code on
  the one surface that runs hourly, and a write path that crashed on every real call
  after committing an orphaned insert. CLOSE caught all five *by checking the merged
  code rather than trusting the reports*, and gated FAILS. **Fix: the Run-4 imperative
  belongs in the REVIEW template too, not just the fire template** — "MANDATORY FINAL
  STEP — this is an ACTION, not a note. RUN it with the Bash tool as your last action
  and do not end your turn until it prints `queued`. **Staging is not submitting.**"
- **Make CLOSE's gate check the CODE, not the verdicts.** This CLOSE re-read `main`
  for each named defect and found all five still present. A CLOSE that had reconciled
  JOBLOG verdicts against a green suite would have passed the drain. Bake into the
  CLOSE spec: *for every CHANGES-REQUESTED finding, confirm the fix in the merged
  source by file and line — a green suite is not evidence that a staged fix landed.*
- **Corollary on CLOSE's own authority:** this CLOSE was told "do not fire more jobs",
  so it correctly stopped and handed back — which cost a human round-trip for a
  mechanically obvious action. The skill's gate-and-remediate budget (max 3 passes)
  exists precisely for this; say so explicitly in the CLOSE spec rather than
  forbidding submission outright.

## Skill maintenance

This skill has run on dk-w5 (milestones 1–6, 2026-08-09 →), the batchq engine
(Phase 3, 2026-08-18 — first cross-repo run), cruising-app (friend-fleet, 2026-08-21 —
first planning-loop + drain on a non-build-loop queue), the batchq messaging plane
(MSGQ M1, 2026-08-22 — first zero-docker file/process milestone; cheap-proof + two-seam
lessons above), bosun (M1/M3 drain, 2026-09-12 — the review-contract ambiguity above), and proj-security (master-plan review, 2026-09-09/10 — first planning-loop-
only run with no build/drain stage at all, on a pure documentation milestone; the commit-
splitting technique above is reusable well beyond this skill). After each run, fold the
CLOSE retro's lessons in here; when stable, propose the fix-loop + recovery patterns
upstream into the batchq engine + skill.

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
