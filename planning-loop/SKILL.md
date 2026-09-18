---
name: planning-loop
description: "Run a plan through Doug's escalating adversarial review loop before committing to it — Odin (local) first on the unreviewed plan, then an independent Sonnet review of the same plan, an independent Sonnet merge, then Opus and Fable passes, each answering what it can and escalating what it cannot. Odin going first is deliberate: it makes the local model measurable against Sonnet on identical input. Use when a plan, roadmap, ADR or design is written and about to be acted on, and when Doug says 'run it through my planning loop', 'adversarial review this plan', 'review the roadmap before we build', or asks for a plan to be stress-tested. NOT for reviewing code (that is review-suite) and NOT the overnight build drain (that is build-loop, which can call this for its plan-review stage)."
---

# Planning loop — adversarial review before the build

A plan written by one session, reviewed by that same session, is a plan reviewed by its own
author. This loop puts **independent readers with different provenance** against it, in
increasing order of capability and cost, and shrinks the set of open decisions as it goes.

**The output is not "approved".** It is a revised plan plus an explicit list of decisions only
the owner can make. A loop that ends with zero open decisions has probably invented answers.

## When to run it

- A roadmap, ADR, design or implementation plan exists and work is about to start.
- The plan commits to something expensive to reverse (a runtime migration, a data model, an
  architecture).
- Doug asks for it by name.

**Do not** run it on a plan that is still a sketch — the loop finds gaps in reasoning, not
gaps in effort. Write the plan properly first.

## The stages

Run in order. Each stage produces a written artifact; do not collapse stages.

| # | Reviewer | Job | |
|---|---|---|---|
| 1 | **Odin** (local 70B) | Adversarial review of the **unreviewed** plan. First eyes, primed by nobody. | ⟵ run 1 and 2 |
| 2 | **Sonnet**, independent | Adversarial review of **the same unreviewed plan**, blind to Odin's findings. | ⟵ concurrently |
| 3 | **Sonnet**, independent | Merge BOTH reviews. Apply what is right, reject what is not (with reasons), leave **DECISIONS**. |
| 4 | **Opus** | Adversarial review of the merged plan. Resolve open DECISIONS it legitimately can. |
| 4a | **Opus**, independent | Merge stage 4. Separate agent from stage 4. |
| 5 | **Fable** | Final review. Audit whether earlier merges under-escalated. Find what everyone missed. |
| 5a | **Fable**, independent | Merge stage 5. Separate agent from stage 5. Produces the final plan. |

**Every review is followed by a merge, and the merge is never the same agent as the review** —
a reviewer that also merges protects its own findings, and findings that are never merged just
pile up with nobody deciding.

**Run stages 1 and 2 concurrently.** They are blind to each other by construction, so there is
no ordering dependency and it halves the wall-clock to the first merge. Launch both in one
message. Every later stage is strictly sequential — each merges what came before.

### Why this order

- **Odin goes first, and that is the point.** Stages 1 and 2 get the *identical* input, so the
  difference between them is a measurement of the local model rather than an impression.
  Running Odin late (the original design) asks it to find what better models already found —
  it will produce nothing, and you learn nothing about whether that is the model or the task.
  This is a real datapoint for the estate's "is local AI good enough yet" question, and it is
  free.
- **Independent means independent.** Stage 2 must not see stage 1's findings, or the comparison
  is worthless and Sonnet is merely grading Odin. Stage 3 must be a different agent from stage
  2: a reviewer that also merges will protect its own findings.
- **Escalating capability.** Cheap models find the obvious defects; spend the expensive
  reviewers on what survives.
- **Fable last** because it is the most capable and the most expensive. Give it the hardest
  residue — and explicitly the job of auditing whether the merge under-escalated, which is a
  failure mode the merge cannot self-detect.

### Scoring Odin (stage 1's second purpose)

After stage 2, compare the two reviews on the same plan and record:

- **Overlap** — findings both caught. This is the signal the local model is genuinely working.
- **Missed** — findings Sonnet caught and Odin did not.
- **Odin-only** — findings Odin caught first. Note whether they survived the merge.
- **Noise** — generic or ungrounded findings ("insufficient error handling" with no line quoted).

Write it into the stage artifact and, if the estate keeps a measurement record for the local
model, put the score there too. Track it over time: the interesting number is whether the gap
closes as models and the resident-model choice change.

**Watch for a rigged comparison.** Odin's context limit may force chunking or truncation while
Sonnet reads the whole plan. If so, they did not get the identical input — say so in the
artifact, and treat the score as indicative rather than clean.

## Running it

### Every stage but 1 — subagents

Use the Agent tool with an explicit `model` override (`sonnet`, `opus`, `fable`). Each stage gets:

