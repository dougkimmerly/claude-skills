---
name: manual-review
description: Keep a user-facing manual coherent across many editing agents and over time. Use in TWO situations — (1) UPDATE mode, the frequent case: you just shipped or changed a user-facing feature and need to reflect it in the manual the way every other agent does, so the doc reads like one author; (2) REVIEW mode, the periodic case: a full multi-lens adversarial audit of the manual (coverage/currency, structure/addressability, the four real use-cases, format/PDF fidelity) producing a triaged fix list. Use for phrases like "update the manual for this feature", "does the manual need to change", "review the manual", "audit the docs before we ship", "is the manual still accurate", or "regenerate the manual PDF". Requires a thin per-repo config (manual file paths, PDF-build command, app feature surface, repo-specific gotchas) — see "Per-repo config" below.
---

# Manual review — keeping a user-facing manual coherent

A user manual written and maintained by many different agents over time drifts unless
every agent follows the *same* conventions. This skill is that shared discipline. It has
two modes:

- **MODE 1 — UPDATE** (use this constantly, every time a user-facing feature changes)
- **MODE 2 — REVIEW** (use this occasionally, as a periodic full audit)

Both modes share the same conventions — voice, anchors, single-sourcing, PDF regen — so
an UPDATE-mode edit and a REVIEW-mode fix look like they came from the same hand.

This skill is **repo-agnostic**. It assumes nothing about which app or which manual file
you're editing — those specifics come from a short **per-repo config** (see below) that
the calling repo supplies. If you can't find that config, stop and ask, or check the
repo's `CLAUDE.md` for a "Manual conventions" pointer before guessing at file paths.

---

## MODE 1 — UPDATE: reflect a feature change in the manual

Trigger: you (or the session you're in) just added, changed, or removed a user-facing
feature — a button, a workflow, a cost, a setting, a whole station/page. Before you
consider the work done, walk this checklist:

1. **Find the RIGHT existing section — don't scatter.** Read the manual's table of
   contents first. A new fact almost always belongs inside an existing section next to
   its siblings, not bolted on at the end or given a stray new heading. If you're
   tempted to create a new top-level section, check the per-repo feature surface first —
   is this really a new station/concept, or a detail of one that already exists?

2. **Write in the crew/owner voice — warm, plain, non-coder.** The reader owns the
   product; they didn't build it. Avoid engineering jargon, hedge words, and passive
   voice. Prefer short concrete sentences over qualifier-stacked ones.

   **Banned: the storm / heavy-weather trope.** Do not reach for storms, gales, heavy
   seas, or "when things get rough" as an example or metaphor in owner-facing docs, even
   as color. It reads as alarming rather than illustrative to someone who lives with the
   real thing. Reach instead for landfalls, anchorages, wildlife encounters, or food —
   "hunting for the clip where the dolphins showed up," not "hunting for footage from the
   30-knot squall." This rule survived a real review pass (a features example had to be
   rewritten from a heavy-weather scenario to a dolphins-at-anchor one) — it is not a
   theoretical nicety, apply it to every example you write or touch.

3. **Keep or add the section's stable `<h2>` kebab-case anchor id.** Every section that
   can be deep-linked, referenced from in-app help, or retrieved by a RAG/search feature
   needs a stable `id="some-section"` on its heading. If the section already has one,
   don't change it — in-app help, bookmarks, and any index that chunks the manual by
   `<h2>` depend on that id staying put. If you add a new section, give it one
   immediately; don't leave it to a later pass.

4. **Add an index entry.** If the manual has a back-of-book index or a generated table
   of contents / "I want to…" task table, add your new fact there too. A fact that exists
   in the body but not the index is invisible to anyone searching rather than reading
   linearly.

5. **Add a cost note if the feature spends money.** Anything that calls a paid API,
   burns bandwidth, or otherwise costs the owner money needs an honest, plain-language
   note near where it's described — not buried in a separate "costs" appendix nobody
   reads at the point of decision.

