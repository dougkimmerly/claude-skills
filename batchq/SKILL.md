---
name: batchq
description: Doug's AS/400-style batch job queue for unattended Claude work (~/.batchq — one JOBQ per repo, launchd-fired worker, MSGW holds). Use when Doug says "queue that", "sbmjob", "add it to the jobq", "run it overnight/as a batch job", "check the queue", "what did the batch jobs do", or "set up a jobq for this repo". Also read this BEFORE doing interactive work in a repo whose queue is ACTIVE — batch jobs and interactive edits share the working tree.
---

# batchq — the batch job queue

One engine, one JOBQ per repo. Jobs are files; the OS (launchd `WatchPaths`)
fires the worker the moment one lands; the worker drains FIFO, running each job
as a **fresh headless `claude -p` session** with the queue's housekeeping tail
welded on. No timers, no session needs to stay open. Doug explicitly authorized
`--dangerously-skip-permissions` for these jobs (2026-07-20).

**Never use in-session CronCreate for autonomy — proven to never fire on this
Mac (2026-07-20 canary test).** This queue is the replacement.

## Layout

```
~/.batchq/
  engine/            worker.sh · sbmjob · wrkjobq.py · register.sh · watch.sh · defaults/
  <queue>/           queue/ running/ done/ held/ config tail.md next.md MSGW?
```

`config` sets `REPO=` (and optionally `MAX_MIN=`, default 150-min job kill).
`tail.md` = the welded standing orders (one unit of work → validate → update
the repo's progress docs → COMMIT clean → exit; plus that repo's guardrails).
`next.md` = what a `NEXT` token means (where that repo's backlog lives — the
backlog itself stays in the repo; queue files are execution tokens only).
Registered queues: `shard` (physically `~/.shard-batch`, symlinked — legacy).

## Commands (also what Doug types)

```
sbmjob NEXT                 # queue "top unblocked backlog item" — cwd-resolved
sbmjob "free text job"      # ad-hoc job; the text becomes the session prompt
sbmjob -pty 1 "..."         # JOBPTY: expedite — runs BEFORE every normal job
                            #   (1 = most urgent; 1-9 all beat plain FIFO)
sbmjob -q <name> ...        # target a queue from anywhere
sbmjob -wrk                 # WRKJOBQ text view, all queues
sbmjob -whichq              # which queue does cwd resolve to?
sbmjob -watch [hb_s]        # reviewer wake-on-event: block until this queue needs
                            #   attention (MSGW/held/drained/heartbeat), then exit.
                            #   Run from a session with run_in_background.
sbmjob -release             # clear MSGW hold + restart that queue's worker
wrkjobq                     # 5250 green screen (F6=NEXT, F10=ad-hoc, 5=log,
                            #   4=cancel queued, F12=release); --once = snapshot
```

## Rules of the machine

- **One job running Mac-wide** (`engine/global.lock`) — queues wait their turn.
  Both locks are dirs whose mtime is a **heartbeat** (worker touches its queue
  lock every 15 s while a job runs or waits its turn — added 2026-07-20 after a
  healthy 3-hour drain read as a "stale lock" and a live job got falsely held
  as stranded); stale-break only fires when the mtime is genuinely old.
- **MSGW holds are per-queue**: a job that exits non-zero OR leaves the repo
  dirty moves to `held/`, the `MSGW` marker freezes that queue only. Read the
  marker + `done/<job>.log`, fix or decide, then `sbmjob -release` (resubmit
  the held job if it should retry). **Exception verdict:** exit 0 + the job's
  commit landed + tree dirty = a parallel interactive session's edits at the
  closing bell — the job counts DONE (no resubmit), the queue holds only to
  protect those edits; release once that session commits. The hold rule is
  deliberate — never "fix" it by exempting doc files (jobs commit those same
  files in housekeeping; an exemption would sweep the reviewer's drafts into
  a job commit).
