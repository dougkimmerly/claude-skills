---
name: imaging-expert
description: Imaging service development expertise for the shared document/image storage system on Distant Shores II. Use when uploading, storing, querying, or serving documents and images from any app — maintenance, clearing, inventory, manuals, galley, boat-log. Covers REST API, WebDAV scanning, scan sessions, XMP metadata, thumbnails, full-text search, semantic search (pgvector + Ollama embeddings), OCR, and client integration.
triggers:
  - imaging
  - documents
  - photos
  - docstore
  - upload
  - thumbnails
  - scan
  - scanning
  - genius scan
  - webdav
  - document storage
  - file upload
  - semantic search
  - embeddings
  - ollama
  - invoice
  - manual
  - attachment
  - triage
  - classify
  - extraction
  - immigration
  - clearance
---

# Imaging Expert

Shared document and image storage service for the Distant Shores II cruising management system. Any app on the boat network uploads files and queries them back via REST API. Files live on disk with PostgreSQL as the primary index.

**Container:** `imaging` on centralsk:3100
**Repo:** `dougkimmerly/imaging-service`
**Base URL:** `http://imaging:3100` (from Docker network) or `http://centralsk:3100` (from LAN)

## How It Works

### For Client Apps

Any app on the boat network can store and retrieve documents via HTTP:

1. **Upload** — POST multipart files with metadata (app, category, tags)
2. **Query** — GET with filters (app, category, doc_type, tags, full-text search)
3. **Serve** — GET original file, thumbnail, or preview by document ID
4. **Scan** — Create a scan session, user scans with Genius Scan+ on iPhone, file auto-attaches with metadata

### Data Flow

```
Client Apps                 Imaging Service :3100            Storage
─────────────               ─────────────────────           ─────────────
maintenance:3200  ────┐                                     /store/{app}/{category}/
clearing (future) ────┤     Express.js + Multer             ├── {hash}-{name}.ext
inventory (future) ───┤     ───────────────────             ├── {hash}-{name}.ext.meta.json
manuals (future) ─────┤     REST API → Store → PG+Disk      ├── {hash}-{name}.thumb.webp
galley (future) ──────┤                                     └── {hash}-{name}.preview.webp
boat-log (future) ────┤     WebDAV ← Genius Scan+
                      │
iPhone (Genius Scan+) ┘     dk400-postgres
  via WebDAV PUT            cruising.documents table
```

### File Naming

```
{app}/{category}/{sha256_prefix_8}-{sanitized_original_name}.{ext}
```

SHA-256 prefix prevents collisions. Human-readable name keeps files browsable without a database.

### Dedup

On upload, SHA-256 of file content is checked against `cruising.documents.content_hash`. Duplicates return the existing row instead of storing again.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js 20 (Alpine) |
| Server | Express 4 |
| Database | PostgreSQL (`dk400`, schema: `cruising`) |
| File Processing | Sharp (thumbnails, HEIC), exiftool-vendored (XMP), pdftoppm (PDF thumbnails), pdftotext + Tesseract (OCR), Ollama nomic-embed-text (embeddings) |
| Upload | Multer (multipart), WebDAV (Genius Scan+) |
| Container | Docker (node:20-alpine + vips-dev + perl + poppler-utils + tesseract-ocr) |
| Port | 3100 |
| Network | `boat` Docker bridge |

## Project Structure

