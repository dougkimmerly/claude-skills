---
name: handover
description: "Verify that a session with none of your context could actually take over — not that the repo is tidy, which is a different and shallower question. Derives the stale-document list from what you changed rather than from a typed checklist, confirms deliveries at the receiver, and checks the next session can still reach the systems it needs. Use when Doug asks 'is the next session set up', 'can I clear', 'are we ready to hand over', before /clear or /compact, and whenever you are about to say a piece of work is finished."
triggers:
  - is the next session set up
  - ready to hand over
  - can I clear
  - handover
  - prepare for a new session
location: global
---

# Handover — can the next session actually take over?

**Stands alone. It does not depend on anything else having been run**, and it
does not assume the repo has been tidied — Doug runs this and
[`housekeeping`](../housekeeping/SKILL.md) separately and in either order.

The question is: **could someone with none of today's context resume this work,
and would anything they read mislead them?** That is not the same question as
*is the repo tidy*, and a repo can pass one and fail the other.

---

## The failure this skill exists to stop

A session on 2026-09-24/25 was asked three times whether the next session was
set up. The first two answers were confident, evidenced, and at the wrong layer:

1. *"Yes"* — everything committed and pushed, log written, handoff updated.
   **True, and insufficient.**
2. *"Yes"* — after a full housekeeping audit: standards re-read, README
   corrected, open questions re-tested, knowledge landed in skills and an ADR.
   **Also true, also insufficient.**
3. The actual gap: **`RUNBOOK.md` — the file that says of itself "if anything
   here disagrees with another file in this folder, this file is right" — had
   zero mentions of the two procedures, the staging file and the new metrics
   created that week**, and its load-bearing table still described a member in
   the shape it had stopped having two days earlier. A session following the
   authoritative document would have copied the wrong pattern and believed it.
   Separately, **both credentials had an expiry date nobody had written down.**

**The lesson generalises:** the documents most likely to be stale are **the ones
that describe the thing you changed**, not the ones you were editing. Nothing
prompts you to open them, because you never opened them.

**If Doug asks the same question twice, you are at the wrong layer. Go down one,
do not elaborate.**

---

## 1. Derive the stale-document list — never type it

**This is the step that catches what the others miss, and it must come from the
diff, not from memory.** A typed list reports a pass on what it forgot.

```bash
# Everything this session touched, whatever "this session" means here
git diff --name-only <first-commit-of-session>^..HEAD
git log --oneline <first-commit-of-session>^..HEAD
```

Then — and this is the actual mechanic — **take the names of things you created
or changed and grep the whole repo for them.** Objects, procedures, files,
tables, jobs, functions, flags, endpoints:

```bash
grep -rn "NEWTHING\|RENAMEDTHING\|REMOVEDTHING" . --exclude-dir=.git
```

Every hit outside the files you edited is a document that describes your change
and does not know about it yet. Also run it **inverted**: grep for the thing you
*replaced*, and see who still describes the old shape.

Three places this reliably finds something:

- **The document that calls itself authoritative.** Runbooks, `CONVENTIONS.md`,
  "read this first" files. **These are the highest-risk stale documents**,
  because everything else defers to them and nobody re-reads them.
- **Tables and lists that classify things.** A member moved between categories,
  a service moved between hosts, a flag changed meaning. Prose survives a
  change; a classification table is silently wrong.
- **Any "how to add another one of these" instructions.** If you changed the
  pattern, the instructions now teach the old one.

**Correcting the copy you had open is not correcting the fact.**

## 2. Say what "normal" looks like, or the next session debugs a non-fault

If the system's healthy state includes something that **reads like a problem**,
write that down where they will look. Otherwise their first hour goes on it.

Real instance: a run-health view reports `ATTENTION` on the newest row **every
single run**, by construction — one component cannot observe itself and another
is deliberately retired. Without a sentence saying so, the next session opens
the health view and starts debugging the instrument.

Ask: *what will they see first, and will they read it correctly?*

## 3. Can they still reach the systems? — the operational layer

