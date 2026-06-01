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
  via WebDAV PUT            imaging.documents table
```

### File Naming

```
{app}/{category}/{sha256_prefix_8}-{sanitized_original_name}.{ext}
```

SHA-256 prefix prevents collisions. Human-readable name keeps files browsable without a database.

### Dedup

On upload, SHA-256 of file content is checked against `imaging.documents.content_hash`. Duplicates return the existing row instead of storing again.

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
│   ├── db.js              # PostgreSQL CRUD for imaging.documents
│   ├── thumbnails.js      # Sharp: 200x200 thumb + 800x800 preview (WebP)
│   ├── webdav.js          # WebDAV router for Genius Scan+ auto-sync
│   ├── xmp.js             # ExifTool: embed metadata into JPEG/PNG/PDF files
│   ├── ocr.js             # Text extraction: pdftotext first, Tesseract OCR fallback
│   ├── embeddings.js      # Text chunking + Ollama nomic-embed-text (768-dim vectors)
│   ├── triage.js          # v1 single-shot classifier (used only by WebDAV auto-triage hook)
│   ├── triage-modules/    # v1 module definitions used by lib/triage.js
│   │   ├── index.js       # Registry: auto-scans directory
│   │   ├── maintenance.js, immigration.js, fuel.js, manuals.js
│   ├── agent-runtime.js   # v2 generic Anthropic tool-use loop (tenant-agnostic)
│   ├── triage-tools.js    # Shared SQL helpers used by v2 tenants (searchJobs, etc.)
│   ├── tenants/           # v2 tenant modules — see ADR 0002 + lib/tenants/README.md
│   │   ├── index.js       # Registry: auto-discovers modules, validates contract
│   │   ├── maintenance/   # jobs, job_parts, equipment
│   │   ├── manuals/       # equipment registry + RAG manual_summary
│   │   ├── ports/         # port_visits (Ports & Immigration)
│   │   └── receipts/      # tank_log fills + generic receipts (subtype dispatch)
│   ├── rag.js             # RAG engine: retrieval + Claude answer generation
│   ├── classify.js        # Post-OCR content-based doc_type + caption classification
│   └── equipment-resolver.js  # Maps natural language → specific boat equipment
├── mcp/
│   └── server.js          # MCP server for Claude Code (runs on dev Mac)
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

Table: `imaging.documents` (shared cruising schema on dk400-postgres)

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

Table: `imaging.document_chunks` — stores chunked text with vector embeddings.

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
| PostgreSQL | `imaging.documents` | DB intact | Primary — all queries go here |
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

**Multi-site compose layout (2026-06-01).** One repo, one `main`, everything committed — no per-host uncommitted mods:
- `compose.yaml` — shared, parameterized **base**; every per-site value is `${VAR:-default}` and the **defaults are the BOAT** (centralsk) deployment.
- `compose.override.yaml` — **boat-only** structural extras (the `manuals-source:ro` mount + public `dns:`). Docker **auto-loads** it on a bare `docker compose up`, so the boat deploys exactly as before.
- `deploy.sh [home|boat]` — injects per-site secrets from SOPS (`homelab-secrets/secrets/<site>/imaging-service.sops.yaml`) via `sops exec-env`. **Home** runs `-f compose.yaml` (explicit → skips the boat override); **boat** runs bare (base + override).
- Per-site **config** lives in each host's `.env` (auto-read for `${VAR}` interpolation); per-site **secrets** in SOPS.

```bash
# BOAT (centralsk) — not yet SOPS-migrated (Phase 3), so still deploys plaintext:
cd /opt/dk400-boat/imaging-service
git pull && docker compose up -d --build      # base + auto-loaded compose.override.yaml
curl http://localhost:3100/health

# HOME (docker-server) — secrets from SOPS:
cd /opt/docker-server/imaging-service
git pull && ./deploy.sh home                   # docker compose -f compose.yaml up, sops exec-env