```
imaging-service/
├── server.js              # Express entry point, all REST routes, scan sessions
├── lib/
│   ├── store.js           # Disk ops: file storage, sidecars, SHA-256, dedup, rebuild
│   ├── db.js              # PostgreSQL CRUD for cruising.documents
│   ├── thumbnails.js      # Sharp: 200x200 thumb + 800x800 preview (WebP)
│   ├── webdav.js          # WebDAV router for Genius Scan+ auto-sync
│   ├── xmp.js             # ExifTool: embed metadata into JPEG/PNG/PDF files
│   ├── ocr.js             # Text extraction: pdftotext first, Tesseract OCR fallback
│   ├── embeddings.js      # Text chunking + Ollama nomic-embed-text (768-dim vectors)
│   ├── triage.js          # AI document triage engine (Claude API classification + extraction)
│   └── triage-modules/    # Module definitions (auto-loaded on startup)
│       ├── index.js       # Registry: auto-scans directory, loads all .js module defs
│       ├── maintenance.js # Invoices, quotes, receipts, work orders
│       ├── immigration.js # Clearance forms, port invoices, zarpes, permits
│       ├── fuel.js        # Fuel receipts, marina fuel dock invoices
│       └── manuals.js     # Equipment manuals, wiring diagrams, tech docs
├── schema/
│   ├── 002-documents.sql  # Table, 7 indexes, auto-update trigger
│   └── 003-document-chunks.sql  # Chunks table + HNSW index for semantic search
├── scripts/
│   ├── migrate-from-docstore.js  # One-time migration from old DocumentStore
│   ├── backfill-xmp.js           # Embed XMP into existing documents
│   ├── import-manuals.js         # Import manuals from DSII Manuals collection
│   ├── ocr-manuals.js            # Batch OCR (--dry-run, --limit, --id, --reprocess)
│   ├── embed-manuals.js          # Batch embed (--dry-run, --limit, --id, --rechunk)
│   └── smoke-test.sh             # Integration tests (REST + WebDAV + scan sessions)
├── compose.yaml
├── Dockerfile
└── .env                   # PGPASSWORD, WEBDAV_USER, WEBDAV_PASS
```

## REST API Reference

Base: `/api/v1`

### Documents CRUD

```
POST   /documents              Upload file(s) — multipart
                                Required: 'app' field
                                Optional: category, caption, source, doc_type,
                                          tags (JSON), job_id, equipment_id, vendor
GET    /documents              List/filter
                                ?app=maintenance&category=JOB-1074&doc_type=invoice
                                &job_id=&equipment_id=&extracted=&limit=&offset=
GET    /documents/:id          Get metadata (full PG row)
PATCH  /documents/:id          Update: caption, doc_type, tags, source, category, app
DELETE /documents/:id          Delete file + sidecar + thumbnails + XMP + PG row
```

### File Serving

```
GET    /documents/:id/file     Original file (Content-Type + Content-Disposition)
GET    /documents/:id/thumb    Thumbnail 200x200 WebP
GET    /documents/:id/preview  Preview 800x800 WebP
```

### AI Extraction (stores results from calling app's AI)

```
PUT    /documents/:id/extraction    Save extraction JSON
GET    /documents/:id/extraction    Retrieve extraction results
```

### Document Triage (AI classification + structured extraction)

```
POST   /documents/:id/triage        Classify and extract — returns result only (no side effects)
                                     Body: { active_jobs?, equipment?, user_instructions? }
POST   /documents/:id/auto-triage   Classify, extract, AND apply results to document
                                     Body: { active_jobs?, equipment?, user_instructions? }
GET    /triage/modules              List registered modules and their extraction schemas
```

### Search

```
GET    /search?q=fuel+filter          Full-text search (keyword match on caption + extracted_text)
                                       Optional: &app=&limit=
GET    /search/semantic?q=...          Semantic search via pgvector + Ollama embeddings
                                       Natural language queries (e.g. "oil capacity of the yanmar")
                                       Optional: &app=&category=&limit=
```

### Scan Sessions

```
POST   /scan-sessions          Create session with pre-registered metadata
                                Body: { app, category, doc_type, caption, tags }
                                Returns: id, status, instructions, expires_at
GET    /scan-sessions/:id      Poll status: pending → matched → expired
                                When matched: includes full document row
DELETE /scan-sessions/:id      Cancel active session
```

### Bulk & Admin

```
POST   /documents/bulk         Body: { action: "update"|"delete", ids: [...], changes: {...} }
POST   /admin/rebuild-from-sidecars   Rebuild PG from .meta.json files on disk
POST   /admin/rebuild-from-xmp        Rebuild PG from XMP metadata in files
```

### Replication

```
GET    /sync/changes?since_version=N  Documents changed since sync_version
POST   /sync/import                   Body: { documents: [...] } — bulk insert
```

### WebDAV (Genius Scan+)

```
WebDAV endpoint: /webdav/
Auth: Basic (WEBDAV_USER/WEBDAV_PASS)
Methods: OPTIONS, PROPFIND, MKCOL, PUT, GET, DELETE

Virtual filesystem:
  /webdav/                        → root (list category folders)
  /webdav/{category}/             → folder
  /webdav/{category}/{filename}   → file
  /webdav/{filename}              → file (category = "unsorted")
```

