---
name: housekeeping
description: "Tidy up a repo at the end of a working session — audit it against the governing standards repo (re-read, never remembered), verify the README is a current status page (proj- repos, ADR-0007), clear the HANDOFF inbox, re-test every open question in QUESTIONS.md — still worth asking, answerable by you now, and written in plain language the person waiting can actually answer, land the knowledge into skills/memory/ADRs, and leave the tree clean. Use when Doug says housekeeping, tidy up, wrap up, clean up, or before handing a repo over."
triggers:
  - housekeeping
  - tidy up
  - wrap up the repo
  - clean up the repo
location: global
---

# Housekeeping

Run at the end of a working session, or whenever Doug asks. The point is that
the **next** person — usually a future session with none of today's context —
can open the repo and know where things are without reading a transcript.

Work through it in order. Each step is cheap; skipping one is how a repo
becomes a thing only the last session understood.

---

## 1. Audit against the standards

**Only if this repo is governed by a standards repo.** Its `CLAUDE.md` says so
— XTL's `proj-` and `kb-` repos are governed by
`~/Programming/proj-01-standards`. If nothing governs this repo, skip to step 2.

**Do not work from a remembered list of standards. Read them now.**

```bash
cd ~/Programming/proj-01-standards && git pull -q
ls docs/adr/ && cat CONVENTIONS.md
git log --oneline -15 -- docs/adr/ CONVENTIONS.md     # what landed recently
cat HANDOFF.md                                        # PROPOSED standards live here
```

The list grows, and the ones added since this repo last tidied up are exactly
the ones it is failing. A standard nobody re-reads is a standard nobody applies.

**Read the standards repo's `HANDOFF.md` too, not only its ADRs.** A standard
proposed by one repo and adopted by Doug in conversation can be in force before
anyone writes the ADR — that is how `QUESTIONS.md` became binding on
2026-09-19 while the only written trace was a handoff entry. An audit that reads
only `docs/adr/` reports compliant and is wrong. If an entry there reads like a
standard, either apply it or ask whether it was adopted; do not assume the
absence of an ADR means the absence of a rule.

For each standard, answer one question: **does this repo comply, and how do I
know?** Then do one of three things, never nothing:

- [ ] **Complies** — move on. No note needed.
- [ ] **Does not comply** — fix it here if it is small (most are), or record it
      in `docs/log.md` as open work with what it needs. **Do not leave it
      unstated.**
- [ ] **Should not apply to this repo** — say so, in this repo, with the reason.
      A standard that genuinely does not fit is useful information about the
      standard.

**If you disagree with a standard, say so in `proj-01-standards`' `HANDOFF.md`
rather than quietly not applying it.** It is one ADR and it can be amended.
**A standard half-applied across five repos is worse than either outcome** —
nobody can tell whether a repo is non-compliant or deliberately excepted.

Things worth checking explicitly, because they are the ones that drift:

- **The spine (XTL `proj-` repos, ADR-0008).** Six required items, and it is a
  **minimum**: `README.md`, `CLAUDE.md`, `HANDOFF.md`, `QUESTIONS.md`,
  `docs/adr/`, `docs/log.md`. **Anything beyond them is the repo's own business
  and is NOT a deviation** — do not file an exception note for an extra
  directory, and do not create a directory to satisfy a checklist. Both
  happened: four repos filed careful exception notes for ordinary structure, and
  one carried an `evidence/` directory containing nothing but a README. (ADR-0008
  superseded ADR-0002 Part B on 2026-09-22; `deliverables/` and `evidence/` are
  gone from the spine.)
- **`HANDOFF.md` and `QUESTIONS.md` must exist even when empty.** A repo that
  deletes the file when it empties silently stops receiving.
- **Where artifacts live.** Anything extracted from a system, any source, any
  dated capture — is it in the knowledge-base repo rather than this one?
  Exception (ADR-0005, amended): where the source system itself hosts a
  version-controlled corpus, that corpus is canonical and the kb links to it.
- **Source in the repo, if any** (ADR-0008 §4). Code we wrote and deploy to the
  box is named for **what it installs as** (`secaudit/`, `mapcoll/`); `src/` is
  reserved for mod-marked working copies of someone else's source. Do not
  normalise one into the other.
- **Superseded documents.** Is the archive rule followed — moved, not
  banner-topped in place?
- **Repo naming and org.** Is it in the right GitHub organisation, named by
  type?
- **The README** — the most-failed one, and it gets its own step below.

## 2. The README (`proj-` repos: this is the big one)

**ADR-0007 in `proj-01-standards`: the README is a status page, not a log.**
Check all five, against the repo's actual current state, not against how the
file reads:

- [ ] **"Where things stand" is milestones, not events.** Which milestones has
      this project got to? Which are in flight, **at what percentage**, and
      **what is the remainder**? If the section is a dated list of things that
      happened, it is a log and it is in the wrong file.
- [ ] **Percentages are re-derived, not copied forward.** This is the claim
      that decays fastest and the only line saying *how far through we are*. If
      you cannot state a denominator, say so in the README — a project that
      cannot define "done" has a problem worth surfacing.
