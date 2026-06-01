---
name: ask-dsii
description: Ask DSII — the boat's natural-language Q&A app. Use when working on the chat UI at /ask, the orchestrator (cruising-app/app/routes/ask.js), the boat-cruising/boat-signalk MCP tools that back it, or the feedback-driven iteration loop where Doug + Claude review thumbs-down answers and write new MCP tools. Also use when diagnosing "I can't access X" answers — they're frequently model hallucinations rather than real auth/network failures.
---

# Ask DSII

The boat's natural-language Q&A app, served from the cruising-app hub at `http://192.168.22.15:3200/ask`. Take a question in plain English, get a sourced answer about the boat — equipment, voyages, port visits, manuals, fuel/water, anchorage, weather, contacts.

## Where it lives

| Piece | Path |
|---|---|
| UI | `cruising-app/app/web/public/ask.html` |
| Orchestrator | `cruising-app/app/routes/ask.js` (Anthropic tool-use loop) |
| Q&A log + threads | `cruising.ask_log` (`schema/032-ask-log.sql`, `033-ask-feedback-notes.sql`, `042-ask-thread.sql`) |
| Tools — boat data | `cruising-app/mcp/tools/*.js` (boat-cruising MCP — find_jobs, find_equipment, search_docs, read_doc, vessel_info, find_voyages, …) |
| Tools — live boat | `~/Programming/dkSRC/boat/boat-mcp/server.js` (boat-signalk MCP — vessel_snapshot, switch_circuit, get_alarms, …) |
| Imaging RAG backing search_docs/read_doc | `imaging-service/lib/rag.js` reached via `imagingFetch` in `cruising-app/mcp/server.js` |

## Architecture flow

```
User → POST /api/ask {question}
     → cruising-app/app/routes/ask.js
        - claude-haiku-4-5 (process.env.ASK_MODEL), max 8 turns
        - Tool list comes from MCPs in MCP_SERVERS array (boat-signalk, boat-cruising)
        - On each tool call, the MCP runs the tool; results stream back to Haiku
     → Tools reach cruising DB / SignalK / imaging:3100
     → Final answer + citations written to cruising.ask_log
```

`cruising-app/mcp/server.js` builds the shared tool-context (`ctx`):

```js
const ctx = { pool, skFetch, cruisingFetch, imagingFetch, imagingBase: IMAGING_URL };
```

`imagingFetch` honors `IMAGING_AUTH_TOKEN` env (Bearer header) — falls back to no auth, relying on imaging's `AUTH_LOCAL_SUBNETS` bypass (`192.168.22.,172.`).

## Iteration workflow ("fine-tuning")

There is no autonomous tool-writer agent — the loop is **Doug + Claude in a Claude Code session**, working from `ask_log` feedback. The cadence shows up in commits like *"Round of fixes from May 1 feedback batch"*.

1. Use Ask DSII; thumbs-down (-1) any answer that's wrong, missing, or shows the agent guessing. Add `feedback_notes` to explain what was missing.
2. Open Claude Code in `cruising-app`. Pull the negative feedback:
   ```sql
   SELECT id, question, answer, feedback_notes, tools_used
   FROM cruising.ask_log
   WHERE feedback = -1 AND asked_at > now() - interval '2 weeks'
   ORDER BY asked_at DESC;
   ```
3. For each, look at `tools_used` vs. what would have answered it. Three usual fixes:
   - **Tool surfaced wrong rows** → tweak the tool's SQL (relevance ranking, filtering, joins). Most "I couldn't find" cases land here.
   - **No tool covers this** → add `cruising-app/mcp/tools/<name>.js`. Exports `{ name, description, input_schema, async handler(args, ctx) }`. Restart the boat-cruising-mcp container.
   - **Tool worked but Haiku didn't pick it** → tighten the tool's `description`. Haiku is *description-driven* for tool selection — vague descriptions get skipped.
4. Re-ask the same question. If the new answer is good, commit. Reference the feedback batch in the message.

Tool collisions: `ask.js` order is local-first, then MCPs in `MCP_SERVERS` order. Earlier wins. Name new tools to avoid clashing.

## Common failure modes

### "I can't access the manuals" / "401 from imaging service"

These answers are *frequently hallucinated*. Haiku will sometimes invent a plausible-sounding error rather than say "I don't know." Always verify before fixing infrastructure:

```sql
SELECT id, question, answer, tools_used, error
FROM cruising.ask_log
WHERE id = <id>;
```

- If `tools_used` shows `search_docs`/`read_doc` returned an actual error → real failure, debug below.
- If `tools_used` shows the tool ran, returned content, AND the answer claims auth failure → **hallucination**. Fix is a prompt/description tweak, not infra.

### Real 401 from imaging (when the tool truly errored)

`imagingFetch` in `cruising-app/mcp/server.js` returns the response body verbatim on failure. If `tools_used[i].error` literally contains `401: {"error":"Authentication required"}`, then both auth paths failed — bypass AND bearer.

Both paths must be checked because either alone is enough to succeed:

