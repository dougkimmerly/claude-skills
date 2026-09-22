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
  index.md             # catalog: every page, one-line hook, by category — DERIVED (see rule 7)
  log.md               # append-only chronology: ## [YYYY-MM-DD] ingest|lint|refresh | title
  systems/<name>.md    # one entity page per system/paper/case: what it is, core model,
                       #   documented failure modes, sources
  concepts/<name>.md   # cross-cutting synthesis pages — where parallel lenses CONVERGE
  METHOD-NOTES.md      # process retrospective, written by the orchestrator at close
  review-findings.md   # only if the run includes an adversarial review of something
```

## The pipeline (founding run)

0. **Get the operator's ACCEPTANCE CRITERION before you write SCHEMA.** One
   question — *"what would make this a success for you?"* — and write the answer
   verbatim at the top of SCHEMA.md. Learned 2026-09-13 (fixer network-resiliency
   run): the run was half-done, four of six lenses finished, before Doug said
   *"I don't need a dashboard telling me what's not working, I need a systems
   operator that keeps things working"*. That single sentence reorganised the
   whole corpus around an autonomy ladder, invalidated the framing of every page
   already written, and cost a three-agent backfill pass to retrofit onto 48
   pages. "SCHEMA first" is right but incomplete: **requirement before schema.**
1. **SCHEMA.md first, before any fan-out.** Highest-leverage step: N writers produce
   one-author pages only if every prompt starts "first read SCHEMA.md". Include: page
   types, frontmatter (incl. `hook:` for the index and `verified:` for citations),
   naming, a controlled tag list, log-entry rules, and the bundling criterion for
   minor-entity pages.
2. **Per-lens fan-out, wiki-first.** Each lens runs research → completeness-critic →
   gap-fill, writing pages directly (raw notes → pages at most; NO monolithic
   intermediate report — the founding run's 5,800-line landscape.md was half-wasted).
   Critique-of-coverage is cheaper and more objective than critique-of-quality.
   **Set a thin-page prohibition, not a page-count target.** A count is a proxy
   for "no padding" and agents optimise the proxy: 2026-09-19 a lens correctly
   refused to merge 21 well-cited, non-padded, mutually-scoped pages down to a
   5–9 target, judging it would destroy evidence to satisfy a number. It was
   right. Say the thing the number stands for.
3. **Concept pass.** A planner names the convergence pages; writers fill them from the
   entity pages. This is where "three lenses found the same lesson" becomes one page
   instead of three duplicates.
4. **Lint — non-optional, budget for it.** Contradiction pass, structural pass,
   a **verdict-consistency pass** (new 2026-09-13: for each concept page, diff
   its verdict against the conclusion of every entity page it cites — synthesis
   can *lose* a finer judgement its own source made. A systems page had
   correctly concluded that abandoning Uptime Kuma was defensible because it is
   a notify-only tool; the concept page flattened that into a generic
   "we don't finish adoptions" pattern and the orchestrator repeated the
   flattened version to the operator, who corrected it. Disagreement between a
   concept verdict and its sources is either a finding or a flattening, and both
   need a human's eye), and a
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
   **The rule must bind SUB-agents too** (bosun assistants wiki, 2026-09-09): two of
   eight lenses spawned their own helpers, which wrote pages outside their scope.
   Both parents caught it and merged rather than leaving duplicates — but that was
   their diligence, not the design. Say in every prompt: *you may spawn helpers, but
   YOU are the only writer; helpers return text to you.*
   **AND SAY WHAT TO DO WHEN HAND-BACK IS UNAVAILABLE — the instruction alone is
   not enough** (proj-security `*ALLOBJ` run, 2026-09-19): a lens dispatched six
   forks which found `SubagentHandback` missing in their sub-sessions and wrote
   wiki pages directly, because writing was the only way not to lose the work.
   The instruction was in the prompt verbatim and the *mechanism* defeated it.
   Give helpers a scratch path the parent owns — `/tmp/<lens>/NN.md` — and have
   the parent merge. A rule with no fallback breaks under the one condition it
   was written for.
3. **Check the web-search budget BEFORE a fan-out.** It is a shared per-session
   resource (default 200 calls, `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION`) spent by
   the parent and every subagent, and it runs out **silently** — the first sign is a
   researcher mentioning it in passing, by which point the run is degraded. For a
   large run, start a fresh session. Note which lenses are search-independent
   (repos via `gh api`, video via `yt-dlp`) and schedule those first when it is
   scarce.
4. **Bulk payloads move between stages as FILES, never prompt-embedded JSON.** The
   founding run's one hard failure: a single merge agent fed 600KB inline died
   mid-stream and ~2M tokens went to verifying duplicates.
5. **No single agent ever holds the whole corpus.** Merge/dedup is a fan-out of small
   cluster editors (21 agents finished in 7 min what one agent died doing).
6. **Amend SCHEMA.md the moment an agent improvises around it** — improvised
   conventions left unrecorded become next batch's inconsistency.
7. **Derive index.md mechanically from page frontmatter (`hook:` field).** Hand-written
   index hooks are copies; in the founding run they rotted within one afternoon.
8. **Tier the MODEL per stage, explicitly — subagents inherit the parent model and
   that is how a run gets expensive by accident.** If you pass no `model` to the
   Agent tool, and no agent definition or `defaultSubagentModel` is configured,
   every subagent runs whatever the *parent session* is running. An Opus session
   therefore fans out Opus agents silently, and a wave of six parents that each
   spawn helpers is the bulk of a run's cost. Observed 2026-09-13 (fixer network-
   resiliency run): six estate-inventory lenses launched with no `model:` at all,
   inherited Opus, and Doug's reaction to the burn — *"that's why we are burning
   so many tokens"* — was the first anyone noticed. They happened to be the stage
   that deserved Opus; that was luck, not design. **Choose per stage and say so in
   the call:**

   | Stage | Model | Why |
   |---|---|---|
   | Index assembly from `hook:` frontmatter, link-depth lint, file splitting, block merges | **haiku** | genuinely mechanical |
   | External landscape/web survey lenses | **sonnet** | retrieval + summarisation against sources, and the citation lint catches fabrications whoever wrote them |
   | Research against the LIVE system (rules 10/11), concept/synthesis pass | **opus** | the value is judgment — live-vs-latent, spotting a check that passes vacuously, noticing the mechanism is real but has never fired. A cheaper model gets these confidently wrong and they enter the wiki as facts |
   | Citation-verification lint | **sonnet** minimum | a judgment task wearing a mechanical disguise |
   | Adversarial review / verifiers | **opus** | the pass exists to kill plausible-but-wrong findings; a weak skeptic here produces confident garbage that reaches an ADR |

   Corollary: **pause between waves.** If wave 1 (what we already have) shows the
   answer, wave 2 (what the world offers) gets much narrower — deciding that
   before spending is worth more than any model choice.

   **WAVE 1 IS ALWAYS THE LOCAL CORPUS, and the check costs one `ls`.** Promoted
   from corollary to rule 2026-09-19: a full landscape run for proj-security
   produced 32 pages and its decisive finding while spending **zero web
   searches**, because a 513-file Usenet archive and the IBM manual set were
   already on disk in a sibling repo. The estate accumulates corpora faster than
   anyone remembers — look before you search.
9. **Scale expectation:** the founding run — 155 pages, ~640 sources, full adversarial
   review — cost ~15M subagent tokens / 214 agents / ~3h20m. Scale lenses and review
   depth to the ask; a landscape-only run without review is roughly half.
10. **When the research serves a system that EXISTS, point every prompt at the running
    system, not only at the literature.** The highest-value finding of the bosun
    design review (2026-09-09) came from an agent told to check a design claim against
    the live database: the rule the entire autonomy model rests on turned out to be
    *unimplemented* — 13 audit rows across 60 records, none written by shipped code —
    which no amount of web research could have found. Give researchers the repo paths,
    the DB, the log files and the live hosts, and say explicitly that the design's own
    claims are hypotheses to be tested. Web-only prompts return what other people did;
    system-pointed prompts return what YOU did. Both matter, and the second is the one
    that changes the design.
11. **Run the thing if it can be run.** Same session: a test script that had been cited
    as evidence for a day could never have worked — it passed the server's flags to
    `docker run` and died on the first container. Two throwaway containers turned a
    desk-researched "yes, with conditions" into four observed failure modes, one of
    which (the documented recovery path silently discarding the backlog and reporting
    healthy) reversed a design decision. **An unrun test is not evidence.**
12. **Budget parent agents at about a third of the concurrency ceiling.** Prompts that
    permit helpers mean each parent may hold several slots; a 7-parent fan-out hit the
    20-subagent limit at 5. Launch in waves and fire the rest as capacity frees.
13. **Spot-check each returning agent's most checkable claim before folding it in** —
    a line count, a row count, a grep. It costs one command per agent, it caught a
    miscount in the founding-run era, and on 2026-09-09 it converted seven agent
    reports into findings safe to write into a design document. Verify the claims that
    would change a decision; ignore the rest.
    **When a spot-check PASSES, read the surrounding primary text anyway** —
    twice now that has yielded more than the check did. 2026-09-19: verifying
    "authority collection ignores special authorities" against the manual turned
    up two further exclusions in the same section that neither of two lenses had
    reported, one of which mattered more than the claim being checked.
14. **Make every agent separate the mechanism from the present tense.** The
    characteristic multi-agent error when researching a live system is being *right
    about the code and wrong about what is currently happening*: it happened twice in
    one session (2026-09-09), both times as "X renders/does Y **today**" where the
    mechanism was real but the symptom had never fired. Both would have entered a
    design document as live bugs. Require the distinction in the prompt — **live**
    (observed happening) vs **latent** (would happen; say what makes it fire) — and
    spot-check every "today" claim, because that is the word that carries the error.
15. **A new lens over an old corpus is a first-class run, and cheaper than new
    research.** 2026-09-09: six pages on interface over 46 system pages written
    months earlier for an entirely different question, with most of the evidence
    already sitting in them under other headings. What makes it work is not new
    sources but (a) a schema rule forcing every page to end in a **verdict** against
    a named principle rather than a summary, and (b) telling each lens to mine the
    existing pages before searching. Budget it as an ingest pass, not a founding run.
16. **Lint links by depth when the wiki has nested folders.** A `concepts/` page is
    one level deeper than a `systems/` page, and agents write the shallower path:
    12 broken links in two pages on the first nested run, all `../../` where
    `../../../` was needed. One shell loop over every relative link catches it.

## Standing watch (built 2026-09-11, adaptive 2026-09-12)

For subjects that keep publishing (a founder's channel, a live system's
write-ups), the reference wiki runs a watch list — `docs/research/WATCH.md`,
one row per page, kind `youtube-channel` or `web` — driven by
`scripts/research/wiki-watch.sh` from a daily homecore timer. Each row paces
itself from its own yield (new → halve the interval; nothing → lengthen ×1.5;
a failed fetch never lengthens and is logged as "could not reach"), per the
estate's measure-it-and-adjust principle. `wiki-watch.sh --status` shows the
per-row intervals. To watch something new: add a row. The ingest obeys the
scope test (design input, not a news scrapbook) and commits its own log entry.

## Fetching sources that block non-browser clients (learned 2026-09-11, Cerebras)

Some sites serve the full article with an HTTP 4xx/5xx to anything that is
not a browser; cerebras.ai returns the whole post under a 500, and the
Internet Archive holds the same block. WebFetch, curl and archive lookups all
report "unreachable" while the page renders fine in Chrome. **When a primary
returns an error or an empty shell, read it with the browser before writing
"primary unavailable":**

```
~/.venvs/wiki-watch/bin/python ~/Programming/dkSRC/w5/scripts/research/browser_fetch.py <URL>
```

(Playwright headless Chromium; prints readable text; exits 2 only when no
real content came back.) The same script runs on homecore inside the weekly
`wiki-watch.sh`. A page built from secondaries because the primary "failed"
imported invented mechanism detail once — the Cerebras security section —
and had to be rewritten.

**When `browser_fetch.py` ALSO fails, the answer may be "ask the operator", and
that is a legitimate move** (2026-09-20, `archive.midrange.com`). A
Cloudflare-style interstitial returns HTTP 403 whose *body* says "Performing
security verification". On that host **every automated route failed** —
WebFetch, curl, `browser_fetch.py`, and a Playwright browser driven
programmatically. Waiting did not help. **Doug cleared the bot check by hand in
the browser**, after which the session was trusted and the whole thread read
normally — and it produced the single most concrete artifact in a 50-page
corpus. A source worth thirty seconds of a human's time is cheaper than a page
built from secondaries: **surface it and ask, rather than recording
"unreachable" and moving on.**

Two things to carry:

- **Record the ACCESS ROUTE on the page, not just `verified:`.** Content got
  this way is properly verified, but the retrieval is not repeatable by an
  unattended agent — a later refresh pass needs to know to ask for a human
  rather than conclude the source rotted. "Human-in-the-loop only" is a
  distinct state from both "fetched" and "unreachable".
- **Do not infer the mechanism from the outcome — especially about your own
  tooling.** The first version of this note claimed the challenge "clears in
  ~30 seconds in an interactive session", inferred from a later navigation
  succeeding rather than observed, and the real cause was the human. Wrong
  access claims propagate into other people's ingest tooling; that one had
  already been delivered to a sibling repo before the operator corrected it.

And **do not assume the Internet Archive covers you** — for that list it held
the month and thread indexes but none of the individual messages, and was
itself returning "Temporarily Offline" at the time.

## Ingest-spec traps (paid for 2026-08-10, Cole Medin rounds 1–2)

- **Test the operator's ACTUAL hypothesis, not a proxy the convenient sources can
  answer.** "Has a logistics background" (bios can falsify) is not "has logistics
  exposure, e.g. consulting" (only content analysis can test — engagements never
  appear in bios). A falsified proxy recorded as a falsified hypothesis actively
  misleads later refreshes.
- **Operator testimony is admissible evidence when labeled and attributed.** Don't
  discard the observation that motivated the ingest.
- **"Written sources primary" systematically skips video-first creators' core
  corpus.** If the subject's main medium is video, budget for transcripts/
  descriptions/companion repos of the RELEVANT series — don't let source
  convenience redefine scope.

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

## Lint mechanics, paid for 2026-09-20 (proj-security wave 2 + four lint passes)

- **Run the verdict-consistency pass LAST, after fixes are applied — not alongside
  the other lints.** Its highest-value catch that day was an *incomplete fix by the
  orchestrator*: an authority-checking correction had landed on a page's `hook:` and
  not its body, and a concept page had inherited the stale half as its headline
  claim. That defect did not exist until fixes began, so a concurrent run would have
  missed it — and no other pass can find it, since the contradiction lint has already
  run, the citation lint checks sources rather than internal consistency, and the
  orchestrator is the one who introduced it. **A pass that audits the fixer is the
  point.**
- **Lints are REPORT-ONLY; the orchestrator is the sole applier.** Three passes read
  the same 32 files concurrently; had any been allowed to edit, the others would have
  been reporting against shifting text. It also puts every correction through one
  reader who can refuse one — and should. **A lint finding is a diagnosis, not a
  prescription:** one recommendation that day would have deleted a page's *evidence*
  along with the bad inference drawn from it. Keep the evidence, drop the inference.
- **For report-only agents, give NO output path — say "return your entire report as
  text".** The harness blocks subagent report-file writes; three of five agents were
  told to write `/tmp/lint-*/findings.md`, were blocked, and improvised. Same root
  cause as rule 2's hand-back fallback: *the prompt specified a mechanism the
  sub-session did not have.*
- **Lint scope = an explicit file list captured at dispatch, not a directory glob.**
  With waves running concurrently a glob silently under-covers: 17 pages written
  mid-run fell outside a citation lint whose mandate was drafted when the corpus was
  32 pages.
- **After correcting any number, grep the WHOLE corpus for the old value.** A
  fabricated figure propagates into synthesis faster than a lint cycle completes —
  one invented statistic had already reached two concept pages written from it hours
  earlier, whose author could not have known.
- **Lint the per-page verdict frontmatter separately, and expect the defects there.**
  Nearly every estate-level contradiction that day was in frontmatter, not body:
  corrections that reached the prose and never the verdict, a verdict explaining a
  599-population with a mechanism that explains 78, a vendor implied as deployed.
  **The verdict is written last, when the body already feels done, and it is the
  field most likely to be quoted.** Consider requiring it written FIRST.
- **Two independent passes converging is the strongest signal available.** A
  contradiction lint and a concept pass that never saw each other's output flagged
  the same four defects. Agreement across lenses beats confidence within one — and it
  is nearly free when both passes were going to run anyway.
- **Exhaustive citation checking is affordable, and the coverage number is itself a
  finding.** ~286 citations across 32 pages, every quoted string rather than a
  sample, cost one sonnet agent with five helpers. It found exactly one fabricated
  statistic and zero fabricated quotes — which tells you how far to trust the rest of
  the corpus. Sampling cannot tell you that.

## Orchestrator staleness is now the dominant defect class (2026-09-21, proj-security wave 3)

Across a 12-page wave with three lint passes, **every high-severity
contradiction finding was the orchestrator's, not an agent's.** The lenses
were fine. What broke was this: the orchestrator ran on-box measurements
*while the lenses were writing*, landed those facts in the project's own
files, and never went back to the pages drafted before they landed. The
contradiction lint then spent much of its budget rediscovering the
orchestrator's own edits — a page calling "confirm X" its cheapest, highest
value action when X had been measured that afternoon and filed as a finding.

Two cheap fixes:

- **Keep a running MEASUREMENTS list during the wave** — one line per thing
  you measured mid-run — and diff the corpus against it *before* dispatching
  lints. It converts a lint pass from rediscovery into real coverage.
- **When you redirect a lens's scope, you own confirming the destination
  accepted it.** In the same wave, two lenses each correctly decided port
  8478 belonged to a third page and handed it off; that page never claimed
  it. Good delegation on both sides produced a hole in the catalogue that
  only the lint found.

## A CORRECTION LANDS IN SIX PLACES, AND THE BANNER IS ONLY THE FIRST (2026-09-22)

The verdict-consistency pass on proj-security wave 3 found **six of twelve
protocol pages contradicting themselves** after the orchestrator applied
fixes. Not one was an agent error. The pattern was identical every time: the
correction went in as a `## 0.` banner or a section-level insert, read as
done, and never propagated.