### Health

```
GET    /health                 { status, postgres, documents, storage, chunks, ollama, uptime }
```

## Database Schema

Table: `cruising.documents` (shared cruising schema on dk400-postgres)

| Column | Type | Purpose |
|--------|------|---------|
| `id` | TEXT PK | `doc-{timestamp}-{random}` |
| `content_hash` | TEXT | SHA-256 for dedup and integrity |
| `original_filename` | TEXT | Original upload name |
| `stored_path` | TEXT | Relative path from store root |
| `mime_type` | TEXT | MIME type |
| `size` | INTEGER | File size in bytes |
| `doc_type` | TEXT | Auto-classified: photo, invoice, manual, document, etc. |
| `app` | TEXT | Owning app (maintenance, inventory, manuals, etc.) |
| `category` | TEXT | Sub-grouping (JOB-1074, yanmar, deck) |
| `tags` | JSONB | Flexible linking: `{ job_id, equipment_id, vendor }` |
| `caption` | TEXT | User description |
| `source` | TEXT | Origin: upload, webdav, scan, migration |
| `extracted` | BOOLEAN | Whether AI extraction has been run |
| `extracted_text` | TEXT | OCR/AI text for full-text search |
| `extraction` | JSONB | Structured AI results |
| `has_thumbnail` | BOOLEAN | Thumbnail generated |
| `has_preview` | BOOLEAN | Preview generated |
| `source_server` | TEXT | Server that created it (for replication) |
| `sync_version` | INTEGER | Auto-increments on update |
| `created_at` | TIMESTAMPTZ | Creation time |
| `updated_at` | TIMESTAMPTZ | Last update (trigger) |

Key indexes: app, app+category, GIN on tags, content_hash, GIN full-text on caption+extracted_text.

### Document Chunks (Semantic Search)

Table: `cruising.document_chunks` — stores chunked text with vector embeddings.

| Column | Type | Purpose |
|--------|------|---------|
| `id` | SERIAL PK | Auto-increment chunk ID |
| `doc_id` | TEXT FK | References `documents(id)`, CASCADE delete |
| `chunk_index` | INTEGER | Zero-based position within the document |
| `chunk_text` | TEXT | ~500-token overlapping chunk of extracted text |
| `embedding` | vector(768) | nomic-embed-text embedding, NULL until embedded |
| `created_at` | TIMESTAMPTZ | Creation time |

Key indexes: doc_id (btree), embedding (HNSW with vector_cosine_ops).

## Three-Layer Metadata Recovery

Every document has metadata stored in three independent layers:

| Layer | Where | Survives | Recovery Endpoint |
|-------|-------|----------|-------------------|
| PostgreSQL | `cruising.documents` | DB intact | Primary — all queries go here |
| Sidecar files | `.meta.json` next to each file | Filesystem intact | `POST /admin/rebuild-from-sidecars` |
| Embedded XMP | Inside JPEG/PNG/PDF via ExifTool | Individual file survives | `POST /admin/rebuild-from-xmp` |

XMP embeds app metadata as JSON in `XMP-xmp:Description` + `UserComment` fields. Supported for JPEG, PNG, TIFF, PDF. Silently skipped for unsupported types (DOCX, XLS, TXT).

## Client Integration Recipes

### Basic: Upload and Query Documents

```javascript
const IMAGING = process.env.IMAGING_SERVICE || 'http://imaging:3100';

// Upload a file
const form = new FormData();
form.append('files', fileBuffer, { filename: 'invoice.pdf', contentType: 'application/pdf' });
form.append('app', 'maintenance');
form.append('category', 'JOB-1074');
form.append('caption', 'FKG Marine invoice');
form.append('tags', JSON.stringify({ job_id: 'JOB-1074', equipment_id: 'EQ-42' }));

const res = await fetch(`${IMAGING}/api/v1/documents`, { method: 'POST', body: form });
const { documents } = await res.json();
const doc = documents[0]; // { id, stored_path, content_hash, ... }

// List documents for a job
const list = await fetch(`${IMAGING}/api/v1/documents?app=maintenance&category=JOB-1074`);
const { documents: docs } = await list.json();

// Serve thumbnail in HTML
// <img src="http://imaging:3100/api/v1/documents/{id}/thumb" />

// Search across all documents
const search = await fetch(`${IMAGING}/api/v1/search?q=fuel+filter`);
```