**(a) Token mismatch — most common, especially after a rotation.**
The MCP's bearer is sourced from `cruising-app/app/.env`'s `IMAGING_AUTH_TOKEN` (the `mcp/.env` is a symlink to that file). Imaging's accepted token is `AUTH_OWNER_TOKEN` in `imaging-service/.env`. After rotating the imaging side, *also* update cruising-app's .env and restart `boat-cruising-mcp` and `cruising-app`. Compare last 12 chars only — never echo full tokens:
```bash
ssh doug@192.168.22.15 'echo "imaging:  $(grep ^AUTH_OWNER_TOKEN= /opt/dk400-boat/imaging-service/.env | tail -1 | rev | cut -c1-12 | rev)"; echo "MCP env:  $(docker exec boat-cruising-mcp printenv IMAGING_AUTH_TOKEN | rev | cut -c1-12 | rev)"'
```
Token-rotation footgun: if `imaging-service/.env` ends up with **two `AUTH_OWNER_TOKEN=` lines** (old + new), bash uses the last one but a casual `grep ^AUTH_OWNER_TOKEN= .env | head -1` would read the wrong value. Always `tail -1` when reading. Delete the duplicate to avoid confusion: `sed -i '0,/^AUTH_OWNER_TOKEN=/{/^AUTH_OWNER_TOKEN=/d;}'` keeps the second.

**(b) Bypass should also work (defense-in-depth).**
boat-cruising-mcp on docker bridge `boat` has IP `172.18.0.x`. Imaging's `AUTH_LOCAL_SUBNETS` should include `172.` — verify:
```bash
ssh doug@192.168.22.15 'docker exec imaging printenv AUTH_LOCAL_SUBNETS'
```
If the var is missing from the container env, check `compose.yaml` includes `AUTH_LOCAL_SUBNETS=${AUTH_LOCAL_SUBNETS:-192.168.22.,172.}` in the `environment:` list. Earlier deploys forwarded `AUTH_OWNER_TOKEN`, `AUTH_BYPASS_LOCAL` etc. but not `AUTH_LOCAL_SUBNETS`, so the container fell back to the hardcoded `['192.168.22.']` default and 172.x bridge traffic missed the bypass.

Quick end-to-end verification after a fix:
```bash
docker exec boat-cruising-mcp sh -c 'wget -qO- "http://imaging:3100/api/v1/search?q=test&limit=1"'   # bypass path
docker exec boat-cruising-mcp sh -c 'wget -qO- --header="Authorization: Bearer $IMAGING_AUTH_TOKEN" "http://imaging:3100/api/v1/search?q=test&limit=1"'   # token path
```
Both should return `{"results":[…]}`. If either fails, that path's broken.

### No answer / 500 from /api/ask

- `ANTHROPIC_API_KEY` missing in cruising-app container.
- MCP servers unreachable on startup. Look for connect failures: `docker logs cruising-app | grep -iE "mcp|connect"`.
- Check `cruising.ask_log.error` for the most recent failure.

## Diagnostic queries

Recent thumbs-down with notes (the iteration target list):
```sql
SELECT id, asked_at, question, feedback_notes, model
FROM cruising.ask_log
WHERE feedback = -1 AND feedback_notes IS NOT NULL
ORDER BY asked_at DESC LIMIT 20;
```

Tool usage for a specific question:
```sql
SELECT id, question, jsonb_pretty(tools_used) AS tools
FROM cruising.ask_log WHERE id = <id>;
```

Per-tool quality signal (how often the tool appeared and the parent answer was rated):
```sql
SELECT t->>'name' AS tool, COUNT(*) AS calls,
       SUM(CASE WHEN feedback = 1 THEN 1 ELSE 0 END) AS up,
       SUM(CASE WHEN feedback = -1 THEN 1 ELSE 0 END) AS down
FROM cruising.ask_log, jsonb_array_elements(tools_used) t
WHERE feedback IS NOT NULL
GROUP BY 1 ORDER BY down DESC, calls DESC;
```

## Multi-tenant Ask — already designed in ADRs

The current Ask DSII is boat-scoped (cruising-app + boat MCPs), but the multi-tenant evolution is already named in imaging's decision records — don't redesign it from scratch:

- **ADR 0001 §4 — RAG isolation is mandatory.** `ask_about_boat` becomes `ask` with a tenant filter. Cross-tenant retrieval requires *explicit opt-in*; per-tenant isolation is the default. Embeddings live together, but retrieval always carries `WHERE app IN (...)`.
- **ADR 0001 §8 — MCP servers split by tenant.** `boat-docs` becomes one of several tenant MCPs. Tool names disambiguate (`ask_boat`, `ask_taxes`, `ask_medical`).
- **ADR 0002 — Cross-tenant opt-in.** Surface as `ask({ tenants: ['cruising', 'household'] })` with explicit list when crossing.

When extending Ask to a new tenant: read those ADRs first, then implement to match. Don't open new design questions that are already settled there. If the implementation reveals a gap that contradicts an ADR, supersede the ADR rather than drifting.

When the cross-tenant routing pattern actually lands (system prompt? per-question router? Haiku-picks?), come back and document the *implementation* here — the ADRs name the contract, this skill names how it actually works.

## Related skills

- `imaging-expert` — the RAG backend `search_docs`/`read_doc` ultimately call
- `tailscale` — when reaching imaging from off-LAN introduces auth issues
- `claude-api` — Anthropic SDK / tool-description tuning patterns
- `cruising-system` (project-scoped, in cruising-app) — table-level reference for `ask_log` and the rest of the cruising schema