**When you correct a page, the same correction must reach all six of:**

1. the body passage it corrects;
2. **every other passage on the same page that reasoned from the old fact** —
   usually §4 "our risk" and any conditional built on it;
3. the **verdict / "what we have"** section, which is where the old value
   most often survives as "UNKNOWN";
4. the **ordered action list**, where the now-answered item is frequently
   still ranked first and other items are *conditioned on it*;
5. the **"testable here" list**, which repeats the query you already ran;
6. the **frontmatter — `title`, `hook`, `verdict_for_xtl`** — which is written
   last, feels done, and is the field most likely to be quoted into a plan.
   One page had all three stale while its own §2 said RESOLVED.

And **sideways**: the sibling page covering the adjacent protocol, and any
concept page synthesised from the old text. In this run a concept page
carried a falsified statistic in bold, inherited from pre-lint source text,
and another filed a live candidate control under "controls that do not
exist" — which would have made a reader ranking work discard it.

**Cheapest mitigation:** after applying fixes, grep the corpus for the OLD
value and the old framing words ("unmeasured", "unconfirmed", "unknown",
"not yet run") before declaring the fix landed. That is a thirty-second check
that would have caught most of these.

## A RETRACTION THAT DOES NOT PROPAGATE CAN BE AMPLIFIED (2026-09-22, proj-security wave 4)