6. **Regenerate the PDF via the repo's builder — never a bare browser print.** The
   PDF is a build artifact, not a hand export. A page-numbered footer, a back-of-book
   index with real resolved page numbers, and front-matter contents all require the
   repo's real build command (see per-repo config below). A plain "print to PDF" from a
   browser silently produces a document with no page numbers, no working index, and a
   PDF that immediately drifts from the HTML source. **Always run the real builder after
   an edit and confirm it reports zero unresolved entries** — a build that logs "?" pages
   or missing phrases means your edit broke a resolver phrase match and needs a look.

7. **Single-source — content lives in the manual, not copied into app HTML.** If the
   app itself renders help text (an in-app help pane, a tooltip, an inline FAQ box),
   that surface should **link to or extract from** the manual, not carry its own copy of
   the prose. Two copies of the same fact drift the moment one of them is edited and the
   other isn't — decide which is canonical (almost always the manual) and make the other
   a pointer.

Do all seven before you call a feature "shipped with its docs." None of them are
optional busywork — skipping #3 or #6 breaks in-app help and RAG retrieval invisibly,
not loudly, so nobody notices until a much later review turns it up.

---

## MODE 2 — REVIEW: the periodic multi-lens audit

Trigger: a scheduled or pre-ship pass to catch what UPDATE-mode edits (spread across many
agents and sessions) let slip. This is heavier — budget real time for it, and prefer
running it as a **workflow** (parallel agents, one per lens) when the manual is large;
each lens is genuinely independent until the synthesis step.

### The 7 lenses

Run each as its own pass (or its own agent in a fan-out), each producing a list of
findings with a location and a one-line description:

1. **Content coverage** — does every feature in the app's current feature surface (per
   the repo config) have a manual section? Anything shipped-but-undocumented is a
   finding here.
2. **Content currency** — does every manual section still match how the feature actually
   behaves today? Screenshots, cost figures, button names, and workflow steps all rot as
   the app changes; check named specifics against the real running code/app, not memory
   of when they were written.
3. **Structure for humans + AI (addressability)** — is the manual organized so both a
   human skimming the table of contents AND a machine chunking it by heading can find
   the right section? Every section needs a real, unique, stable `<h2>` id; sections
   that are too long to be one retrievable chunk, or too fragmented to read as a coherent
   topic, are findings here.
4. **Use-case: human reading start-to-finish** — sit down and actually read it as a new
   owner would, front to back. Confusing ordering, unexplained jargon, and missing
   "why" context surface here — this lens catches what skimming for facts misses.
5. **Use-case: in-app inline/context help** — walk every page/pane of the app that links
   into the manual (a "Help for this page" button, a context panel) and confirm each one
   lands on the *right* section, not just *a* section. This is where pane-key collisions
   hide (see gotchas below).
6. **Use-case: reference / quick-find** — pretend you're the owner mid-task with one
   specific question ("how do I export a cutlist?"). Time how long it takes to find the
   answer via the index, the task table, and search/Ask-style retrieval if the repo has
   one. Slow or wrong answers are findings.
7. **Use-case: coherent learning document** — does the manual, read as a whole, teach a
   consistent mental model, or does it read as a patchwork of unrelated edits (different
   voices, inconsistent terminology, redundant sections covering the same ground
   differently)? This lens catches drift that no single-section check would surface.
8. **Format / style / PDF fidelity** — typography, heading hierarchy, and PDF-specific
   checks: page numbers present and correct, index page numbers resolve (no "?"), the
   PDF and the HTML source agree on every fact (see the drift gotcha below), and the
   voice/banned-trope rules from UPDATE mode #2 hold throughout, not just in new edits.

