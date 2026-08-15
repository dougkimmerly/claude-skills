---
name: batchq
description: Doug's AS/400-style batch job queue for unattended Claude work (~/.batchq — one JOBQ per repo, homecore-hosted worker (systemd; the Mac's sbmjob forwards to it), worktree-per-job, MSGW holds). Use when Doug says "queue that", "sbmjob", "add it to the jobq", "run it overnight/as a batch job", "check the queue", "what did the batch jobs do", or "set up a jobq for this repo". ALSO use when you touched/found something in ANOTHER repo's domain — cross-domain requests are delivered as verify-first jobs to the owning repo's queue (see "Cross-domain requests"; fixer ADR 0048), not HANDOFF.md entries. Jobs run in isolated git worktrees — interactive edits no longer race them.
---

# batchq — the batch job queue

One engine, one JOBQ per repo. Jobs are files; the OS's file-watcher (systemd
`.path` on homecore) fires the worker the moment one lands; the worker drains
FIFO, running each job as a **fresh headless `claude -p` session in its own git
worktree** with the queue's housekeeping tail welded on. The WORKER merges each
job's branch into main and pushes — jobs never push. No timers, no session needs
to stay open. Doug explicitly authorized `--dangerously-skip-permissions` for
these jobs (2026-07-20). Engine history + design rationale: `~/.batchq/engine/`
is a git repo (`github.com/dougkimmerly/batchq`) — see its `DECISIONS.md` (v2
worktree rework, 2026-07-24) and `PARKING_LOT.md`.

## Where it runs (homecore, since 2026-08-05 — fixer ADR 0049)

The worker, all queue state (`~/.batchq/<queue>/`), the engine, and the dashboard
run on **homecore** (192.168.20.19), fired by **systemd `--user`** units
(`batchq@<queue>.path` → `batchq@<queue>.service`) — not launchd. Repos are
dedicated clones under `~/batchq-repos/` on homecore (NOT `/var/syncthing`; git
remotes are the only sync bus). Staying current is **event-driven, not a poll**:
the worker `fetch`+`ff-only`s each clone to origin **before every job** (jobs run
on current code, incl. interactive Mac pushes) and integrate-then-retries the
**push** after (a Mac push mid-job never strands work); between jobs a clone may
sit behind origin harmlessly. You still drive everything from the Mac exactly
as before: `~/.local/bin/sbmjob` is now a thin **forwarder** that SSHes to
homecore, so `sbmjob …` / `sbmjob -wrk` behave identically. The heavy Claude API
traffic leaves homecore's pipe, so submitting from anywhere (incl. away over
Tailscale) is a small SSH round-trip. Rollback: the Mac's launchd plists are
unloaded but retained. Deviations & gotchas (inotify limits, XDG-over-SSH,
10-char queue names): `~/.batchq/engine/PARKING_LOT.md` +
`fixer/docs/runbooks/batchq-homecore-migration.md`.

**Never use in-session CronCreate for autonomy — proven to never fire on this
Mac (2026-07-20 canary test).** This queue is the replacement.

A global SessionStart hook (`~/.claude/skills/bin/jobq-check.sh`) announces the
queue's state to every session that opens inside a registered repo — you don't
need to discover the queue, you're told. The announcement is awareness, not a
mode switch: Doug saying "strategy session" is what flips the session into
reviewer posture (see the strategy-session skill).

## Posture: never idle — there is always a next job to submit

The queue is meant to be FED CONTINUOUSLY, not watched. If you catch yourself
writing "I'll wait for the queue to drain and then…", stop — submit that as a
job instead. The three non-blocking moves, one of which always applies:

1. **Submit a named, self-contained build job** (`sbmjob "Build X — spec…"`).
2. **Expedite a queue-world change** (`sbmjob -pty 1 "…"`) — reprioritization,
   a captured decision, a ROADMAP edit that must land before the next job.
3. **Fire a read-only job** (`sbmjob -ro "Audit/research Y…"`) — runs
   concurrently, never blocks or holds anything.

Since v2 (worktree-per-job) you may also simply **edit and commit in the repo
while jobs run** — jobs can't sweep your files anymore. The only interaction
left is at merge time (see "Sharing the repo" below).

## Layout