The six-places rule is not enough, because it is six places **per page**. In
wave 4 every correction the orchestrator applied landed in `systems/` and **not
one reached `concepts/`**. Three concept pages still carried retracted content
hours later, including a **fabricated** worked example presented as fact in the
section that named the concept, on a page whose title was built on that term.

The sharp part: one retracted claim had been **upgraded**. The entity page's
corrected text said "a market-leading SIEM's user community, on the public
record"; the concept page's *verdict* said "confirmed by the vendor's own staff
on the public record" — stronger than the source ever claimed. **A concept
writer works from pre-correction text and writes it more confidently than the
entity page did**, so a failed propagation does not merely persist, it hardens.

**Cheap fix: after correcting an entity page, immediately grep `concepts/` for
the retracted value.** Cheaper than the lint pass that found it, and concept
pages are what get quoted.

**And regenerate the index before the verdict pass, not after.** Deriving
`index.md` lays every `hook:` side by side, which surfaces a stale one in
seconds — the same wave had a hook still carrying an overbroad claim after the
title, the verdict and a body section saying "state this narrowly" had all been
fixed.

## A NEW FAILURE SHAPE: the quote is real and the authority is invented

Wave 4's citation lint (~272 citations, ~214 verified, 6 fabricated) found a
class worth naming separately. A community forum answer was cited as **"Splunk's
own staff"** in two independent pages. The quoted text was verbatim and correct.
The badge was a community engagement badge, not an employee marker.

