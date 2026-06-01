---
name: command-centre
description: Command Centre is the homelab dashboard at http://192.168.20.19:8080. NetBox-backed service discovery; React/Vite SPA + Express backend; deployed via GHA → GHCR → docker compose pull on docker-server. Use when adding a dashboard panel, a new API proxy route, or troubleshooting why a service tile is showing wrong status. Also use when asked to "add a button to the home dashboard" or "show X on Command Centre".
---

# Command Centre Skill

The homelab dashboard at **http://192.168.20.19:8080**. Replaces the old hardcoded `homelab-dashboard` (v1) with a NetBox-backed service-discovery model (v2).

**Repo:** `dougkimmerly/command-centre` (private GitHub). Local clone: `/Users/doug/Programming/dkSRC/infrastructure/command-centre/`.

---

## Architecture in one screen

```
NetBox  ─────────────►  Backend (Express, port 8080)  ─────────────►  Frontend (React, served from same Express)
(service registry,                  │
custom fields)                      ├─►  DK/400 Postgres (qsys._healthchk_status — service health)
                                    ├─►  Boat cruising-app (http://192.168.22.15:3200 via Tailscale — resource planner, override)
                                    ├─►  Home SignalK (homesk.kbl55.com:3000 — weather, snowmelt)
                                    └─►  GitHub API, NPM, local docker, etc.
```

The backend is a proxy + aggregator. The frontend never talks to NetBox or anything else directly — everything goes through `/api/*` on the same origin.

---

## Critical rules

1. **NetBox is source of truth for tiles.** Don't add services to code. Edit NetBox, the dashboard reflects it.
2. **Health status comes from `qsys._healthchk_status` in DK/400 Postgres**, not hardcoded and not from NetBox.
3. **Tile categories** are defined in NetBox custom field choices (the `dashboard_category` select field). Adding a new category = edit the field choices in NetBox, no code change.
4. **No scheduling here** — this is a read-only dashboard, not a scheduler. Anything that needs to do work on a schedule lives in DK/400 or the boat's cruising-app.
5. **Idempotent** — safe to restart, refresh, or redeploy anytime. No mutable local state.

---

## Where things live

```
command-centre/
├── backend/src/index.js         # All routes. ~1200 lines. Grep for "app.get('/api/" to find them.
├── frontend/src/
│   ├── App.jsx                  # Main dashboard layout. Icon-button header, service grid, modals.
│   ├── HealthCheckPanel.jsx     # Health-status modal
│   ├── NetworkInfrastructurePanel.jsx
│   ├── SnowmeltPanel.jsx        # Home snowmelt control (override + events + feedback)
│   ├── BoatStarlinkPanel.jsx    # Boat Starlink manual override (Wyze-cam-access use case)
│   ├── WeatherHeader.jsx        # Top weather strip
│   ├── DK400Status.jsx, JobsPanel.jsx, ...
│   └── ServiceDetailModal.jsx   # Per-service detail modal (icon click)
├── deploy/compose.yaml          # SOP-compliant compose (uses GHCR image)
├── docker/Dockerfile            # Multi-stage: frontend build → backend + dist
└── .github/workflows/build.yml  # GHA build + push to ghcr.io on push to main
```

**Server-side files** (NOT in this repo — in `homelab-docker-server`):
- `/opt/docker-server/command-centre/compose.yaml` — production compose
- `/opt/docker-server/command-centre/.env` — secrets (NETBOX_TOKEN, GITHUB_TOKEN, GHCR_TOKEN, BOAT_CRUISING_URL, etc.)

---

## Deploy flow (every change ships this way)

```bash
# 1. Commit + push to the command-centre repo
git add -A && git commit -m "..." && git push

# 2. GitHub Actions builds + pushes image to ghcr.io/dougkimmerly/command-centre:latest
#    Watch: gh run list --limit 1 --workflow=build.yml
#    Typical: ~60s

# 3. Pull + restart on docker-server
ssh doug@192.168.20.19 "cd /opt/docker-server/command-centre && \
  source .env && echo \$GHCR_TOKEN | docker login ghcr.io -u dougkimmerly --password-stdin && \
  docker compose pull && docker compose up -d && docker logout ghcr.io"

# 4. Verify
curl -s http://192.168.20.19:8080/health
```

The `docker logout ghcr.io` is intentional — keeps credentials out of `~/.docker/config.json` between deploys (they live in `.env`, managed via Bitwarden).

