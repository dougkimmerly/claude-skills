---
name: imaging-expert
description: Imaging service development expertise for the shared document/image storage system on Distant Shores II. Use when uploading, storing, querying, or serving documents and images from any app — maintenance, clearing, inventory, manuals, galley, boat-log. Covers REST API, WebDAV scanning, scan sessions, XMP metadata, thumbnails, full-text search, and client integration.
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
  - invoice
  - manual
  - attachment
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
| File Processing | Sharp (thumbnails, HEIC), exiftool-vendored (XMP), pdftoppm (PDF thumbnails) |
| Upload | Multer (multipart), WebDAV (Genius Scan+) |
| Container | Docker (node:20-alpine + vips-dev + perl + poppler-utils) |
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
│   └── xmp.js             # ExifTool: embed metadata into JPEG/PNG/PDF files
├── schema/
│   └── 002-documents.sql  # Table, 7 indexes, auto-update trigger
├── scripts/
│   ├── migrate-from-docstore.js  # One-time migration from old DocumentStore
│   ├── backfill-xmp.js           # Embed XMP into existing documents
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

### Search

```
GET    /search?q=fuel+filter   Full-text search across caption + extracted_text
                                Optional: &app=&limit=
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
GET    /health                 { status, postgres, documents, storage, uptime }
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

## Future Work

- **Replication** — rsync files + app-level PG sync between boat (centralsk) and home server
- **Manuals Knowledge Base** — import ~595 marine equipment manuals, OCR with Tesseract, pgvector embeddings for semantic search
- **RAG** — pgvector column, chunking pipeline, embedding generation, natural-language document queries