Documentation can be perfect and the session still blocked on minute one.
**Check the access path rather than assuming it, and re-derive the answer.**

- **Credentials: do they still work, and when do they expire?** Use one, now.
  Expiry is the one that bites, because nothing warns you. **Watch for settings
  where "inherit the default" and "never expires" are encoded identically** —
  on IBM i, `PASSWORD_EXPIRATION_INTERVAL = 0` means *inherit*, not *never*, and
  reading it wrong buys you a surprise lockout. Write the actual date down.
- **Lockout policy.** How many bad attempts before the account is disabled, and
  can it re-enable itself? If not, name who can.
- **Anything you left running.** Scheduled jobs, background work, queued items.
  Say what should happen next and how to tell whether it did.
- **Anything you left half-built.** Written but not deployed, deployed but not
  compiled, compiled but not scheduled. The commit message must say so and name
  what finishes it.
- **Deployed code: does the machine match the repo?** If the project has a
  verification script, run it and quote the result. If it does not, say that the
  claim is unverified rather than implying it was checked.

## 4. Confirm deliveries at the receiver, never at the sender

A cross-domain finding, a handoff entry, a queued job, a message to another
system — **your commit is not evidence it arrived.**

Re-read the receiving artifact and confirm your item is present. If it is
missing, re-deliver and say in the entry that it was lost once, so the receiver
does not read it as a duplicate.

Same discipline for anything the next session depends on that lives elsewhere:
if it is not confirmed where it lands, it is not delivered.

## 5. The one-screen brief

End with what the next session needs, in this shape. **Specific beats complete.**

- **What just happened** — one or two lines, and the current state of anything
  in flight.
- **What is normal that looks abnormal** (from step 2).
- **The next piece of work**, named concretely: the file to copy, the method to
  follow, the command to run. *"Convert `CD` and `CP`, `CAHARV` is the template,
  verify the mapping against the wrapper first"* beats *"continue the
  conversion"*.
- **What is blocked, and on whom** — separated from what is merely not started.
  These are not the same and conflating them misrepresents whose move it is.
- **What you did not verify.** The honest caveat is part of the handover. A
  judgement stated as a judgement is useful; a judgement that reads as a
  verification is a trap.

## 6. Sign off — the required last line

**The very last thing written to the terminal must be, on its own line:**

```
Handover complete now and ready to clear
```

Nothing after it — no trailing question, no offer of further work. Doug's
instruction, 2026-09-25.

**This line is a claim, and a bigger one than it looks.** It does not say *I
tidied up*; it says **the context in your head is no longer needed** — that
`/clear` is safe and nothing will be lost with it. So do not write it until
steps 1–5 have actually been done, in particular step 1, which is the one that
finds what the others miss.

**If you cannot honestly make that claim, do not write the line.** Say what is
missing instead, and what would let you write it. A handover that says "ready to
clear" while a stale authoritative document is still out there is worse than one
that admits the gap — Doug clears on the strength of this sentence.

---

## Notes

- **Separate from [`housekeeping`](../housekeeping/SKILL.md), and run
  separately** (Doug, 2026-09-25). Neither is a prerequisite for the other and
  there is no required order. They answer different questions: housekeeping
  asks *is this repo in good order* — standards, README, the open-questions
  register, knowledge landed in skills and ADRs. This asks *can someone else
  pick it up*. **Do not fold one into the other, and do not tell the reader to
  go and run the other one first.** If a step here overlaps, do it here
  regardless; a handover that depends on a separate skill having been run is
  exactly the fragile assumption this skill exists to catch.
- **"Set up properly" is a claim, so it decays like any other claim.** State it
  for the things you checked and name the things you did not. In the session
  above, each round of asking found something one layer down — the fourth
  answer said so explicitly and named where a gap would most likely be.
- **Do not turn a handover into a rewrite.** If a document needs restructuring,
  note it as open work. The job is to make the repo *true*, not better.
- **This applies mid-session too**, not only at the end — before `/clear`,
  before `/compact`, and before saying any piece of work is finished. "Finished"
  and "handed over" are different claims and the second is the one that matters
  to whoever comes next.