- **Clean-repo gate both sides**: a job won't START if the repo is dirty
  (protects an interactive session's uncommitted work) and won't COUNT unless
  it committed. Corollary for interactive sessions: **don't edit a repo while
  its queue is ACTIVE** — your edits race the job's closing `git commit -A`.
  Check `sbmjob -wrk` first; queue your change as a job instead.
- **Interactive/reviewer sessions: COMMIT EARLY AND OFTEN.** Every stretch of
  uncommitted edits is a stretch where the queue is stalled (or holding a
  finished job's verdict hostage). Doc edits are cheap commits — commit after
  each decided item, don't batch an hour of triage into one commit. Every
  commit is a released queue. If you find the queue held with a
  "COMPLETED but tree is dirty" MSGW, the dirt is probably YOURS: commit it,
  then `sbmjob -release`.
- Job logs: `done/<job>.log` — **stream-json, filling LIVE while the job
  runs** (worker passes `--output-format stream-json`; a plain `claude -p`
  would buffer everything to the end and a running job would show nothing).
  Render them with `wrkjobq` option 5 (a RUNNING job's view is LIVE, follows
  the bottom) or in a terminal:
  `tail -f done/<job>.log | python3 ~/.batchq/engine/render_stream.py`.
  Pre-2026-07-20 logs are plain text; the renderer passes them through.
  Worker log: `<queue>/worker.log`.

## Changing the queue's world while it runs — expedite, don't pause

The reviewer session constantly makes decisions the queue must see (ROADMAP
edits, captured calls, reprioritized work) while a job holds the tree. The
default answer is a **priority job**, not a pause: write the full change into
a `sbmjob -pty 1 "..."` job — exact files, exact edits/decisions, commit
message — and move on. It jumps the FIFO (filename prefix `0N-` sorts before
any timestamp; the worker's plain `sort` does the rest), so the change lands
in its own fresh session before the next queued job runs — reorderings take
effect before the next NEXT fires. Priorities 1-9 all beat normal jobs and
rank among themselves. Reordering/cancelling **queued** jobs needs no job at
all: rename/delete files in `<queue>/queue/` directly — they're execution
tokens, not repo files (safe while a job runs; only don't race an idle
worker's pick).

## Needing the tree YOURSELF while the queue is ACTIVE (rare)

Only when the work is genuinely interactive — Doug iterating live, a server
restart to eyeball, anything a headless session can't do — pause deliberately:
write a note into `<queue>/MSGW` saying it's a deliberate pause (the running
job finishes and commits normally; the worker stops before taking the next).
Wait for `running/` to empty, do the interactive work, COMMIT, then
`sbmjob -release`. If a fire-and-forget `-pty 1` job could do it, use that
instead — pausing costs the whole wait; expediting costs nothing.

## Submitting from a session

When Doug decides something and says "queue it": write the decision INTO the
job text — context, the chosen option, acceptance criteria — so the fresh
session needs nothing else. `sbmjob -q <queue> "..."` or drop a file in
`<queue>/queue/` named `YYYYmmdd-HHMMSS-<slug>.job` (`0N-` prefix = JOBPTY N,
runs before all unprefixed jobs). Decisions that must land before the next
queued job runs → `-pty 1`.

## Watching a queue as reviewer (wake-on-event)

A reviewer/strategy session is interactive — it only wakes on a user message or when a
task it launched exits; it can't poll on its own (in-session cron is dead here). So after
you queue jobs, hand the watching to the queue's own hold signal: launch the **watcher**
in the background and let it wake you.

```
sbmjob -watch &        # from the session with run_in_background — cwd-resolved queue
# or: sbmjob -q <name> -watch 1800   ·   ~/.batchq/engine/watch.sh <queue> <heartbeat_s>
```

It is READ-ONLY (safe while jobs edit the tree) and BLOCKS until the queue needs you,
then exits — which wakes the session. Wake conditions:

- **MSGW** — a job errored / left the tree dirty and froze the queue. Read
  `held/<job>.log`, then fix + `sbmjob -release`, or escalate a genuine decision to Doug.
- **a job in `held/`** — same.
- **DRAINED** — every queued job finished. Review the commits (`git log`); if a big
  multi-step item stranded a later one, top up a `sbmjob NEXT`.
- **heartbeat** (default 30 min / 1800 s) — a liveness ping so a silently-dead watcher
  can't hide a stuck queue; just relaunch it.

**On every wake, act, then RELAUNCH the watcher** (one launch = one wake). It only detects
and wakes — clearing a hold is a judgment call, never automated.

**Limit + the cross-session escalation:** the watcher can only wake a session that is still
alive; it can't resurrect a closed one. A held queue is safe meanwhile — it just waits. For
notification with NO session alive (e.g. overnight), add a launchd `WatchPaths` agent on
`<queue>/held/` + the `MSGW` marker that fires a macOS notification / phone push (the same
mechanism the worker itself uses); build it per-need and scope it to NOTIFY only, never
auto-release. Optional refinement: a `tail.md` line telling a job that hits an ambiguous
requirement to write the QUESTION into a reviewer inbox (HANDOFF-style) before holding, so
you wake to the decision itself, not just a failure log.

## Registering a new repo

```
~/.batchq/engine/register.sh <name> </path/to/repo>
```
Then EDIT `~/.batchq/<name>/tail.md` (add the repo's own hard guardrails —
e.g. shard's "never rename .insv, FCP-gate") and `next.md` (point at the
repo's real backlog doc). Unregister: `launchctl bootout
gui/$UID/com.batchq.<name>`, delete the plist + queue dir.

## The working loop (how this is meant to be used)

1. **Strategy session** (interactive): triage, decide, frame work into the
   repo's ROADMAP/backlog — the thinking-between-jobs layer.
2. `sbmjob NEXT` × N — spend the backlog, then `sbmjob -watch &` so the queue
   wakes you on trouble/drain (see "Watching a queue" above).
3. The queue executes: fresh small sessions (survives slow Starlink),
   housekeeping welded on, MSGW on trouble.
4. Review: `wrkjobq`, `git log`, the repo's own docs — decisions the jobs
   surfaced go back to step 1.