- [ ] **Plain language.** Written for someone who does not work on this. No
      unexpanded acronyms. A bare finding or ticket number is not a fact — say
      what it is, then reference it.
- [ ] **Every date is current or the line is deleted.** "Updated \<date\>" on a
      section nobody revisited is the exact failure the ADR exists to stop.
- [ ] **Every document mentioned is a link.** A broken link is visible; a stale
      filename is not.

Anything historical moves to **`docs/log.md`**, linked from the README. Move
it, do not summarise it away — the reasoning is why the log is worth having.

**Then check the shape, not just the rules** (ADR-0007 as amended 2026-09-22 —
there is a template at `proj-01-standards/templates/README-project.md`):

- [ ] **The eight sections, in order:** title + goal + access · `## Status`
      (milestone table + one bold **"The one number:"** line) · `## Now` ·
      `## Waiting on a person` · `## Traps` · `## Read` · `## Layout` ·
      `## At close`. Omit one only if genuinely empty.
- [ ] **No paragraph inside a table cell.** A cell is a label, not an argument.
      What-is-left cells cap at ~20 words and end in a link. This is the rule
      every repo broke — cells of 60, 110, 170 and 200 words were all found.
- [ ] **No "recent events" / "where things stand" narrative section.** That is
      the log wearing a status page's clothes, and it is how the original
      failure returns under a new heading.
- [ ] **It fits one or two screens, and no section but the milestone table grows
      with the project.** Checkable proxy: **~900 words + 25 per milestone**. A
      flat cap penalises a project for decomposing its work finely, which is why
      the constant became a rule.
- [ ] **Links resolve.** Check them mechanically, do not eyeball them.

**The no-status rule binds every OTHER document too.** If it is not the status
page, it carries no status claim — a "where we are" block in a research index or
a spec preamble is the worst case, because **a status claim rots fastest in the
document least likely to be re-read.** Spot-check one or two while you are here.

## 3. The HANDOFF inbox

`HANDOFF.md` at the repo root is an **inbox, not a log**. Read every entry.
For each: act on it, or consciously defer it and say where that is recorded.
Then **delete the handled entry and commit** — git holds the history.

Entries often contain a correction to something this repo asserts. Take those
seriously; a cross-repo correction is usually right, because the other side hit
the thing in practice.

If work here touched **another repo's domain**, deliver it before finishing —
a batchq job to that repo's queue, or an entry appended to its `HANDOFF.md`.
Check queues with `sbmjob -wrk`. An undelivered cross-domain finding is an
unfinished one.

## 4. Work the open questions — still worth asking, answerable by you, and askable in plain language

**Only if the repo has a `QUESTIONS.md`** (XTL `proj-` repos do — ADR-0009).
Read every open question and put each through three tests, in this order.
The third only applies to the ones that survive the first two.

**Test 1 — is it still the right question?** Sessions change the world. What it
blocks may have been resolved, superseded or descoped; the thing it asks about
may be dead; a decision may have made it moot. A register that accumulates
questions nobody re-reads is the same failure as a stale status page.

**Test 2 — can you answer it yourself, now?** This is the one that pays, and it
has to be asked fresh each time, because **two things change underneath a
question after it is written**:

- **What you can reach.** Authority gets granted, a credential is added, a
  library becomes readable. A question parked because "we lack the authority"
  is not re-tested when the authority arrives — nothing prompts it.
- **What you know how to ask.** The reason a question was left for a person is
  often an *assumption about your own limits*, written in a hurry, never
  revisited.

**The worked case this rule came from** (`proj-imaging`, 2026-09-23): a question
about which machines were connecting had sat for four days behind the sentence
*"IT can map an address to a machine in seconds; we cannot."* One view —
`QSYS2.NETSTAT_JOB_INFO`, which carries the remote address and the authenticated
profile **on the same row** — answered it outright, and named the single largest
consumer of the system as the application nobody had connected to the problem.
Nothing had blocked it but a sentence. A second row in the same question was
answerable by plain measurement: the feed had delivered nothing in five months,
which is the same test the project already used to retire two other feeds.

**So, for each question, do the work before deciding it needs a person.** Run
the query. Most "waiting on a person" rows have a measurable half and a
business half, and only the business half genuinely waits.

**Test 3 — if it survives 1 and 2, can it be asked in plainer language?** A
question that reaches a person and is still open is, by definition, one they
have not answered. Often that is because **it was written for you, not for
them.**

**The reader is whoever it waits on** — a director, a business owner, whoever
holds the decision. They do not know your table names, job names, profile names
or error codes, and a question built from them does not read as "hard", it reads
as **somebody else's problem, written in a language that says so.** It does not
come back as *"I don't know"*. It comes back as nothing, which is
indistinguishable from never having asked.

**The test to apply, literally:** could the person it waits on answer it
**without opening another file and without asking what a word means?** If not,
rewrite it.

- **Expanding an acronym is not removing jargon.** *"`XLIIMGGEN` (the Robot job
  that generates XLI documents) — retire or release?"* still asks them to hold
  a job name and a scheduler concept. *"XLI document capture stopped on 27
  August. Should it start again, or is it finished for good?"* asks the same
  thing and can be answered in four words.
