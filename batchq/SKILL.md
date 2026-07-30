---
name: batchq
description: Doug's AS/400-style batch job queue for unattended Claude work (~/.batchq — one JOBQ per repo, launchd-fired worker, worktree-per-job, MSGW holds). Use when Doug says "queue that", "sbmjob", "add it to the jobq", "run it overnight/as a batch job", "check the queue", "what did the batch jobs do", or "set up a jobq for this repo". Jobs run in isolated git worktrees — interactive edits no longer race them.
---

# batchq — the batch job queue

One engine, one JOBQ per repo. Jobs are files; the OS (launchd `WatchPaths`)
fires the worker the moment one lands; the worker drains FIFO, running each job
as a **fresh headless `claude -p` session in its own git worktree** with the
queue's housekeeping tail welded on. The WORKER merges each job's branch into
main and pushes — jobs never push. No timers, no session needs to stay open.
Doug explicitly authorized `--dangerously-skip-permissions` for these jobs
(2026-07-20). Engine history + design rationale: `~/.batchq/engine/` is a git
repo — see its `DECISIONS.md` (v2 worktree rework, 2026-07-24).

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

**THE monitor is the web 5250 at http://localhost:8250/** (launchd KeepAlive
`com.batchq.wrkjobqweb`; reinstall with `wrkjobq --web --install`, run ad-hoc
with `wrkjobq --web [--port N] [--open]`). It speaks dk400's own screen
protocol — same terminal.css, 3270 font vendored — and auto-refreshes every
3 s without clobbering half-typed options. Screens: **WRKJOBQ** (queues:
5=Work with jobs, 6=Release, 8=JOBLOG) → **WRKJOBS** (jobs: 4=End queued,
5=Display log — LIVE follow while running, 8=Summary, 9=Resubmit) →
**SBMJOB** prompt on F10 (queue/pty/read-only/text). The `===>` line takes
`SBMJOB [-Q q] [-PTY n] [-RO] text`, `NEXT [q]`, `REL [q]`. Server binds
127.0.0.1 only; source `engine/wrkjobq_web.py` + `engine/web/`.

## Rules of the machine

- **Jobs run SONNET by default** (Doug 2026-07-30; engine commit that day). The
  worker resolves `--model` per call: `<queue>/model` file > `engine/model` file >
  `sonnet`. Jobs silently inherited the interactive default (fable) before —
  a 12-job day on the premium tier. The submitting session's stronger model does
  the reasoning IN THE SPEC; jobs execute cold on sonnet. Escalate a single job by
  writing the model name to `~/.batchq/<queue>/model` before submit and deleting
  it after — rare exception, never the norm.
- **Write jobs: one per queue, `MAX_CONCURRENT` Mac-wide** (global slots —
  different queues may overlap). RO jobs ride outside the slots, `RO_MAX` per
  queue. Lock-dir mtimes are heartbeats; stale-break only on genuinely old.
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
ROADMAP/ADR yourself" — so the fresh session needs nothing else. This
**named self-contained job is the default unit** (the retro's strongest
pattern: MON4, ETA-5c, VOY-START all one-shotted). `sbmjob -q <queue> "..."`
or drop a file in `<queue>/queue/` named `YYYYmmdd-HHMMSS-<slug>.job`
(`0N-` prefix = JOBPTY N; `.ro.job` = read-only).

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
~/.batchq/engine/register.sh <name> </path/to/repo>
```
Then EDIT `~/.batchq/<name>/tail.md` (the repo's own hard guardrails) and
`next.md` (point at the repo's real backlog doc). Unregister: `launchctl
bootout gui/$UID/com.batchq.<name>`, delete the plist + queue dir.

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