---

## Adding a new panel — the recipe

The pattern in this repo is: header icon button → opens a modal → modal renders a Panel component → Panel does its own fetches against `/api/*` proxy routes that the backend adds.

Reference examples already in the repo:
- **Boat Starlink Override** (BoatStarlinkPanel.jsx + 4 backend proxy routes) — bidirectional control of a remote system via proxied REST.
- **Snowmelt** (SnowmeltPanel.jsx + signalk proxy routes) — same shape but talks to home SignalK directly.

### Backend (Express)

Add proxy routes in `backend/src/index.js`. For a remote system, write a small helper that handles GET/POST/PATCH/DELETE uniformly:

```js
async function proxyFooBar(method, body, res) {
  try {
    const fetchOpts = {
      method,
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000),
    };
    if (body !== undefined) fetchOpts.body = JSON.stringify(body);
    const r = await fetch(`${UPSTREAM_URL}/api/foo/bar`, fetchOpts);
    const text = await r.text();
    let parsed;
    try { parsed = JSON.parse(text); } catch { parsed = { error: 'upstream non-JSON' }; }
    res.status(r.status).json(parsed);
  } catch (err) {
    res.status(503).json({ error: 'upstream unreachable', message: err.message });
  }
}

app.get('/api/foo/bar',    (req, res) => proxyFooBar('GET',    undefined, res));
app.post('/api/foo/bar',   (req, res) => proxyFooBar('POST',   req.body,  res));
app.patch('/api/foo/bar',  (req, res) => proxyFooBar('PATCH',  req.body,  res));
app.delete('/api/foo/bar', (req, res) => proxyFooBar('DELETE', undefined, res));
```

If the upstream URL is configurable, add `const UPSTREAM_URL = process.env.FOO_URL || 'http://default:port';` near the top with the other env constants.

### Frontend (React)

1. **Create the Panel component** at `frontend/src/FooPanel.jsx`. Model it on `BoatStarlinkPanel.jsx` (simple) or `SnowmeltPanel.jsx` (richer with multiple sub-fetches).
2. **Wire it into App.jsx**:
   - Import: `import FooPanel from './FooPanel';` + the icon you want.
   - State: `const [showFooPanel, setShowFooPanel] = useState(false);`
   - Trigger: add a button to the icon row in the header (around line ~600, next to Network icon).
   - Modal: copy the existing snowmelt or boat-starlink modal block, swap component name + title.

### Tailwind / styling

- Use the existing color palette: `zinc-*` for chrome, accent colors (`emerald`, `orange`, `cyan`, `amber`, `red`) for state-specific UI.
- Modal pattern: full-screen `fixed inset-0 bg-black/50` overlay + centered `max-w-Xxl` panel with sticky header. Click overlay to close.
- For active/inactive state in a panel: `bg-{color}-500/10 border border-{color}-500/30 rounded-lg p-4`.

---

## Service tiles (the main grid)

Services on the dashboard come from NetBox, not code. To add/edit a service tile, edit the NetBox Device or VM custom fields. No code change or redeploy needed — backend re-fetches NetBox on each `/api/services` request.

### Full NetBox custom-field schema (canonical reference)

The dashboard reads these custom fields on `dcim.device` and `virtualization.virtualmachine`. Field definitions live in `scripts/setup-netbox-fields.py`.

| Field | Type | Purpose |
|---|---|---|
| `dashboard_category` | select | Tile group. Choices: `infrastructure`, `automation`, `dk400`, `homeapps`, `signalk`, `network`, `local`, etc. **Without this field set, the device is invisible to the dashboard.** |
| `dashboard_icon` | text | Icon path like `/icons/server.svg`. Falls back to inferred icon from name. |
| `dashboard_url` | url | Where the tile links to (external/public URL). |
| `dashboard_order` | integer | Sort order within category. |
| `check_type` | select | Health check type: `http`, `ping`, `docker`, `none`. |
| `check_url` | url | URL for HTTP health checks. |
| `github_repo` | text | GitHub repo for issue tracking (e.g., `dougkimmerly/cruising-app`). |
| `docs_url` | url | Documentation URL. |
| `has_ui` | boolean | Whether the service has a browsable UI. |
| `ssh_user` | text | Username for SSH (Context menu uses this). |

### Setup / recreate the field definitions

If the fields are missing from a fresh NetBox install (or got deleted), run:

