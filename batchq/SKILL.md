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
  engine/            worker.sh · sbmjob · wrkjobq.py · register.sh · defaults/
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
sbmjob -q <name> ...        # target a queue from anywhere
sbmjob -wrk                 # WRKJOBQ text view, all queues
sbmjob -whichq              # which queue does cwd resolve to?
sbmjob -release             # clear MSGW hold + restart that queue's worker
wrkjobq                     # 5250 green screen (F6=NEXT, F10=ad-hoc, 5=log,
                            #   4=cancel queued, F12=release); --once = snapshot
```

## Rules of the machine

- **One job running Mac-wide** (`engine/global.lock`) — queues wait their turn.
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

## Submitting from a session

When Doug decides something and says "queue it": write the decision INTO the
job text — context, the chosen option, acceptance criteria — so the fresh
session needs nothing else. `sbmjob -q <queue> "..."` or drop a file in
`<queue>/queue/` named `YYYYmmdd-HHMMSS-<slug>.job`.

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
2. `sbmjob NEXT` × N — spend the backlog.
3. The queue executes: fresh small sessions (survives slow Starlink),
   housekeeping welded on, MSGW on trouble.
4. Review: `wrkjobq`, `git log`, the repo's own docs — decisions the jobs
   surfaced go back to step 1.