### Scan Sessions: Context-Aware iPhone Scanning

This is the recommended pattern for adding "Scan Document" to any app view.

```javascript
// 1. User clicks "Scan Document" in your app
//    Create a scan session with the current context
const sessionRes = await fetch(`${IMAGING}/api/v1/scan-sessions`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    app: 'maintenance',           // your app name
    category: 'JOB-1074',         // current context
    doc_type: 'invoice',          // optional: pre-classify
    caption: 'Fuel filter invoice', // optional
    tags: { job_id: 'JOB-1074', equipment_id: 'EQ-42' }  // optional
  })
});
const session = await sessionRes.json();
// session.instructions has display-ready text for the user

// 2. Show instructions to user:
//    session.instructions.steps = [
//      "Open Genius Scan+ on your iPhone",
//      "Scan the document",
//      "Tap Export → WebDAV",
//      "The document will be automatically attached"
//    ]
//    Show a spinner: "Waiting for scan..."

// 3. Poll for completion (every 2-3 seconds)
const poll = setInterval(async () => {
  const res = await fetch(`${IMAGING}/api/v1/scan-sessions/${session.id}`);
  const status = await res.json();

  if (status.status === 'matched') {
    clearInterval(poll);
    // status.document has the full PG row
    // Show: "Document attached!" with thumbnail
    // Thumbnail: GET /api/v1/documents/{status.document.id}/thumb
  }

  if (status.status === 'expired') {
    clearInterval(poll);
    // Show: "Scan session timed out"
  }
}, 2500);

// 4. User scans with Genius Scan+ and exports via WebDAV
//    (same WebDAV destination they always use — no config change)
//    The imaging service sees the active session and applies the metadata
//    automatically. The poll above picks up the match.
```

**Key points:**
- One active session at a time (creating a new one cancels any previous)
- Sessions expire after 5 minutes
- If no session is active, WebDAV uploads go to `unsorted` as before
- The `app` field comes from the session — any app can use this, not just maintenance

### Existing Client: ImagingClient (Maintenance)

The `cruising-app` repo has `modules/maintenance/plugin/imaging-client.js` wrapping the REST API with the same interface as the old local DocumentStore. Enable with `IMAGING_SERVICE=http://imaging:3100` in the container environment.

## Auto-Classification

When `doc_type` is not provided, the service auto-classifies from MIME type and filename:

