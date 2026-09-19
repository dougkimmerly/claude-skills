---
name: housekeeping
description: "Tidy up a repo at the end of a working session — audit it against the governing standards repo (re-read, never remembered), verify the README is a current status page (proj- repos, ADR-0007), clear the HANDOFF inbox, land the knowledge into skills/memory/ADRs, and leave the tree clean. Use when Doug says housekeeping, tidy up, wrap up, clean up, or before handing a repo over."
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

- **Where artifacts live.** Anything extracted from a system, any source, any
  dated capture — is it in the knowledge-base repo rather than this one?
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

## 4. Land the knowledge

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

## 5. Check the docs against reality

Not a full audit — spot-check the claims this session touched:

- Numbers quoted in more than one file. **A number written twice drifts in one
  of them.** Prefer a pointer to the query; if it must be repeated, verify.
- Anything stated as "current" — is it still?
- Anything a session asserted without measuring. Say so explicitly in the doc
  rather than leaving it indistinguishable from a measured fact.

## 6. Leave the tree clean

- [ ] `git status` clean. Everything committed with a message explaining **why**,
      not just what.
- [ ] Nothing left half-built. If something is written but not deployed or
      compiled, the commit message says so and names what is needed to finish.
- [ ] Temporary artifacts removed — scratch tables, test members, debug output,
      stray files in `/tmp` that mattered.
- [ ] Credentials: if a temporary one was issued for this work and the work is
      done, it is revoked and removed from the secret store.
- [ ] Push if the repo has a remote.

## 7. Say what is still open

End with the short list of what the next session or Doug needs to pick up,
and be specific — a named command or file beats "finish the monitoring". If
something is blocked, say on what.

---

## Notes

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