**"Vendor staff confirms a flaw in their own product" is a disproportionately
attractive claim**, and it is the one most worth a badge-level check. Verifying
the quote is not verifying the authority.

**The mirror-image trap, same run:** three of four verification passes nearly
declared a genuine paper fabricated on a **title/abstract mismatch alone**. Full
text showed the quote present. And the orchestrator flagged an arXiv ID as
"implausible" — it was real, three weeks old, and the best-sourced citation in
the corpus. **Pull full text before concluding fabrication, and treat your own
suspicion as the weakest instrument in the pass.**

## ADD AN INTEROPERABILITY LENS WHEN THE SUBJECT EMITS DATA

Wave 4's five lenses asked *what does the world do*. The decisive answer came
from the operator mid-wave and was a different question: *what could we become
compatible with*. Checked at source, OCSF's `base_event` already defined
`count`/`start_time`/`end_time` — the aggregate record the project thought it
had invented — and left undefined exactly the one field it had added.

A lens asking **"how would our output be consumed by someone else's system"**
would have found that on day one. For any wave researching a thing that emits
data, make that its own lens.

## A RETRACTION needs the same evidentiary standard as an assertion (same run)

The orchestrator searched twice for a lens's central citation using semantic
search, did not find it, and **retracted the claim** — writing a correction
banner on the page and reporting the pull to the operator as a win for
rigour. The exhaustive citation pass then found the quote **verbatim, on the
originally-cited page**.