(Seven lenses named in the brief map to these eight checks — #3 "the 4 use-cases" is
listed as one lens with four sub-checks; split or merge however fits the manual's size.)

### Synthesis

Once all lenses report, **dedupe** — the same underlying problem often surfaces from two
lenses (a stale screenshot is both a currency finding and a use-case-1 finding) — then
**rank into three buckets**:

- **Before you send it (must-fix)** — anything that gives a wrong answer, breaks a link,
  breaks in-app help, or violates the banned-trope rule. Ship-blocking.
- **Quick wins** — small, obviously-correct fixes (a missing index entry, a jargon gloss,
  a stale figure) that cost minutes and improve the doc noticeably.
- **Bigger projects** — real restructuring, a new section, a rewritten flow — flag these
  for a follow-up pass rather than folding them into the current review's fix commit.

Fix the must-fixes and quick wins in this pass (following the UPDATE-mode checklist for
each fix — they're still edits, so they still need the anchor/index/voice/PDF discipline).
Log bigger projects wherever this repo tracks forward work (its roadmap/backlog), don't
just let them evaporate at the end of the review.

### Gotchas (load-bearing — hit for real on the first shard-editing run, 2026-07-23)

- **The no-storm-trope rule.** See UPDATE mode #2. It is easy to violate by accident
  when writing "realistic" examples — check every example sentence in the review, not
  just ones you're actively rewriting.
- **PDF ↔ HTML drift.** A shipped PDF can silently disagree with its HTML source (the
  first shard run found the PDF's billing/cost text out of date with the HTML after an
  edit that regenerated only one of the two). **Always regenerate the PDF as the very
  last step after any HTML edit**, even one that feels PDF-irrelevant — there is no way
  to know a PDF is stale except by rebuilding and diffing, and rebuilding is cheap.
- **The in-app "Help for This Page" pane-key trap.** Many apps route in-app help by a
  pane/view "key" that is coarser than the actual page — two different URLs or contexts
  can share one key (e.g. a generic "studio" pane serving both a home page and a
  file-management sub-page). If you route help purely by key, both pages get the *same*
  wrong help target. **Switch on the URL/path within the pane, not the key alone** —
  check the repo's actual routing code (per-repo config points at it) rather than
  assuming key-level routing is precise enough.
- **The `<h2>`-id/anchor discipline.** Losing or renaming an existing anchor breaks
  every deep link into it silently — in-app help, any generated index, and any RAG
  chunker keyed on it. Never rename an existing id as a drive-by cleanup.
- **Single-sourcing.** Re-check this in REVIEW mode even if UPDATE mode was followed
  faithfully — copies can appear from an agent that didn't know this skill existed, or
  from before the skill was adopted.
- **A manual is RAG substrate.** Once anything in the repo retrieves manual content for
  an AI-answered question feature, the manual's addressability (clean, uniquely-anchored,
  current chunks) directly determines answer quality. Structural sloppiness here isn't
  just a readability nit — it degrades a downstream feature that may not even exist yet
  when you're doing the review. Treat "would a chunker/retriever produce a clean, correct
  answer from this section alone" as a real review question, not a hypothetical.

---

## Per-repo config

This skill is shared across repos; each repo supplies a short, concrete config —
either inline in its `CLAUDE.md` or in a `docs/manual-conventions.md` this skill's
caller can find. At minimum it names:

- **Manual file path(s)** — the actual HTML/markdown source file(s) this skill edits.
- **PDF-build command** — the ONE real command that regenerates the shipped PDF (never
  substitute a bare browser print — see UPDATE mode #6). Different repos use different
  toolchains (a Python + headless-Chrome pipeline, a Node/puppeteer build, etc.) — use
  whatever that repo's actual builder is.
- **App feature surface** — where to check "does every feature have a section" against
  (a nav/menu structure, a routes file, a list of stations/pages).
- **Repo-specific gotchas** — anything like the pane-key trap above, but concretely
  named for that repo's actual routing code (a specific function/file), plus any other
  drift traps that repo has already hit once.

Read the calling repo's config before starting either mode — file paths, build commands,
and routing gotchas below are illustrative of the *kind* of thing to expect, not literal
paths to assume exist in every repo.