```bash
cd scripts
NETBOX_TOKEN=nbt_<key>.<plaintext> python setup-netbox-fields.py
```

This creates field definitions only — does NOT populate per-device values.

### NetBox token format (v4.x)

Tokens are v2 by default: `nbt_<12-char-key>.<40-char-plaintext>`. The bare 40-char string alone is treated as v1 and rejected unless the matching row has `plaintext` set (which v2 tokens don't). When updating `.env`, paste the full `nbt_...` string. Generate via NetBox UI → Admin → Tokens, or via Django shell:

```python
from users.models import Token, User
t = Token(user=User.objects.get(username='admin'), description='your-purpose')
t.token = t.generate(); t.update_digest(); t.save()
print(f'nbt_{t.key}.{t.token}')  # full token for .env
```

---

## Health check data flow

```
DK/400 Health Checks  ──writes──►  qsys._healthchk_status (Postgres on docker-server:5433)
                                                │
                                                └──read by──►  Command Centre backend
                                                                  ├─► /api/services       (joins by name)
                                                                  ├─► /api/health/summary (aggregate)
                                                                  └─► /api/health/status  (raw)
```

Each health-check row keys on `target_name` (NetBox device/VM name, normalized to lowercase alphanumeric). The dashboard backend lowercases + strips non-alphanumeric on both sides before joining.

Required grant: `GRANT SELECT ON qsys._healthchk_status TO dk400;` (if Command Centre's connection user changes).

### API format mapping — when /api/healthchecks/* calls DK/400

DK/400's `POST /pgm/health_status` wraps results in a program envelope. Backend unwraps `.result` and maps fields for the frontend:

| DK/400 (`response.result.results[]`) | Frontend expects (`checks[]`) |
|---|---|
| `target_name` | `check_name` |
| `target_type` | `check_type` |
| `error_message` | `last_result.error` |
| `last_check` | `last_checked` |

Historical note: the old `GET /api/healthchecks/results` convenience route was removed when `dk400-homelab` extracted its platform engine (2026-02). Anything calling the old route will get 404.

---

## Important env vars

| Var | Default | Used for |
|-----|---------|----------|
| `PORT` | `8080` | Express listen port |
| `NETBOX_URL` | `http://192.168.20.19:8000` | NetBox API |
| `NETBOX_TOKEN` | `(secret)` | NetBox auth |
| `SIGNALK_URL` | `http://homesk.kbl55.com:3000` | **Home** SignalK (snowmelt, weather) |
| `SIGNALK_TOKEN` | `(secret)` | SignalK PUT auth |
| `BOAT_CRUISING_URL` | `http://192.168.22.15:3200` | **Boat** cruising-app (resource planner, override endpoints) |
| `DK400_DB_URL` | `postgresql://dk400:...@192.168.20.19:5433/dk400` | DK/400 Postgres (health status, jobs) |
| `DK400_WEB_URL` | `http://192.168.20.19:8400` | DK/400 web UI (for tile links) |
| `BRAIN_URL_PRIMARY` / `BACKUP` | `http://192.168.20.19:8420` / `192.168.20.16:8420` | Legacy health monitor (homelab-brain) |
| `GHCR_TOKEN` | `(secret)` | `docker login` to pull image |

All secrets live in `/opt/docker-server/command-centre/.env` and Bitwarden.

---

## Debugging — common issues

- **Service tile shows "unknown" status** → check `qsys._healthchk_status` has a row for that name. The health monitor writes there from boat + home health checks.
- **NetBox unreachable** → `/health` returns `{"status":"degraded","netbox":"unavailable"}`. Check NetBox container is running on docker-server.
- **Boat proxy routes 503** → boat unreachable via Tailscale. Test: `curl http://192.168.22.15:3200/health` from docker-server.
- **Frontend changes not visible after deploy** → image cache. Try `docker compose pull --no-cache` or `docker compose up -d --force-recreate`. Hard-refresh the browser (Cmd-Shift-R) to clear the SPA bundle.
- **CI build failed** → `gh run view --log-failed` for the latest run. Most common: JSX syntax error, missing import. Run `npx esbuild --bundle src/FooPanel.jsx ...` locally before pushing to catch these.

---

## Related skills
- [[homelab-docker-server]] — where command-centre actually runs
- [[netbox]] — the source of truth for service tiles
- [[homelab-dk400]] — the health-status writer