# Smoke tests
WEBDAV_USER=scan WEBDAV_PASS=scan bash scripts/smoke-test.sh http://localhost:3100
```

**Volume (boat):** `/opt/dk400-boat/documents` → `/store` (owned by UID 100:101)
**Database:** `dk400-postgres` container, `imaging.documents` table
**Postgres volume:** `postgres_postgres_data` (compose-managed from `/opt/centralsk/postgres/`)
**Network:** `boat` (external Docker bridge, shared with maintenance, dk400-postgres)

> **Gotcha:** before this layout, both sites' compose **hardcoded** `MAX_UPLOAD_MB=20` while both `.env`s said `100` — the `.env` was ignored. The parameterized base honors the `.env`, so the effective limit is now **100** at both sites. Pin via `.env` if a different value is wanted.

### Multi-host / replica deployment (added 2026-05-05, updated 2026-06-01)

Imaging is deployed on multiple hosts from **one shared repo** (see "Multi-site compose layout" above) — each host selects its config via `.env` + SOPS, not via a divergent committed `compose.yaml`. Replication between hosts is governed by imaging-service ADR 0003 (3-layer hybrid: imaging-core via `/sync/*` HTTP, files via Syncthing, tenant side-effect schemas via postgres replication) and fixer ADR 0008 (cruising-schema scope and mechanism).

**Per-host deployment differences seen in the wild:**

| Setting | centralsk | home |
|---|---|---|
| Repo path | `/opt/dk400-boat/imaging-service/` | `/opt/docker-server/imaging-service/` |
| Storage root | `/opt/dk400-boat/documents/` | `/opt/docker-server/imaging/documents/` |
| Docker network | `boat` | `homelab` |
| Postgres image | `centralsk/postgres:pg16` (custom, with pgvector + PostGIS 3.4) | `dk400-postgres:pg16` (built from `dougkimmerly/dk400-postgres-image`, pgvector + PostGIS 3.6.3) — upgraded from `postgres:16-alpine` 2026-05-06 per ADR 0009 |
| `PGUSER` | `dk400` | `fixer` (the local app role; `dk400` role exists but uses a different SCRAM password we don't have stored) |
| Ollama | local container on `boat` network | `OLLAMA_URL=http://192.168.20.201:11434` (home Ollama host) |
| `AUTH_LOCAL_SUBNETS` | `192.168.22.,172.` | `192.168.20.,172.` |
| Tenants primary on this host | `maintenance, manuals, ports, receipts` | (future) `taxes, medical, legal, household` |

**Schema migration order on a fresh replica without history:**

- Apply `schema/002-documents.sql` after manually creating the `imaging` and `cruising` schemas (both expected to exist by the SQL).
- **Skip `schema/004-imaging-namespace.sql`** — it's a one-time legacy `cruising.documents` → `imaging.documents` rename and contains an `ASSERT doc_count > 0` that crashes on a fresh empty install.
- **Skip `schema/005-immigration-to-ports-rename.sql`** — same reason; it's a data rename that's a no-op on empty data.
- Apply `schema/003-document-chunks.sql` only on hosts with pgvector (`SELECT * FROM pg_available_extensions WHERE name='vector'` to check). Skip on hosts that don't.
- Apply `schema/006-sync-state.sql` always — it's chunks-tolerant.
- Grant all privileges on schema `imaging` to whichever app role connects (e.g. `fixer` on home, `dk400` on centralsk).

**Smoke-checks for a new replica:**

- `curl http://localhost:3100/health` should return `status: ok` and `postgres: connected`. `chunks: …` may report errors if `imaging.document_chunks` is absent — known imaging-side noise (B8d guards missed the chunk-stats query path); flag to imaging session.
- From inside the imaging container: `nc -zv <peer-tailscale-ip> 3100` should connect. Docker bridges DO route to Tailscale on a stock host (IP forwarding + bridge MASQUERADE handles 100.x like any external destination); do **not** switch to `network_mode: host` — unnecessary and disruptive.
- If the sync worker is timing out on `/sync/changes` first-page, the symptom looks like a network problem but is usually large embedding payloads exceeding the worker's HTTP timeout. Test with `wget --timeout=120` to a peer's `/sync/changes`; if it eventually returns MB of data, the bottleneck is payload size, not routing.

**Postgres password gotcha (any host):**

`pg_hba.conf` typically has `local`/`127.0.0.1` set to `trust`. That means `docker exec dk400-postgres psql -U <role> -h localhost` does NOT verify the password — it succeeds for any `-U` and any password. To actually test a role's password, connect from a non-loopback source (e.g. another container on the same docker network), or check `SELECT rolpassword FROM pg_authid WHERE rolname=<role>` against what the app is configured with.

### CRITICAL: Before Any Postgres/Infrastructure Changes

```bash
# 1. ALWAYS backup the database first
docker exec dk400-postgres pg_dumpall -U dk400 > /opt/centralsk/backups/pg-$(date +%Y%m%d).sql

# 2. Verify backup is non-empty
ls -la /opt/centralsk/backups/pg-*.sql

# 3. After any container recreation, verify the correct volume
docker inspect dk400-postgres --format "{{range .Mounts}}{{.Name}}{{end}}"
# Must show: postgres_postgres_data (NOT dk400-pgdata or any other name)
```

**Why:** On 2026-04-12, the postgres container was accidentally pointed at a new empty volume, causing all schemas to appear lost. Data was recovered from the original volume, but only because it wasn't deleted.

### Auth / Network Access

The imaging service uses bearer token auth with a local-network bypass (`lib/auth.js`). The bypass list is **configurable** via `AUTH_LOCAL_SUBNETS` env (added 2026-05-05, commit `fdeba73`) — defaults to `192.168.22.,127.0.0.1,::1` if unset. Requests from any subnet in the list get `owner` role automatically; requests from other sources need a `Bearer` token in `Authorization`.

Per-host typical settings:
- centralsk: `AUTH_LOCAL_SUBNETS=192.168.22.,172.` (boat LAN + docker bridges)
- home: `AUTH_LOCAL_SUBNETS=192.168.20.,172.` (home LAN + docker bridges)

Cross-host calls over Tailscale (`100.x`) are intentionally NOT in any bypass list — they always require a bearer token. The sync worker reads `SYNC_PEER_AUTH_TOKEN` and sends it as `Authorization: Bearer <token>` on every peer request. **`AUTH_OWNER_TOKEN` should be the same value on both hosts** (single user; the worker on host A authenticates as the owner on host B and vice versa).

The MCP server (`mcp/server.js`) does NOT send a token — it relies on the local-network bypass. The dev Mac must be on the appropriate subnet for MCP tools to work.

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

**Current stats:** 911 docs chunked, 9,411 chunks embedded.

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

## Document Triage — two systems

The current architecture (post ADR 0001 + 0002) is a **tool-using triage v2** with tenant modules. The legacy single-shot v1 still runs for one specific path.

### v2 — Tenant modules (current path)

Each registered tenant under `lib/tenants/<name>/` exports the ADR 0002 contract: `uploadFields`, `systemPrompt`, `tools`, `planSchema`, `applyPlan`, `renderPlanCard`. The shared `lib/agent-runtime.js` drives the Anthropic tool-use loop with tenant-supplied prompt + tool list. Apply runs in one PG transaction across imaging-core + tenant-owned tables.

| Tenant | App | Apply targets | Plan focus |
|---|---|---|---|
| Maintenance | `maintenance` | cruising.{jobs, job_parts, equipment, job_embeddings} | primary_job + line items + thread splits |
| Manuals | `manuals` | cruising.equipment + manual_summary in extracted_text | primary equipment + also-references + doc_subtype |
| Ports & Immigration | `ports` | cruising.port_visits | port_visit (existing or proposed) + fees + doc_subtype |
| Receipts | `receipts` | (subtype dispatch via `receipts/domains/`) cruising.tank_log | line_items[] each linking to a fill |
| Household | `household` | imaging.documents only (no tenant schema in v1) | doc_subtype dispatch (insurance/tax/utility/permit/purchase/renovation/maintenance/electrical/network/automation/reference) + extracted fields (vendor, issuer, dates, amount). First non-boat tenant. |

Receipts is itself extensible via subtype handlers in `lib/tenants/receipts/domains/<name>.js`. Today: `tank-log.js` (fuel/water fills) and `generic.js` (file-only). Future subtypes (port_stay → port_visits, parts → job_parts) drop in here without touching the receipts core.

Household is intentionally minimal in v1 — no primary entity, no tenant SQL schema, single `finalize_household_plan` tool. The agent classifies from text+image alone. Promotes to a primary-entity model (systems/projects) only when a search use-case demands it. House appliance manuals route to the manuals tenant (multi-asset), not duplicated here.

**Adding a new top-level tenant:** one directory under `lib/tenants/<name>/` + one render branch in cruising-app/work-items.js. Imaging core unchanged. See `lib/tenants/README.md`.

### v1 — Legacy single-shot (`lib/triage.js` + `lib/triage-modules/`)

Still wired to the WebDAV auto-triage hook (`server.js` line ~1280): when Genius Scan+ delivers a doc via WebDAV, a 5-second `setTimeout` calls `triageDocument()` to classify the doc into one of the v1 modules (maintenance/immigration/fuel/manuals). This keeps freshly-scanned docs from sitting unclassified in the inbox.

When you re-trigger triage from the `/imaging/` UI (autorunner or "Re-plan with hints"), the request goes to `/triage-v2` which dispatches to the v2 tenant — not v1.

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

### Adding a New Tenant (v2)

This is the modern path. v1 modules in `lib/triage-modules/` are only used by the WebDAV auto-classifier; new doc types belong in v2 tenants.

Create a directory `lib/tenants/<name>/` exporting eight things from `index.js`:

```javascript
// lib/tenants/inventory/index.js (sketch)
const { SYSTEM_PROMPT } = require('./prompt');
const { UPLOAD_FIELDS } = require('./upload-fields');
const { PLAN_SCHEMA }   = require('./schema');
const { TOOLS }         = require('./tools');
const { triage }        = require('./triage');
const { applyPlan }     = require('./apply');
const { renderPlanCard } = require('./render');

module.exports = {
  app: 'inventory',
  label: 'Parts & Inventory',
  uploadFields: UPLOAD_FIELDS,        // form fields shown in /imaging/ Add new
  systemPrompt: SYSTEM_PROMPT,
  tools: TOOLS.map(t => t.name),
  planSchema: PLAN_SCHEMA,             // JSON Schema for the agent's plan output
  triage,                              // builds context + calls runAgent
  applyPlan,                           // atomic apply across imaging + tenant tables
  renderPlanCard                       // returns JSON spec the UI renders
};
```

Restart the imaging service. The tenant registers automatically and shows up in `GET /api/v1/tenants`. The /imaging/ Add new form populates its fields from the tenant's uploadFields. **One render branch in cruising-app/work-items.js renderTriagePlan is the only UI change needed.** No edits to imaging core.

See `lib/tenants/README.md` and existing tenants (maintenance, manuals, ports, receipts) for the contract.

## RAG Q&A (Retrieval-Augmented Generation)

Ask natural language questions about the boat and get answers grounded in the document library.

### Endpoint

```
POST /api/v1/ask
Body: { question, app?, category?, limit?, structured_context? }
Returns: { answer, sources: [{ id, filename, app, category, caption, doc_type, similarity }] }
```

### How It Works

Three-layer hybrid retrieval:
1. **Semantic search** — embed question via Ollama, pgvector cosine similarity
2. **Full-text search** — PostgreSQL GIN index keyword matching (catches docs semantic misses)
3. **Equipment-targeted search** — resolves equipment references ("the engine" → Yanmar 4JH5E), then full-text searches within those equipment's tagged documents

Equipment resolver (`lib/equipment-resolver.js`) maps common names to specific gear via an alias table + cruising.equipment DB lookup. Also includes removed equipment flagged as REMOVED/REPLACED so Claude can answer questions about previous gear.

After retrieval, sends top chunks + equipment context to Claude Sonnet for a grounded answer with source citations.

### RAG Quality Notes

- **Manuals** — work well, equipment-targeted search finds the right sections
- **Invoices/receipts** — OCR'd and embedded, work for vendor/cost queries
- **Immigration docs** — re-embedded using synthesized text from triage extraction (raw OCR from handwritten forms is garbage)
- **Structured data** (fuel logs, port visits) — lives in cruising-app DB, not documents. Use `structured_context` field to inject DB records alongside document chunks
- **Post-OCR classification** — `lib/classify.js` auto-detects invoice/quote/receipt from text content and generates captions

### Client Usage

```javascript
// Server-side
const result = await client.ask('What is the oil capacity of the engine?');
// { answer: "5.5 ± 0.3 L at 0° rake...", sources: [...] }

// With structured context from calling app's DB
const result = await client.ask('How much fuel in Florida?', {
  structured_context: 'Fuel records:\n- 2023-01-15 Marathon FL: 200L diesel $340\n...'
});
```

## MCP Server (Claude Code Integration)

Every Claude Code instance can query the boat's knowledge base via MCP tools.

**Location:** `mcp/server.js` — runs locally on dev Mac, HTTP calls to centralsk:3100
**Config:** `~/.claude.json` → `mcpServers.boat-docs`

### Tools

| Tool | Purpose |
|------|---------|
| `ask_about_boat` | **Primary tool.** Full RAG Q&A with hybrid retrieval + equipment resolution |
| `search_boat_docs` | Fallback: raw semantic search returning text chunks |
| `find_boat_documents` | Direct database query by app, equipment_id, job_id, doc_type, category, keyword search |
| `get_boat_document` | Get metadata for a specific document by ID |
| `list_boat_equipment` | Equipment lookup by system or search term |
| `sync_boat_docs` | Pull latest Google Docs into imaging service. Use when user says they updated the numbers doc or other tracked Google Docs. |

### Configuration

```json
// In ~/.claude.json under mcpServers:
"boat-docs": {
  "type": "stdio",
  "command": "node",
  "args": ["/path/to/imaging/mcp/server.js"],
  "env": { "IMAGING_URL": "http://192.168.22.15:3100" }
}
```

## Key Reference Documents

Some important documents in the imaging service aren't manuals — they're structured reference data. These won't surface well via RAG semantic search (numerical/tabular data embeds poorly), so fetch them directly when needed.

| Document | ID | What it contains |
|----------|----|------------------|
| S49 Polars Accurate.csv | `doc-1772406828325-jp1s` | Polar performance table: boat speed (knots) by TWA (degrees) × TWS (knots). Rows = wind angles 36°–180°, columns = wind speeds 4–30 kts. Fetch via `/api/v1/documents/{id}/file` and parse the CSV. |
| Distant Shores II Numbers | (synced from Google Docs, tagged `gdoc_id`) | Vessel registration numbers, MMSI, HIN, engine serial, passport numbers, emergency contacts, Fleet One dialing instructions, Caribbean MRCC numbers. Resync with `POST /admin/sync-gdocs`. |
| BoatRegistry.pdf | `doc-1771163742201` | Canadian vessel registration — home port, registration number, ownership details. |
| Southerly49 Spec.pdf | `doc-1772406908005-3epf` | Hull specs — LOA, beam, draft, displacement, sail area, tank capacities. |
| DSIIMastDrawing.pdf | `doc-1772406895146-v99v` | Mast dimensions and rigging layout drawing. |
| NMEA 2000 network diagram | `doc-1774487448549-0bzh` | N2K bus wiring layout — all networked devices and backbone connections. |
| LithiumWireDiagram.pdf | `doc-1772406935389-jqqk` | Battery and charging system wiring — Victron lithium refit architecture. |
| Yanmar wiring diagrams | `doc-1772406638213-7put`, `doc-1772406637629-ehm0` | Engine wiring (large format) and engine panel wiring. |
| DistantShoresEBIRB.pdf | (in `manuals/ebirb`) | EPIRB registration — HEX ID, MMSI, vessel details. |
| 4JH4 Parts catalog.pdf | `doc-1772406966315-u1d2` | Yanmar engine parts lookup with part numbers and diagrams. |

## Batch Scripts

| Script | Purpose |
|--------|---------|
| `scripts/ocr-manuals.js` | Batch OCR (`--app maintenance --dry-run`, `--reprocess`) |
| `scripts/embed-manuals.js` | Batch embed (`--app maintenance --rechunk`) |
| `scripts/batch-triage.js` | Batch AI triage (`--app maintenance --apply`) |
| `scripts/reembed-triaged.js` | Re-embed with synthesized text from triage data (`--app immigration --apply`) |
| `scripts/reclassify-docs.js` | Reclassify doc_type/caption from content (`--apply`) |
| `scripts/import-manuals.js` | Import manuals from source directory |

All scripts support `--dry-run`, `--app`, `--id`, `--limit` flags.

## Future Work

- **Cruising app chat UI** — conversation page calling `/api/v1/ask`
- **Structured context integration** — cruising app auto-injects DB records (fuel, immigration, jobs) alongside document queries
- **Replication** — rsync files + app-level PG sync between boat (centralsk) and home server