The lesson is not "trust agents more". The lens had over-reached: IBM
documented a security *benefit* and the page claimed *enforcement*. But the
correct move was to **narrow the claim, not kill it** — and to grep the
manual before pulling anything, because `ask_about_*` semantic search over a
manual corpus is a recall instrument, not an exhaustive one, and will miss a
sentence that a targeted grep finds immediately.

Practical: **feed the citation lint your RETRACTIONS as well as the agents'
assertions.** "Claims the orchestrator pulled — re-test these" is a distinct
input class and it caught a real error.

## Do not ship a metric written during the wave without measuring its value

Same run, a monitoring metric written mid-wave counted "installed products
IBM reports unsupported". Measured after the fact: **all 173 of them**,
because the OS itself was out of support. A constant that absorbs the change
it exists to detect — and the wave was *at that moment documenting* the same
defect in a different counter. Written, committed, and only caught because
the orchestrator happened to run the query an hour later.

**Any number a run produces as an instrument gets run once against reality
before it is committed.** The failure mode is not subtle and it is invisible
in review, because the SQL is correct.

## Skill maintenance

After each substantial run, fold that run's METHOD-NOTES lessons back into this file —
this skill is itself the compounding artifact for the process, as the wikis are for the
content.

## Tooling instructions must reach the HELPERS, not just the lens (2026-09-11, bosun EA run)

