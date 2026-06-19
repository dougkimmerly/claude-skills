---
name: archive
description: Operate the Archive platform — Doug's local-first RAG + event-extraction engine that reconstructs his life and his companies' histories (DSN, XTL, KBL) from a ~990k-chunk corpus of documents + email in dk400-postgres. Use to query the corpus (rag.py), run cloud/local event-extraction slices into timeline.life_event / <domain>.event, ingest new documents or mail, or diagnose the HNSW/embedding pipeline. The "how-to" for the [[archive-corpus-build]] memory; sibling of [[life-timeline]] (the personal-domain timeline) and downstream of [[lotus-notes]] (Notes extraction). Lives in apps/archive; current state is docs/STATE.md.
metadata:
  type: skill
---

# Archive — local-first history RAG + event extraction

Reconstructs Doug's life + the entities that ran through it (DSN = Direct Service Network chemical-transport brokerage he founded 1988–~2021; XTL Transport where he was VP-MIS; KBL = KimmerlyBlacksmith / Hand Forged Iron) from a vast doc/email corpus. **Repo: `~/Programming/dkSRC/apps/archive`.** Two layers: a unified pgvector RAG index (`corpus.chunk`) and structured event extraction (`timeline.life_event` + `dsn/xtl/kbl.event`, joined per-event into `archive.my_life`). ADR 0001 governs (confidential = cloud-never). **Always read `docs/STATE.md` + the [[archive-corpus-build]] memory first — they hold current counts/state; this skill is the reusable how-to. Query the DB for live numbers, never trust prose counts.**

## Where everything is
- **DB**: `dk400-postgres` via `ssh 192.168.20.19 docker exec -i dk400-postgres psql -U homelab_admin -d dk400`. **No TCP** — always through docker exec. Pipe SQL via **stdin** (a `-c` with parens gets mangled by the remote shell).
- **Compute**: Ollama on the XPS `192.168.20.12` — `nomic-embed-text` (768-dim embeddings) + `qwen2.5:7b-instruct` (local extraction/triage). Reachable over HTTP from the Mac. Free, off the Claude meter.
- **Code**: `pipeline/` — `ingest.py` (docs+email → corpus.chunk), `rag.py` (query), `slice.py` + `workflows/event-slice.js` (cloud event slices), `extract.py`/`triage.py` (local), `build_signal.sql` (signal/noise), `load_docs.py`, `notes/` (NSF extractors). `pipeline/README.md` has the per-tool detail.

## Query the corpus (RAG)
```bash
python3 pipeline/rag.py "who were DSN's biggest customers?" --domain dsn --k 12   # local qwen answer + citations
python3 pipeline/rag.py "..." --mode retrieve          # just the top-k chunks, no LLM
python3 pipeline/rag.py "..." --safe                   # exclude confidential (chunk_safe) — cloud-safe
```
nomic needs task prefixes: corpus chunks were embedded `search_document:`, queries use `search_query:` (rag.py handles it). Confidential context stays on the **local** model; `--safe` is for anything that may leave the house.

## Run an event-extraction slice (the "383k → events" lever)
Two-tier per ADR 0001: **local qwen does triage + bulk + the confidential 6k (free); cloud sonnet spends only on high-value slices.** Signal/noise is pre-computed in `archive.source_signal` (signal / noise / middle, via bidirectional "replied-to contact" heuristics). **3 steps (runbook also in STATE.md):**
```bash
# 1. stage (recency order — NOT chrono; oldest mail is sparse, ~0.04 vs ~0.31 events/src)
python3 pipeline/slice.py stage --domains dsn --kind mail --order recency --limit 1000
# 2. run the Workflow (via the Workflow tool — explicit cloud opt-in):
Workflow({scriptPath: "pipeline/workflows/event-slice.js"})
# 3. load (path printed when the workflow task completes):
python3 pipeline/slice.py load <workflow-task-output-file>
```
Routing is automatic: personal-domain → `timeline.life_event`; business-domain → `<domain>.event` by the event's `personal` flag. Knobs: `--domains personal|dsn|xtl|kbl`, `--kind any|mail|doc`, `--order recency|score|docsfirst`, `--offset N`. **Economics: ~1000 sources / 50 sonnet agents / ~$8 (CA$10) / ~0.25–0.31 events/source.** Unmined high-value pools: **DSN business mail (68k, biggest)**, more personal-recent, XTL/KBL mail.

## Ingest new documents or mail → corpus.chunk
```bash
# documents: extract text on the Mac, then load + ingest
python3 pipeline/extract_generic.py ROOT TXTDIR docs.jsonl manifest.jsonl   # pdftotext/textutil/html
python3 pipeline/load_docs.py xtl.document docs.jsonl
python3 pipeline/ingest.py dump|prepare|embed|load --domain xtl --table xtl.document
# mail: ingest.py email mode reads mail.message by source_system
python3 pipeline/ingest.py dump --domain dsn --kind email --source notes-dsn,dsn-gmail --max-chunks 10
```
Sensitivity: `ingest.py` classifies (confidential by source/subject; ADR 0001), scrub-and-harvests secrets to a 0600 file → SOPS, redacts to `[REDACTED]`. **Mail domain is per-MESSAGE, not per-mailbox** — the `kbl` mailbox was Doug's *personal* email (`doug@kimmerlyblacksmith.com` is personal); only `handforgediron.ca` is the KBL business.

## Hard-won gotchas (these cost hours — see STATE.md "Hard-won gotchas")
- **HNSW + bulk writes: DROP the index FIRST, ALWAYS.** Loading/UPDATEing 100k+ rows of `corpus.chunk` with `chunk_hnsw` present runs for *hours* (per-row graph insertion). `DROP INDEX corpus.chunk_hnsw` → write → `ingest.py index`. Forgetting it → a lock pileup that hangs the DB (slow write → queued DROP → SELECTs queue behind). **pgvector's HNSW build ignores `pg_cancel_backend`** — use `pg_terminate_backend`.
- **dk400-postgres RAM gates the HNSW build** — build memory scales with rows (~4 GB `maintenance_work_mem` / 6 GB container for ~990k; spill NOTICE = "no longer fits"). `max_parallel_maintenance_workers=0` (container `/dev/shm` too small for parallel). Container mem persisted in `homelab-dk400/compose.yaml`.
- **psql JSON output: parse with `split("\n")`, NOT `splitlines()`** — chunk text holds raw `\x0b`/`\x0c`/`\x85` that over-split. Dump JSONL with `-tA` + `row_to_json` (not `\copy ... to stdout`, which double-escapes).
- **NEVER print harvested credential values to chat** — decrypt to a local 0600 file for review (Doug corrected this; see [[feedback-never-echo-secrets]]).

## Budget discipline (it's the real constraint)
Cloud sonnet agents are cheap (~$0.008/source) and the Sonnet weekly limit is roomy, but the **usage-credit pool (CA$, resets ~monthly)** and the **Opus orchestration session window** are what bind — long >150k-context Opus sessions are the burn, not the agents. So: cloud only on high-value recency-ordered slices, lean local for bulk, **keep Opus sessions short** (`/clear` between tasks; the slice runbook survives a clear).

## Related
- [[archive-corpus-build]] memory — current state, domain model, what's loaded/unmined
- `docs/STATE.md` (in repo) — live handoff + runbooks; `docs/decisions/0001` — the founding ADR
- [[life-timeline]] — the personal-domain timeline (co-built); [[lotus-notes]] — Notes/NSF extraction (the deferred DSN Notes doc DBs); [[secrets]] — SOPS for harvested creds; imaging ADR 0012 — archive+imaging converge into one document platform
