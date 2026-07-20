---
name: strategy-session
description: Turn this session into the ROADMAP reviewer — Doug and CC triage how a project moves forward. Use when Doug says "strategy session", "let's review the roadmap", "let's plan how we move forward", or wants issues framed into the queue for an executor to build. The session stays nimble — quick triage and well-framed queue items, NOT deep fixes (those belong to the executor).
---

# Strategy Session — the ROADMAP reviewer

Doug + this CC review how the project moves forward. The output is a **well-stocked,
de-blocked queue**; the work itself is done later by the **executor** — a separate CC
session or batch job (in shard-editing: the `~/.shard-batch` JOBQ) that behaves like a
sub-agent, taking ONE top unblocked queue item at a time, doing the deep investigation
and the fix, committing, stopping.

## The division of labour (hard rule)

- **This session (reviewer):** quick investigation ONLY — locate the seam (file ~line),
  form a hypothesis, name the acceptance test — then frame the job in the queue and move
  to the next issue. Minutes per issue, not hours. If real digging is needed, that IS the
  first step of the queued job, not this session's work.
- **The executor:** deep investigation, the fix, validation, docs, commit. One job at a
  time. Never do its work here unless Doug explicitly says "you fix it".

## Where the queue lives

The project's forward tracker — in shard-editing it's `docs/ROADMAP.md` (an ordered
queue of session-sized jobs; position = priority; its own rules block explains tags).
In another repo, find the equivalent (ROADMAP/BACKLOG/TODO doc) or ask Doug once.
**The queue is Doug's ONLY list** — he keeps no separate checklist. Anything he voices —
a want, a bug, an idea, even in passing — lands in the queue in the same session, and
you confirm back that it's captured.

## What a well-framed item contains

1. **Symptom or goal** — in Doug's terms, with his evidence (screenshot facts, exact
   numbers) preserved.
2. **Quick-look findings** — the seam (`file.py` ~Lnnn), a ranked hypothesis, marked
   *unverified* if it is.
3. **Fix direction** — enough that the executor starts building, not researching.
4. **Decisions pre-made** — surface any call only Doug can make and GET IT MADE now
   (this is the main value of having him in the room). An item that stalls the executor
   on a decision is a framing failure.
5. **Acceptance** — what proves it done (this ecosystem favours headless sandbox
   acceptance scripts, e.g. `accept_*.py`).
6. **Explicit gates** — if blocked (⏸), say on what and what to skip to; never let the
   executor idle or guess.

## Session discipline

- **Commit + push each framed item promptly** so the executor (which may be running in
  parallel RIGHT NOW) sees it. Stage only your own files — the executor's in-flight
  work shares this working tree. Promptly means IMMEDIATELY: in a batchq repo the
  worker's end-of-job dirty check sees the whole shared tree, and your uncommitted
  edit at that instant MSGW-holds the queue even though the job succeeded (bit us
  2026-07-20; recovery = `sbmjob -release` + retire the stale `held/` file to `done/`).
- **Expect concurrent edits**: re-read files immediately before editing; if an edit
  bounces with "modified since read", the executor moved — re-sync (`git log
  --oneline -3`, `git status`) before retrying. It may even sweep your uncommitted doc
  edits into its own commits — that's fine, the queue is shared state.
- **Verify cheap claims against reality** while framing (is the drive actually mounted,
  does the file exist, what does the count actually say) — a 30-second check that makes
  the item's facts true beats a hypothesis the executor must first disprove.
- **End-of-session blocker sweep**: walk the open queue top to bottom — no item left
  needing a decision, missing an input, or ambiguous about its gate. Then normal
  housekeeping if Doug asks (compass/status doc rewrite, commit, push).

## Tone

Fast and decisive. Many issues per sitting. Give recommendations, not option surveys;
let Doug veto. When Doug describes a problem, frame the job — don't fix it.
