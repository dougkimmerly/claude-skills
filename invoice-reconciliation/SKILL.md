---
name: invoice-reconciliation
description: Reconcile vendor invoices and email threads to maintenance jobs in the Distant Shores II cruising-management system. Use when ingesting Gmail threads, allocating multi-job invoices to line items, fixing job actual_cost, or backfilling vendors. Covers the line-item allocation rule, FX conversion strategy, "math must tie to printed total" check, doc retagging, and the thread-ingester pattern.
triggers:
  - invoice reconciliation
  - allocate invoice
  - line item allocation
  - job cost audit
  - actual_cost
  - vendor backfill
  - thread ingest
  - dsii maintenance
  - reconcile
  - multi-job invoice
  - horizon allocation
  - contractor allocation
---

# Invoice Reconciliation Playbook

How to reconcile vendor invoices, email threads, and wire transfers to maintenance jobs in the `cruising` schema. Built from the Horizon/contractor reconciliation exercise (April 2026).

## Use the Imaging UI for new threads

For ingesting new email threads going forward, the **Imaging UI at /imaging/** does most of this work automatically:

- Auto-runs the v2 agent on every Gmail thread in the inbox
- Searches existing jobs by keyword AND semantic similarity
- Reads PDF attachments for line items
- Splits multi-topic threads to existing jobs
- Allocates line items as job_parts in one transaction
- Adds `dsii maintenance` Gmail label on apply
- Apply on an email-thread doc also propagates `category` + triage tags to sibling attachment docs (same `gmail_thread_id`), so they leave the unsorted inbox together — without this they re-surface and get re-triaged on refresh

Manual reconciliation (the rest of this skill) is for **historical backfill** or **fixing** what v2 got wrong. The v2 agent does the same conceptual work; this skill describes the rules so you can tell when it's wrong.

## The seven rules

### 1. Verify "already in imaging" — never assume
Gmail labels (e.g. `dsii maintenance`) do **not** mean a thread was ingested. Of 665 labelled threads, ~651 were orphans. Always content-hash check before claiming a doc exists.

```sql
-- Find orphan threads that Gmail says are labelled but imaging doesn't have
SELECT gmail_thread_id FROM gmail_metadata
EXCEPT
SELECT tags->>'gmail_thread_id' FROM imaging.documents
WHERE tags->>'gmail_thread_id' IS NOT NULL;
```

### 2. Pre-existing `actual_cost` is a placeholder, not truth
Existing job costs often came from misattributed wires or round-number user estimates. Treat them as the user's working number; override only when an invoice line-items confirm.

Examples encountered:
- JOB-154 actual_cost was Raymarine wire amount ($5,255) → real canvas invoice $8,529
- JOB-155 was round $5,000 → real Driftwood wire $8,212

### 3. Line-item allocation, never invoice totals
"Biggest dollar item" tagging is fine for **filing the doc** but breaks cost rollups when the invoice spans multiple jobs. JOB-1123 showed $68K vs actual $9K because 4 multi-job Turbulence invoices summed onto it.

**Rule:** Costs must be allocated at the line item level. Each row in `cruising.job_parts` belongs to exactly one job.

```sql
INSERT INTO cruising.job_parts
  (job_id, description, qty, unit_cost, status, source, date_received)
VALUES (...);
```

### 4. Math must tie to the printed total
If line items don't sum to the printed invoice total, the **assumption about the column is wrong**, not the math.

Real example — OTSM gangplank invoice 22231:
```
Labour 96 hr × 80         7680.00   Disc.   7000.00
Shop supplies + argon      960.00     "      480.00
                                   Total   8733.00
```

Initial read: `7680 - 7000 + 960 - 480 + materials(1253) = 2413` — doesn't match $8,733.
Re-read: "Disc" column is the **post-discount actual charge**, so `1253 + 7000 + 480 = 8733` ✓.

When math doesn't tie, re-read column meanings, don't fudge.

### 5. FX: convert at the total, back-allocate per line
Per-line conversion accumulates rounding (cost JOB-154 $90 of drift). For EC$ → USD at 2.67:

```python
total_usd = total_ec / 2.67
ratio = total_usd / total_ec
for line in lines:
    line.unit_cost_usd = round(line.unit_cost_ec * ratio, 2)
# Last line absorbs the rounding remainder
```

### 6. Wires are payments, not invoices
A wire transfer references the invoice it paid. Tag the wire doc to the invoice's primary job; don't treat the wire amount as a standalone cost. The invoice is the source of truth for cost.

### 7. One thread → one doc, with append
`thread-ingester.js` is idempotent by `tags.gmail_thread_id`:
- Fetches all messages in thread
- Strips quoted content (`stripQuotedContent` from `cruising-app/routes/maintenance/helpers.js`)
- Concatenates chronologically
- Finds existing doc by `gmail_thread_id` and **deletes it** before posting new one
- Uploads attachments separately
- Inserts timeline entries on each target job

Re-runs are safe — never duplicates.

## Reconciliation workflow

For each vendor:

1. **Pull threads** — run thread-ingester for the vendor's domain or sender address
2. **Read invoices** — `pdftotext -layout` for PDFs, `textutil -convert txt` for .docx; use local extraction if imaging OCR truncated multi-page PDFs (INV-033 hit this)
3. **Identify primary job per invoice** — biggest-dollar line item rules tagging
4. **Allocate line items** — split each invoice across jobs at the line level
5. **Reconcile** — `SUM(qty*unit_cost) per job` must match the invoice's slice for that job
6. **Update actual_cost** — only where source-verified; sum across vendors for multi-vendor jobs
7. **Update captions** — match the new tag (FTS-indexed, shapes RAG)
8. **Synthesize ALLOCATION SUMMARY** — append to extracted_text + re-embed so RAG can answer per-line questions

## Verification SQL

```sql
-- Per-job parts vs actual_cost
SELECT j.id, j.title, j.actual_cost,
       COALESCE(p.parts_total, 0) AS parts_total,
       j.actual_cost - COALESCE(p.parts_total, 0) AS delta
FROM cruising.jobs j
LEFT JOIN (
  SELECT job_id, ROUND(SUM(qty*unit_cost), 2) AS parts_total
  FROM cruising.job_parts GROUP BY job_id
) p ON p.job_id = j.id
WHERE j.id IN (...) ORDER BY j.id;
```

Delta of 0 = clean. Small deltas (≤$100) are typically FX rounding. Large deltas mean misattribution or missing line items.

## Doc retagging pattern

When a doc is filed under the wrong job, **four** things update:

```sql
UPDATE imaging.documents SET
  tags = tags || jsonb_build_object('job_id','JOB-XXX','entity_id','JOB-XXX'),
  category = 'JOB-XXX',
  caption = 'Vendor invoice NNNN (YYYY-MM-DD) — JOB-XXX <description> — total $X'
WHERE id = 'doc-...';
```

`db.search()` unifies `tags.job_id`, `tags.entity_id`, and `category`. **Caption is FTS-indexed** — it shapes RAG retrieval. Auto-generated captions like `"Silvio/OTSM invoice 2022-01-01 — primary JOB-138 (keywords matched: ...)"` go stale after a retag and silently hurt search. Always rewrite the caption to match the new tag.

## RAG visibility — making allocations searchable

The hard rule: **structured data in `job_parts` does NOT flow into RAG.** Only `caption` + `extracted_text` get chunked + embedded. After allocating an invoice, append a synthesized "ALLOCATION SUMMARY" block to `extracted_text` and re-embed — otherwise `boat-docs` MCP / `/api/v1/ask` can't answer "how much did line X cost on JOB-Y?"

Synthesis pattern (per invoice doc):

```
────────────────────────────────────────
ALLOCATION SUMMARY (synthesized for RAG)
────────────────────────────────────────
Invoice: <vendor> invoice <number> — <description>
Date: YYYY-MM-DD
Vendor: <vendor>

### JOB-XXX — <job title> → $<job-total>
  - <line item> @ $<unit> = $<total>
  - ...

**Total allocated: $<grand-total>**
```

Append it to existing OCR text (don't overwrite — the original invoice text stays useful), then call:

```bash
docker exec imaging node scripts/embed-manuals.js --id doc-XXX --rechunk
```

Worked example: `/tmp/pyi-ingest/synthesize-allocations.py` does this for the contractor invoices.

**This pattern also works for Horizon multi-job invoices** — generate one summary per source doc showing how its line items fanned out to multiple jobs. Currently TODO; would benefit from `invoice_number` being recorded on `job_parts` so the allocation can match a specific source doc.

## .docx is OCR-supported as of April 2026

`lib/ocr.js` handles `.docx` via `mammoth` (pure JS). MIME `application/vnd.openxmlformats-officedocument.wordprocessingml.document`. New uploads auto-extract; backfill with `node scripts/ocr-manuals.js --app maintenance`.

## DUPLICATE jobs

When over-decomposed siblings exist (one SRO became 8 jobs), set `stage = 'DUPLICATE'` rather than deleting. Server filters them by default; pass `?include_duplicates=true` to surface them.

## Vendor name aliases (DSII-specific)

| Canonical | Aliases |
|---|---|
| OTSM / Silvio | "On The Spot Marine", "Sjseppi", "Silvio Iseppi" |
| Trigentic AB | "EmpirBus" (successor), "Garmin Sweden Technologies AB" |
| Turbulence Grenada | "Spice Island Marine" |

## Gotchas

- **OCR truncates multi-page PDFs** — re-extract locally with `pdftotext -layout` if line items appear missing
- **Two routes, one endpoint** — `/api/maintenance/jobs` had two definitions; patching one wasn't enough. Grep for the route.
- **Yard seasons are May→Feb** — 2023 season = May 2023 – Feb 2024
- **Smartsheet emails are noise** — Horizon's PM tool sent automated row-update emails; the invoices are the source of truth
- **`job_parts.unit_cost` is `numeric(10,2)`**, no `total_cost` column — total = `qty * unit_cost`
- **EC$ → USD = ÷ 2.67** for Turbulence/OTSM/Driftwood (Grenada vendors)

## Related

- Thread-ingester: `/tmp/pyi-ingest/thread-ingester.js` (deployed to `cruising-app:/app/plugin/thread-ingester.js`)
- Allocation SQL examples: `/tmp/pyi-ingest/horizon-allocation.sql`, `/tmp/pyi-ingest/contractor-allocation.sql`
- Imaging service: see `imaging-expert` skill for upload/dedup/retagging mechanics
