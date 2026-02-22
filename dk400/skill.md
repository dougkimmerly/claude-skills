# DK/400 Development Skill

AS/400-inspired platform with green screen web TUI, Robot (Celery Beat scheduler), API (FastAPI), and programs layer. Runs on PostgreSQL with supervisord managing all processes in a single container.

## Repository Structure

DK/400 has three repositories plus two deployment repos:

### Platform Engine: `dk400`
- **URL:** https://github.com/dougkimmerly/dk400
- **Purpose:** Core AS/400 platform — 5250 terminal, commands, qsys schema, Robot, API, Web
- **Local Path:** `/Users/doug/Programming/dkSRC/platform/dk400/`
- **Used as:** `engine/` submodule in deployment repos

### Shared Programs: `dk400-programs`
- **URL:** https://github.com/dougkimmerly/dk400-programs
- **Purpose:** Programs shared between all dk400 deployments
- **Local Path:** `/Users/doug/Programming/dkSRC/infrastructure/dk400-programs/`
- **Contains:** health_check, send_telegram, report_issue, daily_report, disk_space, etc.
- **Used as:** `shared/` submodule in deployment repos

### House Deployment: `dk400-homelab`
- **URL:** https://github.com/dougkimmerly/dk400-homelab
- **Purpose:** Homelab-specific deployment on Docker Server (.19)
- **Local Path:** `/Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/`
- **Server Path:** `/home/doug/dkSRC/infrastructure/dk400-homelab/`

### Boat Deployment: `dk400-boat`
- **URL:** https://github.com/dougkimmerly/dk400-boat
- **Purpose:** Boat deployment on CentralSK (.15)
- **Local Path:** `/Users/doug/Programming/dkSRC/infrastructure/dk400-boat/`
- **Server Path:** `/opt/dk400-boat/`

### Deployment Repo Structure (both follow this pattern)
```
dk400-homelab/  (or dk400-boat/)
├── engine/              # dk400 platform (submodule)
├── shared/              # dk400-programs (submodule)
├── programs/            # Deployment-specific programs
│   └── __init__.py
├── compose.yaml         # dk400 + redis + flower
├── Dockerfile           # Merges engine + shared + programs
├── supervisord.conf     # Runs Robot + API + Web in one container
├── requirements.txt     # Deployment-specific deps
└── .env.example
```

**Dockerfile COPY layering:** `COPY shared/ ./programs/` then `COPY programs/ ./programs/` — shared programs copied first, then deployment-specific programs overlay. Both end up in the container's `programs/` directory.

**IMPORTANT:** Do NOT mount `./programs:/app/programs:ro` in compose.yaml — this would hide shared programs baked into the image at build time.

## Quick Reference

### Deployment

```bash
# Deploy to house (.19)
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull && git submodule update --remote shared && docker compose build --no-cache dk400 && docker compose up -d dk400"

# Deploy to boat (.15)
ssh doug@192.168.22.15 "cd /opt/dk400-boat && git pull && git submodule update --remote shared && docker compose build --no-cache dk400 && docker compose up -d dk400"

# Check logs
ssh doug@192.168.20.19 "docker logs dk400 --tail 50"
```

### URLs

**House:**
- **API:** http://192.168.20.19:8400
- **Web UI:** http://192.168.20.19:8500
- **Flower:** http://192.168.20.19:5555

**Boat:**
- **API:** http://192.168.22.15:8400
- **Web UI:** http://192.168.22.15:8500
- **Flower:** http://192.168.22.15:5555

### Default Users

| User | Password | Class | Notes |
|------|----------|-------|-------|
| QSECOFR | QSECOFR | *SECOFR | Security Officer |
| QSYSOPR | QSYSOPR | *SYSOPR | System Operator |
| QUSER | QUSER | *USER | Default User |
| DOUG | TEST | *SECOFR | Test user (password reset) |

### Containers

Each deployment runs three containers:
- **dk400** — Single container with supervisord (Robot + API + Web)
- **dk400-redis** — Redis for Celery job queue
- **dk400-flower** — Celery task monitor