- the plan file(s) **by path**, so it reads the current text rather than a summary
- the relevant ADRs / context files
- the stage's own instructions (below)
- for every merge stage: the review it is merging, plus the current plan and `DECISIONS.md`
- for stages 4 and 5: the prior merged plan (stage 2 excepted — it reviews blind)

A review and its merge must be **separate** agent invocations. Stage 2 must NOT be shown stage 1's findings.

### Stage 1 — Odin

Odin is not a subagent; call it directly on gpucore. It has no filesystem access, so the plan
must be pasted into the prompt:

```bash
curl -s http://192.168.20.20:11434/api/chat -d @- <<'JSON' | python3 -c 'import json,sys; print(json.load(sys.stdin)["message"]["content"])'
{"model":"llama3.3:70b","stream":false,
 "messages":[{"role":"system","content":"<stage instructions>"},
             {"role":"user","content":"<the plan + open decisions>"}]}
JSON
```

Watch the context budget: the service default is `num_ctx=8192` (see odin `models.md`). A long
plan plus instructions will silently truncate. Either pass a larger `options.num_ctx` **within
the VRAM budget** — the spill trap is real and `models.md` is binding — or give Odin one
section at a time. Say which you did in the artifact.

If Odin adds nothing, record that. A stage that contributes nothing is a finding about the
local model, not a failure of the loop.

## Stage instructions

**Stages 1 and 2 — adversarial review.** (Identical brief for both; that is what makes them comparable.) Attack it. Specifically hunt:
- assumptions stated as facts, and numbers resting on a single trial
- ordering errors — what must happen before what, and what is built before it is needed
- missing success criteria: how would we know this phase worked?
- unfalsifiable claims, and work with no stated cost
- what happens when it fails: rollback, blast radius
- scope that has quietly grown, and machinery built for a problem that may be removed
Rank findings by severity. Say which are blocking. No praise.

**Every merge stage (3, 4a, 5a).** Stage 3 takes BOTH reviews; 4a and 5a take their own tier's review. Apply findings that are right. Reject findings that are wrong, **with the
reason**. Where a finding raises a question only the owner can settle, do not guess — record it
under `DECISIONS` with the options and the trade-off. Produce the revised plan.

**Stages 4 and 5 — review, resolve, and audit.** Same as the review+merge brief against the current plan, plus: audit whether the merge UNDER-ESCALATED (decided something that turns on the owner's preference, money, time or taste), and
work through the open `DECISIONS` and answer every one you legitimately can from the plan,
the repo and the context. For each, say answered-or-escalated and why. Never resolve a decision
that turns on the owner's preference, risk appetite, money or taste.

## Output

Write artifacts under `docs/plan-review/<plan-name>/` in the repo that owns the plan:

```
01-odin-review.md     02-sonnet-review.md    <- concurrent, same input, blind to each other
03-sonnet-merge.md                           <- merges 01 + 02; creates DECISIONS.md
04-opus-review.md     04a-opus-merge.md
05-fable-review.md    05a-fable-merge.md     <- 05a holds the FINAL plan
DECISIONS.md                                 <- the live list; shrinks at every merge
```

Then update the plan itself and commit. The artifacts are the reasoning; the plan is the
product.

## Stop conditions

- **A stage finds a blocking flaw in the plan's premise** → stop the loop and take it to Doug.
  Do not merge a plan whose foundation is wrong; later stages will polish a bad design.
- **A merge changes nothing** → stop there. If 4a applied no findings and resolved no decisions,
  stage 5 will not either; running it is spend without yield. Note the exception: **never skip stage 1 to save time.**
  Odin is free, and skipping it forfeits the measurement that is half its purpose.
- **Decisions remain** → that is the expected ending. Present them to Doug as the deliverable.

## Verify claims against the world, not just against the document

**The findings that matter most come from outside the plan.** Across two runs of this loop, every
premise-level finding came from reading OTHER repos and checking whether an assertion was true —
not from internal coherence. Examples: a plan said "build on batchq" while batchq runs jobs as
cloud sessions; a purpose was named "cloud would price this out" when the owner's own recorded
run priced at $90; "the corpus is private" contradicted that domain's own history.

Internal review finds contradictions. Only external verification finds **false beliefs**, and
false beliefs are what get a plan superseded.

So: **stages 4 and 5 must be told explicitly to leave the document** — read the other repos, run
the arithmetic, check the claim. Give them the paths.

**The tension to manage:** stages 1 and 2 need identical, restricted input for the Odin score to
mean anything. That restriction is what stops them catching premise errors. Resolve it by
scoping narrowly for the comparison and widely afterwards — do not let the whole loop inherit
stage 1's context limit.

## Mistakes this loop is meant to catch

- The author reviewing their own work and finding it good.
- One-trial numbers hardening into facts through repetition across documents.
- Building machinery for contention a different decision would remove.
- A plan with no way to tell whether it worked.
