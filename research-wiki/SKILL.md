---
name: research-wiki
description: Build large multi-agent research as a compounding wiki instead of a one-shot report — and maintain it as a living design input afterward. Use for ANY research effort big enough to fan out agents (landscape surveys, due diligence, design reviews against prior art, "what's out there that does X"), and for ingest/refresh passes on an existing research wiki. Encodes the hard-won process rules from the W5 founding review (2026-08-09: 214 agents, 155 pages, ~640 sources — reference instance at ~/Programming/dkSRC/w5/docs/research/, retrospective in its METHOD-NOTES.md). NOT for small lookups a few searches can answer; pairs with the deep-research plugin, which handles one-shot questions — this skill is for research that should compound.
---

# Research wiki — compounding multi-agent research

One-shot research reports get read once and rot. A research wiki — entity pages,
convergence-point concept pages, an index, a lint pass — is the coordination substrate
for a large agent fan-out AND a permanent asset later runs extend. The pattern is
Karpathy's llm-wiki applied to research corpora (its sweet spot: sources are immutable
reference; the wiki layer is synthesis, which is the product).

**Reference instance:** `~/Programming/dkSRC/w5/docs/research/` — read its `SCHEMA.md`
(content rules) and `METHOD-NOTES.md` (candid process retrospective) before running a
big one. This skill encodes those lessons; the instance shows them at full scale.

## Artifact layout

```
docs/research/
  SCHEMA.md            # page types, naming, frontmatter, citation rules — WRITE FIRST
  index.md             # catalog: every page, one-line hook, by category — DERIVED (see rule 6)
  log.md               # append-only chronology: ## [YYYY-MM-DD] ingest|lint|refresh | title
  systems/<name>.md    # one entity page per system/paper/case: what it is, core model,
                       #   documented failure modes, sources
  concepts/<name>.md   # cross-cutting synthesis pages — where parallel lenses CONVERGE
  METHOD-NOTES.md      # process retrospective, written by the orchestrator at close
  review-findings.md   # only if the run includes an adversarial review of something
```

## The pipeline (founding run)

1. **SCHEMA.md first, before any fan-out.** Highest-leverage step: N writers produce
   one-author pages only if every prompt starts "first read SCHEMA.md". Include: page
   types, frontmatter (incl. `hook:` for the index and `verified:` for citations),
   naming, a controlled tag list, log-entry rules, and the bundling criterion for
   minor-entity pages.
2. **Per-lens fan-out, wiki-first.** Each lens runs research → completeness-critic →
   gap-fill, writing pages directly (raw notes → pages at most; NO monolithic
   intermediate report — the founding run's 5,800-line landscape.md was half-wasted).
   Critique-of-coverage is cheaper and more objective than critique-of-quality.
3. **Concept pass.** A planner names the convergence pages; writers fill them from the
   entity pages. This is where "three lenses found the same lesson" becomes one page
   instead of three duplicates.
4. **Lint — non-optional, budget for it.** Contradiction pass, structural pass, and a
   **fetch-verified citation pass**: multi-agent web research produces confident
   fabricated quotes at a steady rate (~15 caught in the founding run, plus dead URLs
   and mis-scoped statistics — including citogenesis in the field's own most-cited
   numbers). Record per page which claims were fetch-verified vs researcher-asserted.
5. **Adversarial review** (if the research serves a design): finders work
   concepts-first (cheaper); every finding cites wiki pages, never restates them;
   per-finding verifiers get explicit refutation instructions **with a refutation
   quota** — require each verifier to state and rate the strongest refutation, and
   spot-audit verdicts with a second hostile verifier. Expect a nonzero kill rate;
   0-of-N-refuted means your skeptic bar was too low, not that everything was right.
   Data point (dk-w5 plan review, 2026-08-09): require-and-rate-the-refutation alone
   produced 3-of-24 WEAKENED but still 0 REFUTED — it moves verifiers off pure
   recalibration but doesn't produce kills when finders cite verified local text
   (source-grounded findings genuinely die less than web-sourced ones). Partial
   mitigation that worked: the orchestrator independently reads the core sources and
   pre-registers its own findings before seeing panel output, giving an external
   check on at least the top of the ranking. The second-hostile-verifier spot-audit
   remains untried; do it next run before concluding the bar is fine.
6. **METHOD-NOTES.md at close.** The orchestrator writes the candid retrospective —
   scale numbers, what worked, what fought, what to change — before the session ends.
   That knowledge exists nowhere else and is the input to improving this skill.

## Hard process rules (each one paid for)

1. **Failure-evidence-first doctrine in every research prompt:** "an entry without a
   documented weakness is unfinished research." Without it you get vendor brochures.
2. **One file per agent; single-writer files named in EVERY prompt** — non-owners get
   an explicit "do not touch index.md/log.md", not just the owner getting "you own it".
3. **Bulk payloads move between stages as FILES, never prompt-embedded JSON.** The
   founding run's one hard failure: a single merge agent fed 600KB inline died
   mid-stream and ~2M tokens went to verifying duplicates.
4. **No single agent ever holds the whole corpus.** Merge/dedup is a fan-out of small
   cluster editors (21 agents finished in 7 min what one agent died doing).
5. **Amend SCHEMA.md the moment an agent improvises around it** — improvised
   conventions left unrecorded become next batch's inconsistency.
6. **Derive index.md mechanically from page frontmatter (`hook:` field).** Hand-written
   index hooks are copies; in the founding run they rotted within one afternoon.
7. **Tier reasoning effort:** mechanical stages (splitting, index assembly, block
   merges) at low effort; research/verify stages at default or higher.
8. **Scale expectation:** the founding run — 155 pages, ~640 sources, full adversarial
   review — cost ~15M subagent tokens / 214 agents / ~3h20m. Scale lenses and review
   depth to the ask; a landscape-only run without review is roughly half.

## Living-wiki maintenance (after the founding run)

A research wiki is a permanent design input, not a review artifact — but unmaintained
corpora always rot (the wiki's own declared-metadata-rot lesson applies to itself).

- **Event-driven ingest** (primary mode): a newly discovered system/paper → one ingest
  pass: new/updated entity page, touched concept pages, lint over the touched set,
  log.md entry.
- **Periodic refresh** (~quarterly for fast-moving fields): sweep for new entrants AND
  re-verify the **load-bearing pages** — those cited by decisions/ADRs, flagged
  `load_bearing: true` in frontmatter (apply the flag at citation time; remove only
  when no decision cites the page). A refresh that finds a decision-relevant delta
  files a finding; findings can supersede decisions. The reference instance records
  this whole commitment as w5 ADR 0014 (its SCHEMA.md Conventions define the flag);
  a wiki that misses its refresh cadence is presumed decaying, like any unverified
  registry.
- **Scope test on every ingest:** does this bear on a decision the wiki serves? A
  research wiki is not a news scrapbook.
- Known-weak page classes to re-check first on refresh: empty-failure-cupboard pages
  (current-gen products with no track record yet) and vendor-sourced claims.

## Skill maintenance

After each substantial run, fold that run's METHOD-NOTES lessons back into this file —
this skill is itself the compounding artifact for the process, as the wikis are for the
content.
