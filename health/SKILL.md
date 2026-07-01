---
name: health
description: Track and answer questions about Doug's and Maggie's medical lives — meds, conditions, labs, vitals, procedures, immunizations, vaccinations, family history — produce doctor-ready outputs (full medical history, one-page appointment prep sheet), and ingest scanned documents through the imaging pipeline. Use for ANY "what meds am I on / when was my last colonoscopy / what's my BP trend / am I due for a shingles shot / log this lab / prep me for my physical / give the new GP my history / I've scanned new files / drain the scan inbox" task, and the medical-history intake. STRUCTURED DATA lives on the NAS at /Volumes/Home Files/Data/Documents/Personal/Health (per person, _Records/*.md); documents are filed there too AND indexed in the home imaging service (app=medical) for search/RAG + AI extraction. Code/tools = git repo ~/Programming/health. Most sensitive data we hold — home-only, never synced to the boat.
metadata:
  type: skill
---

# Health — medical records + document pipeline for Doug & Maggie

Two medical lives kept straight as we age. **Two coupled stores:** the **NAS** is the canonical, human-browsable
home (records + filed documents); the **home imaging service** is a search/RAG/extraction index over the same
documents (its own copy, rebuildable). They're linked by content hash + a stamped `nas_path`.

## Where everything is
- **NAS (canonical)** — `/Volumes/Home Files/Data/Documents/Personal/Health/` (Synology "Blackhole55"). Per
  person `Doug/` & `Maggie/`:
  - **`_Records/*.md`** — structured data you maintain (profile, conditions, medications, allergies,
    immunizations, procedures, family-history, providers, measurements, labs, history, timeline, intake). **The
    source of truth for "what's true now."**
  - Document categories (identical for both): `Exec Exams · Lab Results · Imaging & Tests · Surgeries &
    Procedures · Prescriptions · Vaccinations (+ Vaccine passes) · Optometry · Dental · Reports & Letters ·
    Receipts · Summaries & ID`.
  - `_ScanInbox/` (Health root) — new scans land here (Brother MFC-L3780CDW scans straight to it, or via
    Image Capture). `_Reference/` = generic guides.
- **Imaging service (home node)** — `http://192.168.20.19:3100/api/v1`, app **`medical`**, tenant defined in
  `dkSRC/infrastructure/imaging/lib/tenants/medical/`. Each doc: OCR/vision text, embeddings, classification
  (person + doc_subtype), extracted meds/items, and `tags.nas_path` = its canonical NAS location.
- **Code/tools (git `~/Programming/health`)** — `tools/`, `templates/`, `CONVENTIONS.md`, `docs/decisions/`. No PII.
- Non-medical docs stay in their own home: **tax** receipt bundles → `Personal/Taxes/`, **XTL business** →
  `/Volumes/XTL/`. Their *medical content* is still extracted by the tenant (mixed-batch) and searchable.

## ⚠️ Confidentiality
Most sensitive data we hold. **Home-only:** the `medical` app is deliberately NOT in any imaging sync peer
list, so it never replicates to the boat. Records + documents live on the NAS + the home imaging node — not on
GitHub. Cloud Claude IS used for triage/classification of medical docs (Doug approved this); OCR (Tesseract) +
embeddings (Ollama) are local. Don't put medical data in git.

## The scan → records pipeline (the main workflow)
When new scans are in `_ScanInbox/` (or to (re)index the tree). All tools in `~/Programming/health/tools/`:
1. **Upload** → `ingest-medical.sh <dir>` — POSTs PDFs to imaging as `app=medical`; derives person + subtype
   from the NAS folder (auto-detect for `_ScanInbox`). Idempotent (dedup by content hash).
2. **OCR + embed** (on the imaging container, local):
   `ssh 192.168.20.19 'docker exec imaging node scripts/ocr-manuals.js --app medical'` then `embed-manuals.js --app medical`.
   (Photo scans OCR to little/no text — the tenant's PDF→image **vision fallback** reads them at triage.)
3. **Classify + extract** → `python3 tools/triage-apply-medical.py` — runs the v2 medical tenant (cloud Claude)
   over every un-applied medical doc: person, doc_subtype, provider, date, **medications[]**, **medical_items[]**
   (for mixed bundles), `mixed_batch`, `clinical_relevance` (high/low/none). Skips already-applied + un-OCR'd.
   **Do NOT use `scripts/batch-triage.js` — it's legacy v1 and won't use the medical tenant.**
4. **File** → `python3 tools/file-from-imaging.py` — moves `_ScanInbox` docs into `Person/<category>/<caption>.pdf`
   using the classification, stamps `nas_path` back onto imaging. Leaves tax/business-homed docs in place;
   holds `Both`/`Other`-person docs for you to place.
5. **Reconcile + verify** → `python3 tools/sync-nas-paths.py` (stamp NAS locations after any move) then
   `python3 tools/audit-health.py` (verify naming date-first + folder matches classification, by hash).
6. **Distill (QC)** — you are the quality check: the tenant is ~95% right (watch dates!). Read the richer new
   docs and fold the precise clinical facts into the `_Records/*.md`.

Run `sync-nas-paths.py` + `audit-health.py` after ANY manual move/rename to keep the two stores coherent.

## Answer a question
Read the canonical `_Records` file that owns the fact (don't guess): meds→`medications.md`, conditions→
`conditions.md`, "when was X"→`procedures.md`/`timeline.md`, a number/trend→`labs.md`/`measurements.md` (long
tables — pivot yourself), "am I due for…"→`immunizations.md`. For free-text search across the documents, use
imaging semantic search / `/ask`. Cite the source; if a value is `?` or files conflict, say so.

## Record something new (canonical home = the NAS `_Records`)
New lab→append `labs.md`; vital/InBody→`measurements.md`; med change→`medications.md`; diagnosis→`conditions.md`
(+`timeline.md`); procedure→`procedures.md`; vaccine→`immunizations.md`. Refresh the affected `history.md` section.

## Produce a one-page appointment prep sheet
Draft `Person/_Records/assessments/<year>-summary.md`, copy `templates/health-summary.html`, fill it, mark
worsening values `class="red"`, keep ONE page (CSS tuned large), then
`tools/render-summary.sh <file>.html "<…>/Summaries & ID/<Year> Health summary for assessment.pdf"`. Verify by
reading the PDF back. The 2026 sheets are worked examples.

## Doctor-ready full history / intake
`_Records/history.md` = maintained narrative; regenerate after changes, print or wrap in the summary template.
`_Records/intake.md` = open `⟨GAP⟩` questions; Maggie prefers Doug as scribe (printable worksheet in her
`Summaries & ID/`).

## Conventions
Documents: **`YYYY-MM-DD <description>.pdf`** (date-first; person = the folder; undated IDs/credentials plain).
Records: ISO dates; append to labs/measurements (never overwrite — trends need the series); cite a `source`;
flag uncertainty `?`. Full grain in `~/Programming/health/CONVENTIONS.md`; decisions in its `docs/decisions/`.