Rule 2 makes the single-writer rule bind sub-agents. **The browser fallback needs
the same treatment and did not get it.** Three lenses were each given
`browser_fetch.py` in their prompt. One of them spawned three helpers to do the
actual searching and synthesised their returns itself — correctly, per rule 2 —
but the helpers were never told the fallback existed. Their report came back
*"r/ExecutiveAssistants and equivalent forums were unreachable by every tool
across all three passes; WebFetch refuses reddit.com outright"*, and the page
shipped with the candid-practitioner layer recorded as a permanent gap.

It was reachable. `browser_fetch.py` returns **HTTP 200 and ~33k chars** on the
same URL, first try.

Two fixes, both cheap:
1. **Every prompt that permits helpers must say the helpers inherit the tooling** —
   name `browser_fetch.py` and require it be passed down, the same sentence that
   passes down the single-writer rule.
2. **"Unreachable" is a claim that needs the fallback tried**, exactly like a
   `verified` citation needs the primary opened. Reddit, Discourse forums,
   Substack, X and most JS-rendered sites refuse WebFetch and render fine in
   Chromium — that is the normal case, not an exception, so a lens reporting a
   whole source class as unreachable has almost certainly not tried it.

Generalisation worth holding: the parent obeys the process rules it is given and
then writes its own prompts for its helpers from scratch. Anything the run
depends on has to be stated as *"and tell your helpers this"*, or it stops at the
first generation.

