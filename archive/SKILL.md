---
name: archive
description: Operate the Archive platform — Doug's local-first RAG + event-extraction engine that reconstructs his life and his companies' histories (DSN, XTL, KBL) from a ~1.04M-chunk corpus of documents + email in dk400-postgres. Use to query the corpus (rag.py), run cloud/local event-extraction slices into timeline.life_event / <domain>.event, ingest new documents or mail, or diagnose the HNSW/embedding pipeline. The "how-to" for the [[archive-corpus-build]] memory; sibling of [[life-timeline]] (the personal-domain timeline) and downstream of [[lotus-notes]] (Notes extraction). Lives in apps/archive; current state is docs/STATE.md.
metadata:
  type: skill
---

# Archive — local-first history RAG + event extraction

Reconstructs Doug's life + the entities that ran through it (DSN = Direct Service Network chemical-transport brokerage he founded 1988–~2021; XTL Transport where he was VP-MIS; KBL = KimmerlyBlacksmith / Hand Forged Iron) from a vast doc/email corpus. **Repo: `~/Programming/dkSRC/apps/archive`.** Two layers: a unified pgvector RAG index (`corpus.chunk`) and structured event extraction (`timeline.life_event` + `dsn/xtl/kbl.event`, joined per-event into `archive.my_life`). ADR 0001 governs (confidential = cloud-never). **Always read `docs/STATE.md` + the [[archive-corpus-build]] memory first — they hold current counts/state; this skill is the reusable how-to. Query the DB for live numbers, never trust prose counts.**

## Where everything is
- **DB**: `dk400-postgres` via `ssh 192.168.20.19 docker exec -i dk400-postgres psql -U homelab_admin -d dk400`. **No TCP** — always through docker exec. Pipe SQL via **stdin** (a `-c` with parens gets mangled by the remote shell).
- **Compute**: Ollama on the XPS `192.168.20.12` — `nomic-embed-text` (768-dim embeddings) + `qwen2.5:7b-instruct` (local extraction/triage). Reachable over HTTP from the Mac. Free, off the Claude meter.
- **Code**: `pipeline/` — `ingest.py` (docs+email → corpus.chunk), `rag.py` (query), `slice.py` (`stage`/`stage-uncited`/`load`) + `workflows/event-slice.js` (cloud event slices), `extract.py`/`triage.py`/`qc.py`/`reextract.py` (local + QC), `ocr.py` (`run`/`--mode xls`/`recover` path-repair), `intake.py` (old-drive dedup), `palm_dat.py` (Palm PDA), `build_signal.sql` (signal/noise), `load_docs.py`, `notes/` (NSF extractors). `pipeline/README.md` has the per-tool detail.

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
Routing is automatic: personal-domain → `timeline.life_event`; business-domain → `<domain>.event` by the event's `personal` flag. Knobs: `--domains personal|dsn|xtl|kbl`, `--kind any|mail|doc`, `--order recency|score|docsfirst`, `--offset N`. **Economics: ~1000 sources / 50 sonnet agents / ~$8 (CA$10) / ~0.25–0.31 events/source.** Unmined high-value pools: **DSN business mail (68k, biggest)**, more personal-recent, XTL/KBL mail. **Batch math: `event-slice.js` reads `/tmp/slice_NN.jsonl` at 20 sources/agent → pass `args = ceil(sources/20)` or it silently processes only the default 50.** **Budget: SIZE BY INPUT+OUTPUT (dense docs ran ~13M tok / 3,500 sources; a pass once blew a 30M cap because input was under-counted).**

### Finish the DOC backlog — uncited docs + the `archive.extract_attempt` ledger
The `dsn.document` corpus is fully event-attempted (2026-06-27). To sweep any *new* docs, use the ledger, NOT a raw "uncited" query — **"uncited by any event" conflates never-processed with processed-but-event-less** (tax returns, price lists), so event-less docs re-stage forever. `archive.extract_attempt(source_ref, attempted_at, method)` records every STAGED source regardless of yield.
```bash
python3 pipeline/slice.py stage-uncited --domain dsn --source-dbs '<csv of dsn.document.source_db>' --limit 3500
Workflow({scriptPath: "pipeline/workflows/event-slice.js", args: <ceil(N/20)>})
python3 pipeline/slice.py load <out>   # stamps the whole staged set into the ledger
python3 pipeline/dedup_events.py --apply
```
`stage-uncited` picks docs no event cites (all 3 evidence forms: `dsn.document:id`, `nas:<source_unid>`, raw UNID) AND not already in the ledger, densest-first. `--domain xtl` for `xtldocs` (routes to xtl.event). **Gotcha: the ledger stamp in `slice.py load` MUST run before `extract.stage_load()` — that fn ends in `sys.exit()`, so anything after it is dead code.**

