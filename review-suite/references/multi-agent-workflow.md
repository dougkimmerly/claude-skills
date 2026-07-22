# Multi-agent adversarial review workflow (L3 / L4)

The method behind a deep or ship-level review: fan out one reviewer per area, **adversarially
verify** every finding, synthesize a ranked punch list. Run it with the **Workflow tool** (Claude
Code's deterministic multi-agent orchestrator). Requires the user to have opted into workflow
orchestration (they asked for a deep/whole-repo review, or said "ultracode").

This is a **template to adapt**, not a fixed script — swap the AREAS list for the target repo, keep
the review→verify→synthesize shape.

## Shape

1. **Decompose** the codebase into ~8–14 **areas** (by subsystem, not by file). Each area names the
   real files it owns and any skill to load first.
2. **Review** (one agent per area): read the real code, check the real data (index/db/drive/fixture),
   return structured findings (file, line, severity, category, failure_scenario, fix_direction).
3. **Verify** (adversarial, per finding — *pipeline*, no barrier): an independent skeptic tries to
   **refute** each finding against the real code/data; default to not-a-defect unless it concretely
   reproduces. For highest stakes, use ≥3 distinct-lens skeptics and require a majority.
4. **Synthesize**: dedupe, keep only confirmed, rank blocker→low, return the punch list.

## Key choices that make it trustworthy

- **Give every reviewer the shared rules** of the codebase (its invariants, its data-safety rules,
  its offline-first contract) + where the **real data** lives, and tell them to **verify against it**,
  read-only. A finding checked against reality beats a hypothesis.
- **Adversarial verify is non-optional.** It's what removes plausible-but-wrong findings. Prompt the
  skeptic to REFUTE, not to confirm — a **separate** agent, never the finder self-checking.
- **Debias the prompts (research-backed).** Tell every reviewer + verifier to judge the code **on its
  own merits** — ignore reassuring comments, the PR/commit description, and benign-looking names;
  verify what the code *does*, and treat a "this is safe / can't happen" comment as a place to look
  harder. Framing defeats autonomous LLM reviewers up to **88%** of the time; explicit debiasing
  restores detection to **~94%**. Put this line in `CTX`.
- **Verify in a pipeline**, not after a barrier — each area's findings verify as soon as that area
  finishes, so fast areas don't wait on the slowest.
- **Severity comes from the verifier**, not the finder (finders over-rate).
- **Scale to the ask**: a few areas + single-vote verify for "any bugs?"; all areas + 3-vote
  adversarial + synthesis for "audit this before we ship."
- **Model & reasoning — tier it, don't leave to inheritance (see SKILL.md "Model & reasoning").** A
  review is the highest-stakes reasoning task, but your best model may be scarce (Fable has a limited
  weekly bucket), so aim it where it counts:
  - Area **reviewers** → **Opus**, `effort: 'high'` (plentiful; surfaces candidates across the whole repo).
  - Adversarial **verifiers** + **data-safety/security/irreversible** areas → **Fable**,
    `effort: 'high'` (or `'max'`/ultrathink) — highest leverage, lower volume. Set per-agent
    `model: 'fable'` on those `agent()` calls.
  - **Don't** run a whole 30+-agent fan-out on Fable — it burns the bucket. Alternatively: all-Opus,
    then a short **Fable second-opinion pass on the confirmed high/blocker findings**.
  - Mechanical **fixes** → Sonnet. Agents inherit the orchestrator's model unless a per-agent
    `model` is set.

## Skeleton (adapt AREAS + paths)

```js
export const meta = {
  name: 'full-app-review',
  description: 'Deep multi-area adversarial code review → ranked punch list',
  phases: [{ title: 'Review' }, { title: 'Verify' }, { title: 'Synthesize' }],
}

const CTX = `<<the target repo's shared rules + invariants + where the REAL data lives (db/drive/
fixture) + the priority order: correctness > data-safety > offline/resilience > perf. Tell agents
to check against real data read-only, never mutate, report file:line + a concrete failure scenario,
skip style nits, load the named skill for their area first.>>`

const AREAS = [
  { key: 'subsystem-a', skill: 'some-skill', files: 'tools/a.py, tools/b.py', focus: '...' },
  // ... 8–14 areas, one per subsystem
]

const FIND_SCHEMA = { /* area, clean, notes, findings[]: {file,line,severity,category,summary,
                         failure_scenario, offline_relevant, fix_direction} */ }
const VERDICT_SCHEMA = { /* real, confidence, reasoning, corrected_severity */ }
const sev = { blocker: 0, high: 1, medium: 2, low: 3 }

phase('Review')
const perArea = await pipeline(
  AREAS,
  a => agent(`${CTX}\n\nAREA ${a.key}\n` + (a.skill ? `Load the \`${a.skill}\` skill first.\n` : '')
      + `Files: ${a.files}\nFocus: ${a.focus}\nReturn genuine defects with file:line + failure scenario.`,
      { label: `review:${a.key}`, phase: 'Review', agentType: 'general-purpose', schema: FIND_SCHEMA }),
  (review, a) => {
    if (!review?.findings?.length) return { area: a.key, confirmed: [] }
    return parallel(review.findings.map(f => () =>
      agent(`${CTX}\n\nAdversarially REFUTE this (area ${a.key}). Read ${f.file}:${f.line} + real data.`
          + ` Default real=false unless it concretely reproduces.\nCLAIM: ${f.summary}\nSCENARIO: ${f.failure_scenario}`,
          { label: `verify:${a.key}`, phase: 'Verify', agentType: 'general-purpose', schema: VERDICT_SCHEMA })
        .then(v => ({ ...f, area: a.key, verdict: v }))))
      .then(vs => ({ area: a.key, confirmed: vs.filter(Boolean)
        .filter(x => x.verdict?.real && x.verdict.corrected_severity !== 'not-a-defect') }))
  }
)

phase('Synthesize')
const confirmed = perArea.filter(Boolean).flatMap(r => r.confirmed || [])
const seen = new Set()
const ranked = confirmed
  .filter(f => { const k = `${f.file}::${f.summary}`; if (seen.has(k)) return false; seen.add(k); return true })
  .sort((x, y) => (sev[x.verdict.corrected_severity] ?? 9) - (sev[y.verdict.corrected_severity] ?? 9))
return { confirmed_count: ranked.length, punch_list: ranked }
```

## After it returns

- Write the punch list into the project's tracker (ROADMAP / issues) as ranked items.
- Split **fix-now** (mechanical/safe/testable — proceed) vs **hold** (judgment/design/irreversible
  — surface for the human). Re-verify every fix on the real path.
- For L4, run this over the **whole** codebase, then also run the **doc-conformance** variant: same
  shape, but each agent reviews the code against an ADR / manual / skill / plan and classifies each
  drift as **fix-code** vs **fix-doc**.

## Notes / gotchas

- Scripts are plain JS; `Date.now()`/`Math.random()` are unavailable in workflow scripts.
- `agentType: 'general-purpose'` gives agents Bash/Read/Grep to check real data + load skills.
- The workflow runs in the background and notifies on completion; its result is the punch list.
- Cost scales with area count × findings — fine for an audit, but say so if you cap coverage.