| MIME / Filename Pattern | doc_type |
|------------------------|----------|
| PDF + "invoice" or "inv-" | invoice |
| PDF + "quote" or "estimate" | quote |
| PDF + "receipt" | receipt |
| PDF + "manual" | manual |
| PDF + "drawing/diagram/fabrication" | diagram |
| PDF (other) | document |
| image/* | photo |
| video/* | video |
| spreadsheet/excel/csv/xls | spreadsheet |
| word/doc/docx | document |
| markdown | manual |
| text | document |
| (fallback) | other |

## Thumbnail Support

Sharp generates 200x200 thumbnails and 800x800 previews as WebP (quality 80).

**Supported:** JPEG, PNG, WebP, TIFF, AVIF, HEIC/HEIF, GIF
**PDF:** First page rendered via pdftoppm, then processed by Sharp
**Unsupported:** DOCX, XLS, TXT (no thumbnail generated)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3100 | HTTP port |
| `STORE_ROOT` | /store | Root directory for file storage |
| `PGHOST` | localhost | PostgreSQL host |
| `PGPORT` | 5432 | PostgreSQL port |
| `PGDATABASE` | dk400 | Database name |
| `PGUSER` | dk400 | Database user |
| `PGPASSWORD` | — | Database password (required) |
| `SOURCE_SERVER` | centralsk | Server identifier for replication |
| `MAX_UPLOAD_MB` | 20 | Maximum upload size |
| `WEBDAV_USER` | — | WebDAV Basic auth username (enables WebDAV if set) |
| `WEBDAV_PASS` | — | WebDAV Basic auth password |
| `OLLAMA_URL` | http://ollama:11434 | Ollama server URL for embeddings |
| `ANTHROPIC_API_KEY` | — | Anthropic API key (required for document triage) |

## Deployment

```bash
# On centralsk
cd /opt/dk400-boat/imaging-service
git pull
docker compose up -d --build
curl http://localhost:3100/health

# Run smoke tests
WEBDAV_USER=scan WEBDAV_PASS=scan bash scripts/smoke-test.sh http://localhost:3100
```

**Volume:** `/opt/dk400-boat/documents` → `/store` (owned by UID 100:101)
**Database:** `dk400-postgres` container, `cruising.documents` table
**Network:** `boat` (external Docker bridge, shared with maintenance, dk400-postgres)

## Critical Rules

1. **App field required** — every document must have an `app` (maintenance, clearing, inventory, etc.)
2. **Dedup by content hash** — identical files return existing row, not a duplicate
3. **Three-layer metadata** — PG is primary, sidecars for filesystem recovery, XMP for per-file recovery
4. **XMP is non-blocking** — XMP embed failures are silently caught; never block an upload
5. **WebDAV fallback** — if no active scan session, WebDAV uploads go to `maintenance/unsorted`
6. **UID 100** — container runs as non-root imaging user; volume dirs must be owned by 100:101
7. **Parameterized queries** — never interpolate SQL

## OCR / Text Extraction

`lib/ocr.js` extracts text from PDFs and images for full-text search:

1. **pdftotext** (instant) — tries embedded text first; used if >= 50 chars returned
2. **Tesseract OCR** (fallback) — renders pages to PNG via pdftoppm at 300 DPI, OCRs each page

Batch script: `scripts/ocr-manuals.js`
- `--dry-run` — show what would be processed
- `--limit N` — process only N documents
- `--id doc-xxx` — process a single document
- `--reprocess` — re-run pdftotext on all docs (upgrades OCR'd text to cleaner embedded text)

Results stored in PG: `extracted=true`, `extracted_text`, `extraction` (method, pages, chars, duration).
Full-text search GIN index covers `extracted_text` automatically.

**Current stats:** 431/489 manuals extracted (352 via pdftotext, 79 via Tesseract OCR), 10,503 pages, 17.8M chars.

## Semantic Search / Embeddings

`lib/embeddings.js` chunks extracted text and generates 768-dimensional vector embeddings via Ollama's `nomic-embed-text` model. Enables natural language queries like "oil capacity of the yanmar" or "how to replace the impeller".

### Architecture

```
Query → Ollama embed → pgvector cosine similarity → ranked results with chunk context
```

**Infrastructure:** Requires `pgvector/pgvector:pg16` (postgres image) and an `ollama` container with `nomic-embed-text` model on the `boat` network.

### Chunking Strategy

- Split on paragraph boundaries (`\n\n`)
- Merge short paragraphs up to ~2000 chars (~500 tokens)
- Split long paragraphs at sentence boundaries
- 400-char (~100-token) overlap between adjacent chunks
- Preserves OCR page markers for context

### Embed Cleaning

Before embedding, text is cleaned to reduce token inflation from OCR artifacts:
- Trailing whitespace trimmed per line
- Repeated ASCII dots (`.....`) collapsed to `...`
- Repeated Unicode ellipsis (`……`) collapsed
- Repeated underscores, dashes, newlines collapsed
- Text truncated to 8000 chars (nomic-embed-text has 8192-token context)

### Batch Script

`scripts/embed-manuals.js` — chunks and embeds all extracted manuals.

- `--dry-run` — show chunk counts without embedding
- `--limit N` — process only N documents
- `--id doc-xxx` — process a single document
- `--rechunk` — delete existing chunks and re-embed from scratch

Resumable: skips documents that already have chunks (unless `--rechunk`).

### Client Usage

```javascript
// Semantic search — natural language query
const res = await fetch(`${IMAGING}/api/v1/search/semantic?q=how+to+winterize+the+engine`);
const { results } = await res.json();
// results[]: { chunk_text, chunk_index, similarity, id, original_filename, app, category, ... }

// With filters
const res2 = await fetch(`${IMAGING}/api/v1/search/semantic?q=oil+change&app=manuals&limit=5`);
```

**Current stats:** 423 docs chunked, 11,033 chunks embedded, ~1.1s per chunk average.

## Embeddable Components

Reusable UI components served at `/components/`. Any app includes two tags:

```html
<link rel="stylesheet" href="http://centralsk:3100/components/imaging-components.css">
<script src="http://centralsk:3100/components/imaging-components.js"></script>
```

### PhotoGallery — Entity-Scoped Gallery

```javascript
// Show all photos for a maintenance job, with upload + caption + delete
const gallery = new Imaging.PhotoGallery(document.getElementById('photos'), {
  app: 'maintenance',
  entityType: 'job',
  entityId: 'JOB-1074',
  allowUpload: true,
  allowDelete: true,
  allowCaption: true,
  compact: false     // true = single 48x48 thumbnail for table rows
});
// Events: img:uploaded, img:deleted, img:captionChanged, img:loaded
// Public: load(), getCount(), destroy()
```

### DocumentBrowser — Embeddable Browse/Search Panel

```javascript
// Full document browser scoped to manuals
const browser = new Imaging.DocumentBrowser(document.getElementById('docs'), {
  app: 'manuals',        // scope to app (null = all)
  showSearch: true,
  showUpload: true,
  showDetail: true,      // split-view detail panel
  height: '600px'
});
// Events: img:documentSelected, img:documentDeleted
// Public: load(), setFilter({ app, category }), search(q), destroy()
```

### UploadWidget — Standalone Upload

```javascript
const uploader = new Imaging.UploadWidget(document.getElementById('upload'), {
  app: 'maintenance',
  category: 'JOB-1074',
  tags: { job_id: 'JOB-1074' }
});
// Events: img:uploaded, img:uploadError
```

### ScanSession — iPhone Scan Integration

```javascript
const scanner = new Imaging.ScanSession(document.getElementById('scan'), {
  app: 'maintenance',
  category: 'JOB-1074',
  doc_type: 'invoice',
  tags: { job_id: 'JOB-1074' },
  pollInterval: 2500
});
// Events: img:scanMatched, img:scanExpired
// Public: start(), cancel()
```

### Token Auth for Components

```javascript
// Set token globally for all components
Imaging.setToken('your-bearer-token');

// Or per-component
new Imaging.PhotoGallery(el, { token: 'your-bearer-token', ... });
```

### Theme Inheritance

Components use CSS custom properties with `img-` prefix. They auto-inherit from the host app if these variables are defined:

```
--bg-primary, --bg-secondary, --bg-card, --bg-card-hover,
--text-primary, --text-secondary, --text-muted,
--accent, --accent-hover, --success, --warning, --danger, --border
```

### Server-Side Node.js Client

`lib/imaging-client.js` wraps the REST API for use from any Node.js app:

```javascript
const ImagingClient = require('./lib/imaging-client');
const client = new ImagingClient({
  baseUrl: 'http://imaging:3100',
  token: process.env.IMAGING_TOKEN
});

// List, search, scan sessions
const docs = await client.list({ app: 'maintenance', tags: { job_id: 'JOB-1074' } });
const results = await client.search('fuel filter');
const semantic = await client.searchSemantic('how to replace impeller');
const session = await client.createScanSession({ app: 'maintenance', category: 'JOB-1074' });
```

## Document Triage (AI Classification + Extraction)

Universal document intelligence powered by Claude Sonnet. Classifies documents into modules and extracts module-specific structured data.

### Registered Modules

| Module | Handles | Key extraction fields |
|--------|---------|----------------------|
| `maintenance` | Invoices, quotes, receipts, work orders, parts lists | vendor, costs[], parts[], equipment[], total_amount, invoice_number |
| `immigration` | Clearance forms, port invoices, zarpes, permits, registrations | country, port, visit_type, date, fees_usd, fees_local, permit_number, crew_count |
| `fuel` | Fuel receipts, marina fuel dock invoices | litres, cost, price_per_litre, fuel_type, location, date |
| `manuals` | Equipment manuals, wiring diagrams, spec sheets | manufacturer, model, equipment_name, doc_subtype |

**Extensible:** Add a new module by creating a `.js` file in `lib/triage-modules/`. The registry auto-loads it and the AI prompt auto-includes it. No changes to core triage logic needed.

### Iterative Triage Workflow

The triage system is designed for iterative refinement. The `POST /documents/:id/triage` endpoint is read-only — it returns a classification but does not modify the document. This lets a client call it multiple times with increasing context until satisfied, then apply the result.

**Step 1: Initial triage (no context)**
```javascript
// First pass — AI classifies from document content alone
const result = await fetch(`${IMAGING}/api/v1/documents/${docId}/triage`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({})
});
// result: { module: "maintenance", doc_type: "invoice", caption: "FKG Marine invoice for impeller replacement", extraction: { vendor: "FKG Marine", costs: [...] }, confidence: 0.85 }
```

**Step 2: Reassess with context**
```javascript
// User sees the result and wants to refine — provide additional context
const result2 = await fetch(`${IMAGING}/api/v1/documents/${docId}/triage`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    active_jobs: [
      { id: 'JOB-1074', title: 'Impeller replacement', stage: 'in-progress', system: 'Engine', equipment: 'Raw water pump' }
    ],
    equipment: [
      { id: 'EQ-042', name: 'Yanmar 4JH5E Raw Water Pump', system: 'Engine' }
    ],
    user_instructions: 'This is the final invoice from FKG for the impeller job'
  })
});
// result2: { module: "maintenance", job_id: "JOB-1074", equipment_id: "EQ-042", confidence: 0.95 }
```

**Step 3: Apply when satisfied**
```javascript
// Lock in the result — updates app, category, tags, caption, extraction on the document
const { triage, document } = await fetch(`${IMAGING}/api/v1/documents/${docId}/auto-triage`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    active_jobs: [...],
    equipment: [...],
    user_instructions: 'This is the final invoice from FKG for the impeller job'
  })
}).then(r => r.json());
```

**Key points:**
- `triage` is read-only — call it as many times as needed, it never modifies the document
- `auto-triage` classifies AND applies — use only when the user is satisfied with the result
- `user_instructions` is injected as highest-priority context (same pattern as maintenance email-analyzer)
- Context (active_jobs, equipment) improves matching but is optional — triage works without it
- The AI is told explicitly not to guess or fabricate values — only fields present in the document are extracted

### Server-Side Client

```javascript
const ImagingClient = require('./lib/imaging-client');
const client = new ImagingClient({ baseUrl: 'http://imaging:3100' });

// Read-only triage
const result = await client.triage(docId, {
  active_jobs: [...],
  equipment: [...],
  user_instructions: 'invoice for keel work'
});

// Triage + apply
const { triage, document } = await client.autoTriage(docId, {
  active_jobs: [...],
  equipment: [...]
});

// List available modules
const { modules } = await client.triageModules();
```

### WebDAV Auto-Triage

Documents uploaded via WebDAV (Genius Scan+) are automatically triaged after ingest if `ANTHROPIC_API_KEY` is set. A 5-second delay allows the background OCR to complete first. Results are applied immediately (same as auto-triage). This means scanning a clearance form auto-classifies it as immigration without any manual step.

### Adding a New Module

Create a file in `lib/triage-modules/` (e.g., `inventory.js`):

```javascript
module.exports = {
  name: 'inventory',
  description: 'Spare parts inventory: purchase orders, packing slips, inventory counts.',
  doc_types: ['purchase_order', 'packing_slip', 'inventory_count', 'receipt'],
  keywords: ['spare', 'parts', 'inventory', 'order', 'packing slip', 'stock'],
  extraction_schema: {
    vendor: { type: 'string', description: 'Supplier name' },
    items: { type: 'array', items: { name: 'string', part_number: 'string', quantity: 'number' } },
    order_number: { type: 'string', description: 'PO or order reference' },
    total_cost: { type: 'number', description: 'Total cost' }
  },
  context_fields: {},
  prompt_hint: 'For inventory documents: extract all line items with part numbers and quantities.'
};
```

That's it — restart the service and the new module appears in `GET /triage/modules` and is included in all triage prompts automatically.

## Future Work

- **Replication** — rsync files + app-level PG sync between boat (centralsk) and home server
- **Migrate maintenance photo-manager.js** to use `Imaging.PhotoGallery` component
