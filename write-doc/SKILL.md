---
name: write-doc
description: Use before authoring any persistent document — READMEs, runbooks, how-to guides, design notes, architecture docs, or any markdown captured to file. Forces identification of which of the four knowledge homes the content belongs in BEFORE writing, and catches common misclassifications like documenting volatile state in prose, duplicating facts across files, or authoring orphan docs in a reference store. Does NOT fire for answering questions in-conversation, for ADRs (use `adr` skill), or for code comments.
---

# Write Doc — which home does this belong in?

## Stop. Identify the home first.

Before drafting any persistent document, identify which of the four knowledge homes the content belongs in. Write to the wrong home and the doc will drift, mislead, or duplicate existing information.

## The four homes (quick reference)

| Home | For | Where |
|---|---|---|
| **Living** | Configuration, architecture, design rationale — things that evolve *with* code | Git, co-located with what it describes |
| **State** | What is happening or true *right now* | **Don't write.** Query the authoritative system. |
| **Reference** | Stable information with long shelf life | Document store, tagged for retrieval |
| **Experiential** | Lessons, rationale, rejected alternatives | ADR (`adr` skill), skill, or memory |

For depth on any of these, see the `knowledge-architecture` skill.

## Decision tree

```
Is this a description of a fact that may become untrue tomorrow
without anyone updating this file?
  └─ YES → STATE. Don't write the fact. Link to the query or dashboard.
  └─ NO → next

Is this the "why" of a significant choice?
  └─ YES → EXPERIENTIAL. Use the `adr` skill.
  └─ NO → next

Will this change alongside code in the same PRs?
  └─ YES → LIVING. Markdown in the repo, co-located with what it describes.
  └─ NO → next

Does it have a long shelf life and is mostly-static reference material
(manuals, specs, signed paperwork, photos)?
  └─ YES → REFERENCE. Put it in the document store.
  └─ NO → Reconsider whether it should be written at all.
```

## Anti-patterns to catch before writing

### Prose describing current state

- **Wrong:** "The auth database runs on the production host at `db:5432` using the `auth` schema with 12 GB allocated."
- **Right:** "Schema name is `auth`. See [inventory entry](link) for current host, port, and sizing."

The architectural fact (schema is named `auth`) is living. The physical facts (host, port, allocated size) are state — they will change without anyone remembering to update a doc sentence.

### Duplicated facts

Before writing "service X uses configuration Y," grep the repo for existing mentions. If the fact is already stated somewhere, **link** rather than repeat. If the existing statement is wrong, **fix it** — don't add a second, conflicting version.

### Narrative that should be an ADR

If you're writing "we considered A but chose B because…" in a README, stop. That's an ADR. Use the `adr` skill.

### Setup instructions that should be code

If the "doc" is a sequence of commands to run, consider whether it should be a script, compose file, or runbook yaml. Executable documentation doesn't rot the same way prose does.

### Authoring living docs directly into a reference store

Living docs need git history, review, and co-location with code. If you find yourself uploading a hand-written "how this works" doc into the document store, stop — it belongs in git. The reference store is for ingested material, not originated material.

## What each home's content should look like

**Living docs** (in-repo markdown):
- Architecture: components and how they fit together — *shape*, not current state.
- Design rationale too small for its own ADR.
- Runbooks: diagnostic steps and commands for operators.
- READMEs: what this is, how to get started, where to find more.

Actively avoid in living docs: "current status", "who's working on what", "today's deployment", anything timestamped or with volatile values embedded.

**Reference docs** (document store):
- Ingested originals — scanned PDFs, datasheets, received paperwork.
- Tagged with entity and category for retrieval.
- No live links to volatile systems.

**Experiential**:
- Significant decisions → ADRs (use `adr` skill).
- Reusable operational know-how → skills.
- Session-to-session context about user preferences and project state → memory files.

## The reread test

Before finishing any doc, re-read it and ask:
> "If I deleted every sentence that would need maintenance when something in the system changes, what's left?"

The remainder is the real content. Everything else is a future drift bug. Remove the drift bugs now, while it's easy, and replace them with links to state sources.