## The estate already has a YouTube transcript tool — and it needs a cert on the Mac

Two traps in one, both hit 2026-09-12 researching a video-first builder.

**1. Look in `w5/scripts/research/` before installing anything.** It holds
`yt_packet.py` beside `browser_fetch.py` — the same directory this skill already
sends you to for the browser fallback. It builds a markdown packet of a
channel's videos (title, URL, description, **full auto-caption transcript**) from
the YouTube RSS feed, and `youtube_transcript_api` is already in the
`wiki-watch` venv. A session started `brew install yt-dlp` without opening the
folder it had been using all day.

```
~/.venvs/wiki-watch/bin/python w5/scripts/research/yt_packet.py <channel_id> <since_iso8601> <out.md>
```

Exit 3 means nothing new. It takes a **channel ID**, not an `@handle` — get it
from the page source (`curl -sL -A Mozilla/5.0 <channel-url> | grep -oE 'canonical[^>]*channel/UC[A-Za-z0-9_-]{22}'`).
The `"channelId"` fields scattered through the page belong to *other* channels;
the `canonical` link is the one.

**2. On the Mac it fails with `CERTIFICATE_VERIFY_FAILED`.** The venv is built on
the python.org framework build, which ships no system CA bundle — `wiki-watch.sh`
normally runs this on homecore, where it never bites. Point it at certifi:

```
CERT=$(~/.venvs/wiki-watch/bin/python -c "import certifi;print(certifi.where())")
SSL_CERT_FILE="$CERT" REQUESTS_CA_BUNDLE="$CERT" ~/.venvs/wiki-watch/bin/python …
```

Same fix applies to anything else in that venv that uses `urllib` or `requests`
from the Mac. `browser_fetch.py` is unaffected — Playwright carries its own trust
store, which is why it works and its neighbour does not.

## Go to the artifact, not the description of it (2026-09-12)

A video said *"I turned Obsidian into a life OS and gave it away."* The instinct
was to fetch the transcript. The description carried a GitHub link, and the repo
answered every question the transcript would have, better: the behavioural
contract the author wrote for his agent, the CI check that is the only thing
enforcing any of it, and — decisive — **three verbatim statements in the repo
that the contract "is a policy, not a technical guarantee."** No talk-track says
that as plainly as the source does.

So: **when a subject has published code, the repo is the primary and the video
is the index to it.** Read the description for links before queuing transcript
work. This also sidesteps the next item.

## YouTube rate-limits by IP, and it is silent until it is total

`youtube_transcript_api` raises `IpBlocked` after a burst — 15 transcripts in one
session was enough. It then fails for **every** video from that address,
including ones fetched fine minutes earlier. homecore shares the house IP, so it
is blocked too; the only genuinely different IPs in this estate are the boat's,
and spending a metered link on transcripts is not a fix.

Practical rules: **pull a channel's packet ONCE per session, early**, since one
call gets every video; expect the block to be sticky for hours; and when it hits,
`browser_fetch.py` still returns the page's **title, chapters and description**,
which is usually enough to decide whether the transcript was worth having.