### Site Filtering

Each deployment sets `SITE_SLUG` env var to its NetBox site slug:
- House: `SITE_SLUG=homelab`
- Boat: `SITE_SLUG=boat`

Health checks only monitor targets assigned to the deployment's site.

---

## Database Architecture

### Consolidated Database

DK/400 uses a single PostgreSQL instance with multiple schemas, following the AS/400 library model:

```
dk400-postgres (single instance per site)
└── DATABASE: dk400
    ├── SCHEMA: qsys       -- System library (journaling, users, jobs)
    ├── SCHEMA: qgpl       -- General purpose library
    ├── SCHEMA: fixer      -- Unified issues, actions, remediation
    ├── SCHEMA: netbox     -- Infrastructure DCIM/IPAM
    ├── SCHEMA: bitwarden  -- Password vault
    ├── SCHEMA: galley     -- Recipe and meal planning
    └── SCHEMA: musiclib   -- Music library
```

### Library = PostgreSQL Schema

- `QSYS` = `qsys` schema (system library)
- `QGPL` = `qgpl` schema (general purpose)
- User libraries = user-created schemas

**CRITICAL:** Always use `qsys.tablename` in SQL queries, never just `tablename`.

---

## Git Workflow

### Updating Platform Engine (dk400)
```bash
cd /Users/doug/Programming/dkSRC/platform/dk400
# Make changes
git commit -am "Description"
git push origin main  # Push to PUBLIC dk400 repo

# Update submodule reference in deployment repo
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab
git add engine
git commit -m "Update dk400 engine submodule"
git push
```

### Updating Shared Programs (dk400-programs)
```bash
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-programs
# Make changes
git commit -am "Description"
git push

# Update submodule in both deployment repos
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab
git submodule update --remote shared && git add shared && git commit -m "Update shared programs" && git push
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-boat
git submodule update --remote shared && git add shared && git commit -m "Update shared programs" && git push
```

### Updating Deployment-Specific Programs
```bash
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab  # or dk400-boat
# Edit programs/*.py
git commit -am "Description"
git push
```

---

## Adding New Commands

1. **Register in COMMANDS dict** (`screens.py`):
```python
COMMANDS = {
    'NEWCMD': 'newscreen',
}
```

2. **Add description** (`screens.py` COMMAND_DESCS)

3. **Create screen method** (`screens.py`):
```python
def _screen_newscreen(self, session: Session) -> dict:
    hostname, date_str, time_str = get_system_info()
    content = [
        pad_line(f" {hostname:<20}   Screen Title               {session.user:>10}"),
        pad_line(f"                                                          {date_str}  {time_str}"),
        # ... content ...
    ]
    return {"type": "screen", "screen": "newscreen", "cols": 80, "content": content, "fields": [], "activeField": 0}
```

4. **Create submit handler** if needed

5. **Add F12 cancel handler** in `handle_function_key`

---

## Common Issues

### psycopg2 % Escape in LIKE Patterns
```python
# Wrong:
cursor.execute("SELECT * FROM t WHERE name NOT LIKE '\\_%'", ())
# Correct:
cursor.execute("SELECT * FROM t WHERE name NOT LIKE '\\_%%'", ())
```

### Dict Cursor with SELECT EXISTS
```python
# Wrong: cursor.fetchone()[0]
# Correct: cursor.fetchone()['exists']
```

### WebSocket Disconnects
Silent exceptions in screen methods cause disconnects. Use `.get()` with defaults, check for None.

---

## Testing

```bash
# Syntax check
python3 -m py_compile dk400/web/screens.py
python3 -m py_compile dk400/web/database.py

# Database test
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U dk400 -c 'SELECT * FROM qsys.users;'"

# Function test
ssh doug@192.168.20.19 "docker exec dk400 python3 -c 'from dk400.web.database import get_library_objects; print(get_library_objects(\"QSYS\", \"*FILE\"))'"
```