- **Put the technical evidence where it belongs.** Keep it — it is what makes
  the answer trustworthy and it is why the row can be closed cleanly. But it
  goes in the evidence column. **The question itself is a sentence, in their
  vocabulary, about a decision they own.**
- **Name the consequence, not the mechanism.** Not *"step 8 disables this
  account"* but *"doing this stops documents being captured automatically —
  is that acceptable?"* People answer consequences; they defer mechanisms.
- **One decision per question.** If the plain-language version needs the word
  "and" twice, it is probably two questions, or the lettered-row form.

**Rewriting is not cosmetic and it is not optional.** A question that has sat
unanswered for days is evidence about the question at least as much as about
the person. Before chasing anyone, re-read what you actually sent them.

**Three disciplines when you do answer one:**

1. **An absence is not an answer until a control says the query can see a
   presence.** This matters most here, because the questions that survive
   longest are the ones about things that are missing. Ask the same question
   about something you *know* exists; if that also comes back empty, you have
   measured your own authority, not the world. On the same day as the case
   above, a profile lookup returned zero rows and nearly became "the account has
   no description" — it was an authority wall.
2. **Split what you answered from what is left.** Update the row to the
   genuinely remaining question rather than annotating it with findings; the
   register's one valuable property is being the *open* set.
3. **Follow the register's own rules on closing.** Under ADR-0009 that means:
   a fully answered row is **deleted**, its answer moves to the spec, the ADR or
   the log, and **the commit message names where it landed**. A question deleted
   without its answer going anywhere is the failure the register exists to stop.

**And if it still needs a person, say what you established anyway.** A narrowed
question gets answered faster: "which of these six profiles" is a better ask
than "what is this unidentified reader".

## 5. Land the knowledge

Ask the three questions, and act on the answers rather than noting them:

- **Did a skill help, and was any of it stale or missing?** Fix it now. A
  silently wrong skill misleads every future session.
- **Was anything learned today reusable?** If it will recur and is not obvious
  from the code, it belongs in a skill.
- **Was a non-trivial decision made?** It needs an ADR, or it will be silently
  reversed. Use the `adr` skill.
- **Anything about how Doug wants to work?** Memory, not a doc.

Rule of thumb from the global conventions: **every non-trivial fix updates
exactly one artifact.** If today produced fixes and no artifact changed,
something was not captured.

## 6. Check the docs against reality

Not a full audit — spot-check the claims this session touched:

- Numbers quoted in more than one file. **A number written twice drifts in one
  of them.** Prefer a pointer to the query; if it must be repeated, verify.
- **Anything corrected earlier in this session: grep the whole repo for it.**
  Correcting the copy you were looking at is not correcting the fact. On
  2026-09-22 a session fixed a false sentence in `proj-01-standards`' ADR-0003
  ("until cutover, the fused RAG keeps serving both tiers" — the cutover had run
  sixteen days earlier), and `kb-xtl400` had already fixed its own two copies.
  **A third copy sat in `docs/migration-map.md` and was found only by
  housekeeping** — in a working checklist nobody re-reads, which is precisely
  where a status claim survives longest. Grep the distinctive phrase, not the
  filename you remember.
- Anything stated as "current" — is it still?
- Anything a session asserted without measuring. Say so explicitly in the doc
  rather than leaving it indistinguishable from a measured fact.

## 7. Leave the tree clean

- [ ] `git status` clean. Everything committed with a message explaining **why**,
      not just what.
- [ ] Nothing left half-built. If something is written but not deployed or
      compiled, the commit message says so and names what is needed to finish.
- [ ] Temporary artifacts removed — scratch tables, test members, debug output,
      stray files in `/tmp` that mattered.
- [ ] Credentials: if a temporary one was issued for this work and the work is
      done, it is revoked and removed from the secret store.
- [ ] Push if the repo has a remote.

## 8. Say what is still open

End with the short list of what the next session or Doug needs to pick up,
and be specific — a named command or file beats "finish the monitoring". If
something is blocked, say on what.

---

## Notes

- **A question left for a person is a claim about your own limits, and it
  decays like any other claim.** Step 4 exists because that claim is never
  re-tested on its own — no hook fires when authority is granted or when you
  learn a better query. Housekeeping is the only place it gets re-asked.
- **Do not turn housekeeping into a rewrite.** The job is to make the repo
  true and findable, not to improve it. If a doc needs restructuring, note it
  as open work rather than doing it here.
- **Do not fabricate a percentage.** If the denominator is unknown, write that
  in the README. An invented number is worse than an admitted gap, because it
  stops anyone asking.
- **`kb-` repos are out of scope for the README step.** They are operated
  knowledge bases; their READMEs describe what the thing is and how to use it,
  and a milestone status page does not fit (ADR-0002 Part C). **They are still
  in scope for the standards audit** — the artifact-location and archive rules
  apply to them most of all.
- **The standards audit is a check, not a migration.** If compliance needs real
  work, record it as open rather than doing it inside housekeeping. The point
  is that nobody can later say the gap was unknown.