```
~/.batchq/
  engine/            worker.sh · sbmjob · wrkjobq.py · jobsummary.py ·
                     register.sh · watch.sh · defaults/ · tests/run-tests.sh ·
                     DECISIONS.md   (a git repo — commit engine changes)
  <queue>/           queue/ running/ done/ held/ work/ config tail.md next.md
                     JOBLOG.md MSGW?
```

`config` sets `REPO=` (and optionally `MAX_MIN=`, default 150-min job kill).
`engine/config` sets `MAX_CONCURRENT` (global write slots), `RO_MAX`
(concurrent read-only jobs per queue), `NTFY_SERVER`/`NTFY_TOPIC` (push).
`tail.md` = the welded standing orders; `next.md` = what a `NEXT` token means.
`work/` holds the per-job worktrees (transient). `JOBLOG.md` = one entry per
finished job: disposition + the job's own final summary. Registered queues:
`shipslog`, `shard` (physically `~/.shard-batch`, symlinked — legacy).

**Per-queue worktree provisioning (opt-in, fixer #1344).** A fresh worktree is a
bare `git worktree add` — no `node_modules`, no `.env`, deps gitignored — so
node/pg-heavy repos couldn't self-verify (`npm run test:unit`, DB queries). If a
queue defines an **executable `$Q/setup.sh`** (i.e. `~/.batchq/<queue>/setup.sh`),
the worker runs it *inside* the fresh worktree right after `worktree add` (both RO
and RW lanes, `provision_worktree` in `worker.sh`). Opt-in (no-op for queues
without it) and non-fatal (a failing hook is logged, the job still runs). Example
(`music-library`): sources nvm (npm is not on the worker's default PATH) then
`npm ci`. Note node/npm live under `~/.nvm`; there is **no host `psql`** — jobs
reach the DB via `docker exec dk400-postgres psql` or the `pg` package.

## Job types

- **Write job** (`sbmjob "…"` → `<stamp>-<slug>.job`): serial — queue lane +
  a global slot; runs on branch `job/<name>` in `work/<name>`; the worker
  merges + pushes on success.
- **Read-only job** (`sbmjob -ro "…"` → `<stamp>-<slug>.ro.job`): research /
  audit / report. Runs CONCURRENTLY (no lane wait, no global slot, `RO_MAX`
  cap), findings land in `done/<job>.summary.md` + `JOBLOG.md`. A failed RO
  job logs + notifies but NEVER holds the queue. If it commits anyway, the
  branch is kept and noted — merge by hand if wanted.
- **`NEXT` token**: "take the top unblocked backlog item". **Only legal when
  the top ROADMAP item is already executor-ready** — self-contained spec,
  decisions made, acceptance named (a `tests/*-sim.js` or equivalent). If it
  isn't, the framing IS the job: submit a named job that includes writing its
  own ROADMAP entry. Named jobs beat anonymous NEXTs — the retro lost track
  of a stray NEXT; don't stack several when order matters to you.

## Commands (also what Doug types)

```
sbmjob "Build X — full spec"     # THE default unit: named, self-contained
sbmjob -ro "Audit Y — report"    # read-only: concurrent, never holds
sbmjob NEXT                      # top backlog item (only if executor-ready)
sbmjob -pty 1 "..."              # JOBPTY: expedite — runs BEFORE every normal job
sbmjob -q <name> ...             # target a queue from anywhere
sbmjob -wrk                      # WRKJOBQ text view, all queues
sbmjob -whichq                   # which queue does cwd resolve to?
sbmjob -watch [hb_s]             # wake-on-event (run with run_in_background)
sbmjob -release                  # clear MSGW hold + restart that queue's worker
wrkjobq                          # curses 5250 in the terminal (ssh fallback)
wrkjobq --once                   # one text snapshot to stdout
```

**THE monitor is the web 5250 at http://192.168.20.19:8250/** (systemd
`batchq-web.service` on homecore, bound `0.0.0.0` via `BATCHQ_WEB_HOST`; also on
the Command Centre dashboard as the `batchq` tile). It speaks dk400's own screen
protocol — same terminal.css, 3270 font vendored — and auto-refreshes every
3 s without clobbering half-typed options. Screens: **WRKJOBQ** (queues:
5=Work with jobs, 6=Release, 8=JOBLOG) → **WRKJOBS** (jobs: 4=End queued,
5=Display log — LIVE follow while running, 8=Summary, 9=Resubmit) →
**SBMJOB** prompt on F10 (queue/pty/read-only/text). The `===>` line takes
`SBMJOB [-Q q] [-PTY n] [-RO] text`, `NEXT [q]`, `REL [q]`. Server binds
`0.0.0.0` on homecore (`BATCHQ_WEB_HOST`; default localhost — an unauthenticated
control surface, LAN-exposed, see engine `PARKING_LOT.md`); source
`engine/wrkjobq_web.py` + `engine/web/`.

## Rules of the machine

- **Jobs run SONNET by default** (Doug 2026-07-30; engine commit that day). The
  worker resolves `--model` per call: `<queue>/model` file > `engine/model` file >
  `sonnet`. Jobs silently inherited the interactive default (fable) before —
  a 12-job day on the premium tier. The submitting session's stronger model does
  the reasoning IN THE SPEC; jobs execute cold on sonnet. Escalate a single job by
  writing the model name to `~/.batchq/<queue>/model` before submit and deleting
  it after — rare exception, never the norm.
- **Write jobs: one per queue, `MAX_CONCURRENT` homecore-wide** (global slots,
  currently **6** — different queues may overlap). RO jobs ride outside the slots, `RO_MAX` per
  queue. Lock dirs record their holder's PID; stale-break on holder death
  (mtime-age is the fallback), and every no-op lock exit is logged.
- **A job must leave its WORKTREE clean and commit its work** — an uncommitted
  worktree or non-zero exit moves the job to `held/` + freezes the queue
  (`MSGW`), worktree kept for autopsy. Read the marker + `done/<job>.log`,
  fix or decide, then `sbmjob -release` (which auto-resubmits held jobs).
- **Offline is not failure**: a non-zero exit while the network is down
  retries with backoff (3 attempts) before holding. Prior attempts' logs are
  kept as `done/<job>.log.attemptN`.
- **Merge conflict = job done, queue held**: the work is safe on its `job/*`
  branch; the MSGW gives the exact manual-merge commands. The queue holds
  because later jobs may build on that work. Merge, push, release.
- **A "DONE but UNMERGED / needs manual merge" line in JOBLOG is NOT proof of a
  live hold** — the worktree job writes that line *before* it exits, and the
  worker merges *after*, so the line goes stale the instant the merge lands
  (seen 2026-08-04: read a stale line as a hold and spawned a needless recovery
  job). The authoritative "still needs hands" signals are the queue's `held/`
  dir and an actual `MSGW` — check those, or `git log main | grep "Merge branch"`
  for the branch name, BEFORE treating any JOBLOG disposition as unfinished.
- **Machine-readable completion signal (bit us 2026-08-08):** the `.log` fills
  LIVE while the job runs — a consumer that tests `done/<job>.log` existence
  declares completion ~16s after submission (this broke the Telegram
  dispatcher's first live run). The authoritative signals are the **`.job`
  file itself appearing in `done/`** (worker moves it at completion) and
  `done/<job>.summary.md` (written at completion; also the job's final result
  JSON line carries `total_cost_usd` + `usage` — parsed daily by fixer's
  CLSPEND spend tracker, ADR 0059).
- **Jobs can arrive via Telegram** (fixer ADR 0058): any text Doug sends the
  bot becomes a verify-first job on the fixer queue; the dispatcher relays
  the job's summary back to his phone. Producer convention: begin the job
  summary with `**Answer for Doug:**` — that block is what gets sent.
- Job logs: `done/<job>.log` — stream-json, filling LIVE. Render with
  `wrkjobq` option 5 or `tail -f … | python3 ~/.batchq/engine/render_stream.py`.
  Quick review path: `done/<job>.summary.md` and `JOBLOG.md` — read those
  FIRST; open the full log only when something looks off.
- **ntfy push**: the worker pushes job-done / MSGW / drain to the topic in
  `engine/config`. Every push's title ends with `· N left in queue` — the
  drain's live position. Subscribe on the phone: ntfy app → the `NTFY_TOPIC` value.

## Sharing the repo with a running queue (v2 — mostly a non-issue)

Interactive edits and batch jobs no longer share a tree. Edit freely, commit
normally. Two residual rules:

1. **Commit your own edits reasonably promptly.** The worker merges a job
   branch into the MAIN checkout; if your uncommitted edits overlap the
   files a job changed, that merge aborts safely → MSGW "manual merge
   needed". Nothing is lost — commit/stash yours, merge the branch, release.
2. **Sequential jobs build on each other**, so a held merge holds the queue —
   don't leave a manual-merge MSGW sitting.
3. **Shared hot-spot files need an edit convention** (learned 2026-07-27,
   shard: two manual merges in one day). When jobs and the interactive
   session both edit one file's SAME region — e.g. a ROADMAP where new
   entries are inserted at the top while each finishing job stamps "done" on
   its topmost-entry heading — adjacent-line edits conflict every time. Fix
   in the queue's `tail.md`: jobs must never edit the region where the
   session inserts (e.g. mark done by APPENDING a status line at the END of
   their entry, never editing its heading). Distant edits auto-merge; the
   dance disappears.

`-pty 1` expedites remain the tool for REORDERING the queue's world (a
decision the next job must see), not for tree safety. Cancel/reorder queued
jobs by renaming/deleting files in `<queue>/queue/` — they're execution
tokens, not repo files (safe while a job runs; only don't race an idle
worker's pick).

## Submitting from a session

When Doug decides something and says "queue it": write the decision INTO the
job text — context, the chosen option, acceptance criteria, "update the
ROADMAP/ADR yourself" — so the fresh session needs nothing else. **Acceptance
criteria = ENUMERATED behavioral cases** — the submitting session fixes the
test contract before any code exists; the executor's tail.md forbids editing
existing tests to pass and requires the full suite green (see engine
`defaults/tail.md`, inherited by new queues; the strategy-session skill
carries the framing side). This
**named self-contained job is the default unit** (the retro's strongest
pattern: MON4, ETA-5c, VOY-START all one-shotted). `sbmjob -q <queue> "..."`
or drop a file in `<queue>/queue/` named `YYYYmmdd-HHMMSS-<slug>.job`
(`0N-` prefix = JOBPTY N; `.ro.job` = read-only).

**Backgrounding is now engine-killed — the per-spec clause is retired**
(2026-08-15, engine dfec97f; history: two jobs idle-waited to death 2026-08-07,
three more auto-backgrounded to death 2026-08-14). The worker now runs every
batch session with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` (disables
run_in_background AND harness auto-backgrounding) and raises
`BASH_DEFAULT/MAX_TIMEOUT_MS` to the job's `MAX_MIN` ceiling so long suites
finish in the foreground; a standing BACKGROUND TASKS section lives in
`defaults/tail.md` and every registered queue's `tail.md`. Specs no longer
need the defensive boilerplate. Still worth stating in specs: "COMMIT FEATURE
CODE FIRST, before docs/full-suite runs, so partial progress survives" — that
one is job-ordering advice the engine can't enforce.

**Gotcha — never pass a rich job spec as an inline `sbmjob "..."` arg.** Job
text almost always contains backticks (`` `file.js` ``) and parentheses
(`foo(bar)`), which zsh/bash evaluate as command substitution / hit parse
errors *before* `sbmjob` sees them (seen repeatedly, 2026-08-02). Write the
spec to a file with the Write tool, then submit with
`sbmjob "$(cat /tmp/thejob)"` — command-substitution output is
used literally and is NOT re-scanned for backticks. **Use the forwarder `sbmjob`
(PATH → `~/.local/bin/sbmjob`), NOT `~/.batchq/engine/sbmjob` and NOT a direct
file-drop into `<queue>/queue/` — post-homecore-migration those write to the
Mac's DEAD local queue and the job never runs** (seen 2026-08-05: a cross-domain
job stranded on the Mac's `~/.batchq/homelab/queue/`). Only drop a `.job` file
directly when you're on homecore itself. Editing a parked/queued `.job` file in
place (on the host that owns the queue) is safe — they're plain text, not running.

**Gotcha — when submission ORDER matters, pause 1s between submits.** The FIFO
drain orders by the `.job` filename's `<stamp>` (`YYYYMMDD-HHMMSS-slug`), which is
second-granular. Fire several `sbmjob`s in the same shell burst and they collide on
one timestamp → the worker picks among them in filesystem order, NOT submit order
(observed 2026-08-04: four c4-mcp jobs shared `122948`; the dependent job ran before
its prerequisite). When a later job depends on an earlier one landing first, `sleep 1`
between the submits so the stamps differ and FIFO holds. (Belt-and-suspenders even
so: write dependent jobs to be order-robust — "if the prereq isn't in your base yet,
build it yourself" — since same-queue jobs serialize with a merge between and a
truly independent stamp still can't guarantee which worker cycle grabs which.)

## Cross-domain requests (verify-first — ADR 0048 in fixer)

When any session touches, fixes, or discovers something in **another repo's
domain**, the delivery is a job on the OWNING repo's queue, not a HANDOFF.md
entry (HANDOFF.md survives only for repos with no registered queue — `ls
~/.batchq/` to check). The job runs inside the owning repo, so its own
CLAUDE.md/skills/memory make the judgment call the sender can't. Every such
spec begins with this preamble, verbatim:

```
CROSS-DOMAIN REQUEST from <sender CC> — VERIFY FIRST.
Before executing, check this against your domain's context (CLAUDE.md, skills,
memory, current state). Three outcomes:
1. Makes sense → execute it (or your domain's better variant; note the deviation).
2. Wrong or unnecessary here → no-op; record why in your job output.
3. Needs Doug (destructive / attended-only / policy) → do NOT execute; file a
   fixer issue with your recommendation, park attended work in your deferred
   register, and end the job clean.

What happened: <finding, in this domain's terms>
What we ask: <the concrete follow-up>
Refs: fixer issue #N, commits, log paths
```

- **FYI-only findings are still jobs**: "What we ask: verify whether this
  changes your docs/skills/memory; update if so, otherwise no-op."
- **Don't promise capabilities the owning queue forbids** (2026-08-14): a fixer
  job spec told the cruising queue "live boat access IS available" — but that
  queue's standing orders ban batch SSH to 192.168.22.x, so the job (correctly)
  declined those parts as outcome 3. Live-host / actuation work goes in the
  spec as "flag for interactive follow-up", not as an instruction; the sender
  can't waive the receiving queue's guardrails.
- **Escalation (outcome 3) is a fixer issue, never an MSGW hold** — MSGW is
  for broken jobs and blocks the queue; issues reach Doug via `/issue-review`
  (severity=info, send_notification=false — the ADR 0047 producer discipline).
  Attended boat work also goes in `fixer/docs/runbooks/stored-boat-plan.md`.
- **Jobs can't verify LAN endpoints** — the `tail.md` guardrail is localhost +
  Anthropic API only, so a job asked to confirm something on the LAN (a service
  on homecore, NetBox, another host) will correctly DECLINE rather than reach it.
  Put the verification *result* in the spec, or do the LAN check from an
  interactive/LAN session (cost two needless command-ce jobs, 2026-08-05).
- Submit per the inline-arg gotcha above: Write the spec to a file, then
  `sbmjob -q <owning-queue> "$(cat /tmp/spec)"` (the forwarder, NOT
  `~/.batchq/engine/sbmjob` — that strands the job on the Mac's dead local
  queue). No parallel HANDOFF entry — one fact, one home; JOBLOG.md is the record.

## Watching a queue as reviewer (wake-on-event)

After queuing, hand the watching to the queue: `sbmjob -watch &` (from the
session, with run_in_background). READ-ONLY; BLOCKS until the queue needs
you, then exits — waking the session. Wake conditions: **MSGW** · **held/**
· **DRAINED** · **heartbeat** (default 30 min). On every wake: act, then
RELAUNCH the watcher (one launch = one wake). It can only wake a LIVE
session; with no session alive, ntfy push covers the human directly.
Clearing a hold is a judgment call, never automated.

## Registering a new repo

```
# on homecore: clone the repo under ~/batchq-repos/ first, then
~/.batchq/engine/register.sh <name> </home/doug/batchq-repos/<repo>>
```
register.sh is OS-guarded: on homecore it links + `systemctl --user enable --now
batchq@<name>.path`. Queue names max 10 chars (`*JOBQ` limit; register.sh's
`set -eu` rejects longer — the grandfathered over-length queues `music-library`
/`voice-announce` were enabled directly with `systemctl --user enable --now`).
Then EDIT `~/.batchq/<name>/tail.md` (the repo's own hard guardrails) and
`next.md` (point at the repo's real backlog doc). Unregister on homecore:
`systemctl --user disable --now batchq@<name>.path`, delete the queue dir.

## Multi-job overnight builds → the `build-loop` skill

For a MILESTONE of coding (many dependent jobs verified against ADRs/specs,
unattended, with reviewer jobs + bounded hold recovery + self-chaining plans),
don't hand-roll it on raw sbmjob — use the **`build-loop`** universal skill
(piloted on dk-w5, 2026-08-09). This skill remains the chassis underneath.

## The working loop (how this is meant to be used)

1. **Strategy session** (interactive): triage, decide, frame — see the
   `strategy-session` skill. Its output is a stream of named self-contained
   jobs; it never waits for the queue.
2. The queue executes: fresh isolated sessions, worker merges + pushes,
   summaries into `JOBLOG.md`, ntfy on done/stuck.
3. Review = scan `JOBLOG.md` + `git log`, open a full log only on surprise.
   Decisions the jobs surfaced go back to step 1.
4. Engine changes: edit in `~/.batchq/engine`, run `tests/run-tests.sh`
   (scratch repo + fake claudes, no network), commit there. Never edit
   `worker.sh` in place while a drain is running — write aside and `mv`.

## Recovering a queue after a host crash / hard shed (learned 2026-08-10)

A killed worker (host wedge, `pkill claude`, reboot) leaves two messes the
watcher won't self-heal:
1. **A stale job stuck in `running/`** with a half-built worktree. Reset it:
   remove the worktree + branch, `mv running/<job> queue/<job>`, `rm -rf work/<job>`.
   FIFO stamps restore correct order automatically (a build's stamp < its review's).
2. **`systemctl --user start batchq@<q>.path` does NOT pick up pre-existing queue
   files** — inotify fires on new events only, and files that predate the watcher
   start are invisible. Re-trigger by touching the top job:
   `cd queue; F=$(ls|sort|head -1); mv "$F" "../$F.t" && mv "../$F.t" "$F"`.
   New jobs (fix pairs, next batch) trigger normally once the watcher is live.

Also: after a memory-pressure or PCIe-storm wedge, verify it was actually the
batch system before blaming `MAX_CONCURRENT` — the 2026-08-10 wedge was a faulty
Thunderbolt controller (fixer #1237), batch exonerated, cap restored to 6.

- **After a host-wide shed, re-enable EVERY watcher, not just the ones you're
  working on** (2026-08-11): a crash-recovery that does `systemctl --user stop
  batchq@*.path` must pair with re-enabling ALL of them on return — otherwise the
  queues you weren't focused on sit dark with jobs stranded (5 estate queues sat
  silent for hours after the 2026-08-10 wedge). Verify:
  `for u in $(systemctl --user list-unit-files 'batchq@*.path' -o json 2>/dev/null); do systemctl --user is-active "$u"; done`
  — any inactive one with a non-empty queue/ is stranded. Nudge each (inotify won't
  fire on pre-existing files).

- **Stale locks after a crash self-heal since 2026-08-15** (engine dfec97f;
  was fixer #1353 — a stale `worker.lock` blocked a queue ~3h, silently): the
  worker now breaks `worker.lock` and `global.lock.N` when the recorded holder
  PID is dead (mtime is the fallback), logs every no-op "another worker holds
  the lock" exit in worker.log, and a TERM trap releases locks on systemctl
  stop/restart. If a queue still won't drain, read worker.log — the reason is
  now always logged; manual `rmdir` is only for the rare PID-reuse case (a
  live unrelated process wearing the dead holder's pid, and lock mtime <3h).

- **A stopping worker strands its pre-claimed jobs in `running/`** (2026-08-14):
  with MAX_CONCURRENT>1 the worker can move several queue files into `running/`
  before a hold stops it. On the next start, the startup autopsy treats ALL of
  them as "stranded mid-job" → moves them to held/ + re-holds the queue, looping.
  Before `-release` after any hold-with-strandings: `mv running/*.job queue/`
  (they never executed — no worktree/log means never started), leave real crashed
  jobs (those WITH a worktree/log) for proper disposition.

## Traps for job authors (what kills a headless job)

- **NEVER background a long command and end the turn to "wait for the
  notification"** (2026-08-14, the HARDEN-conformance job): in an interactive
  session backgrounded Bash re-invokes you when it exits — in a headless batch
  job, ending your turn ENDS THE SESSION. The background child is orphaned, your
  edits sit uncommitted, and the queue takes a dirty hold. Long commands
  (test suites, builds) run FOREGROUND with an explicit generous `timeout`
  parameter. If a job legitimately needs to outlive a command, poll it in a loop
  — never yield the turn.
- Related session-side trap already recorded: `done/`-log-streams-live (reading a
  running job's log via `done/` path tails a live file — see Rules of the machine).