### Recover NO-TEXT docs — it's PATH-REPAIR, not OCR
"Image-only" / no-`body_text` docs are usually **0-byte placeholders** at their indexed `source_unid` (a Synology sync artifact) while the real content sits at a **sibling NAS path with the same basename** (the intake content-dedup finding). `pipeline/ocr.py recover` builds a basename→largest-non-zero-path index, pulls the real copy, extracts by form (pdf→pdftotext/tesseract-OCR, **ppt→LibreOffice `--headless --convert-to pdf`→pdftotext**, doc/docx→textutil w/ LibreOffice fallback, xls→xlrd w/ LibreOffice fallback for legacy variants). Then embed the fills (`ingest.py dump --new-only`→prepare→embed→load; small adds insert into the existing HNSW, no rebuild) and event-extract via `stage-uncited`. Needs LibreOffice (`brew install --cask libreoffice`; `_soffice()` finds it).

### Palm PDA data (`palm_dat.py`)
Doug's Palm Desktop backup (`/volume1/Home Files/Data/Documents/Personal/Palm/KimmerD`, ~1999-2002) is proprietary `.dat`/`.bak` binary. `pipeline/palm_dat.py` parses datebook/memo/todo (type-3/1 = begin/end UNIX-u32 datetimes, type-5 = length-prefixed strings; validate decoded dates against known holidays) → dated `personal` slice sources → `event-slice.js` → life_event. `address.bak` (contacts) + `Note Pad.BAK` (graffiti) left unparsed.

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

## Render a styled life-history PDF (the "make me a booklet" ask)
Doug periodically asks for a polished year-by-year listing of some thread (Christmas parties, home dinner parties, trips…). The reproducible recipe — reuse it so every booklet matches:
1. **Derive the list from the DB, don't trust one source.** Find the spine doc if any (e.g. the DSN party history is the single doc `dsn.document` id `4752`), then cross-check + extend with `timeline.life_event` / `<domain>.event`. **Dedup the extraction's near-identical rows** (same date arrives 3–8×) and drop away-events + noise. `people` is a Postgres **array** (`array_to_string(people,', ')`); event `description` is often empty — the menu / color lives in the source **`evidence` → `mail.message`** rows, so fetch those for detail.
2. **Author HTML from the shared template** `assets/history-doc-template.html` (in this skill dir) — navy Playfair headings, gold subheads, cream intro box, year sections, `Who:` / `Served:` labels, gold "pill" badges. Matches the originals on Doug's Desktop.
3. **Render via Chrome headless** (the originals were Skia/PDF — same engine):
   ```
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
     --no-pdf-header-footer --print-to-pdf="$HOME/Desktop/Name.pdf" "file:///tmp/dsncal/name.html"
   ```
   Fonts load from Google Fonts (Chrome fetches online); the cert/`Failed parsing extensions` stderr line is harmless. Deliver the **PDF to `~/Desktop`**; keep the `.html` source beside it for re-edits.

## Budget discipline (it's the real constraint)
Cloud sonnet agents are cheap (~$0.008/source) and the Sonnet weekly limit is roomy, but the **usage-credit pool (CA$, resets ~monthly)** and the **Opus orchestration session window** are what bind — long >150k-context Opus sessions are the burn, not the agents. So: cloud only on high-value recency-ordered slices, lean local for bulk, **keep Opus sessions short** (`/clear` between tasks; the slice runbook survives a clear).

## Related
- [[archive-corpus-build]] memory — current state, domain model, what's loaded/unmined
- `docs/STATE.md` (in repo) — live handoff + runbooks; `docs/decisions/0001` — the founding ADR
- [[life-timeline]] — the personal-domain timeline (co-built); [[lotus-notes]] — Notes/NSF extraction (the deferred DSN Notes doc DBs); [[secrets]] — SOPS for harvested creds; imaging ADR 0012 — archive+imaging converge into one document platform
