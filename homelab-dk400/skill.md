# Homelab DK/400 Instance Skill

This skill covers the specific deployment of DK/400 at Doug's homelab. For generic DK/400 development (screens, database, commands), see the **dk400 skill** in `dk400/.claude/skills/dk400/skill.md`.

**Always load both skills when working on this instance.**

**Central Skills Repo:** `infrastructure/claude-skills/homelab-dk400/skill.md`

---

## Instance Overview

| Property | Value |
|----------|-------|
| **System Name** | HOMELAB |
| **Server** | Ubuntu 192.168.20.19 (docker-server) |
| **Web UI** | http://192.168.20.19:8400 |
| **Flower** | http://192.168.20.19:5555 |
| **Database Port** | 5433 (exposed) |

---

## Repository Structure

```
homelab-dk400/                    # This repo (private)
├── dk400/                        # Public repo (git submodule)
│   └── src/dk400/...             # All AS/400 simulation code
├── tasks/                        # Private Celery tasks
│   ├── __init__.py
│   ├── notifications.py          # Telegram via comms service
│   ├── backup.py                 # All backup jobs
│   ├── health.py                 # Container monitor, daily report
│   ├── maintenance.py            # VPN rotation, log cleanup
│   └── infrastructure.py         # Docker sync, dashboard
├── celery_app.py                 # Extends dk400 with homelab schedule
├── db_scheduler.py               # Database-backed job scheduler
├── populate_schedule.py          # Populates QSYS._JOBSCDE
└── Dockerfile                    # Builds image with submodule + tasks
```

---

## Deployment

### Server Directory Structure

```
/opt/docker-server/homelab-dk400/
├── compose.yaml                  # THE ONLY compose file (deployment)
├── deploy.sh                     # Canonical deploy script
├── .env                          # Secrets (POSTGRES_ADMIN_PASSWORD, etc.)
├── postgres/
│   ├── data/                     # PostgreSQL data
│   └── init/                     # Init scripts (01-create-databases.sql)
├── redis/
│   └── data/                     # Redis persistence
├── code/                         # Git clone of homelab-dk400
│   ├── dk400/                    # Public submodule
│   └── tasks/                    # Private tasks
└── backups/                      # Local backup staging
```

**IMPORTANT:** There is NO docker-compose.yml in the repo. The repo contains only code. The server's `compose.yaml` is deployment-specific and lives outside the code directory.

### Deploy Commands

```bash
# ALWAYS use the deploy script
ssh doug@192.168.20.19 "cd /opt/docker-server/homelab-dk400 && ./deploy.sh"

# Force rebuild (cache issues)
ssh doug@192.168.20.19 "cd /opt/docker-server/homelab-dk400 && ./deploy.sh --rebuild"

# Check container status
ssh doug@192.168.20.19 "docker ps --filter 'name=dk400-'"

# View logs
ssh doug@192.168.20.19 "docker logs dk400-web --tail 50"
ssh doug@192.168.20.19 "docker logs dk400-qbatch --tail 50"
```

### What deploy.sh Does

1. Verifies running from correct directory (`/opt/docker-server/homelab-dk400`)
2. Pulls latest code from GitHub
3. Updates submodules
4. Rebuilds containers if code changed (or with `--rebuild`)
5. Restarts all containers
6. Shows status and confirms Beat schedule sync

### Git Workflow

```bash
# Update public dk400 (AS/400 simulation code)
cd /Users/doug/Programming/dkSRC/infrastructure/homelab-dk400/dk400
# Make changes...
git commit -am "Description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push origin main  # Push to PUBLIC dk400 repo

# Update private homelab-dk400 (tasks, config)
cd /Users/doug/Programming/dkSRC/infrastructure/homelab-dk400
git add dk400  # Update submodule reference if dk400 changed
git commit -m "Description"
git push
```

---

## Container Architecture

All containers use `dk400-` prefix as one unified system:

| Container | Purpose | Compose Service |
|-----------|---------|-----------------|
| dk400-postgres | Central database | dk400-postgres |
| dk400-redis | Job queues, state | dk400-redis |
| dk400-qbatch | Celery worker (QBATCH subsystem) | dk400-qbatch |
| dk400-beat | Celery scheduler (job scheduler) | dk400-beat |
| dk400-web | 5250 terminal + API | dk400-web |
| dk400-flower | Job monitoring (optional) | dk400-flower |

---

## Consolidated Database

Single PostgreSQL instance with multiple schemas (AS/400 library model):

```
dk400-postgres
└── DATABASE: dk400
    ├── SCHEMA: qsys       -- DK/400 system
    ├── SCHEMA: qgpl       -- General purpose
    ├── SCHEMA: brain      -- Homelab-brain data
    ├── SCHEMA: galley     -- Meal planner
    ├── SCHEMA: musiclib   -- Music library (33k tracks)
    ├── SCHEMA: netbox     -- Infrastructure DCIM/IPAM
    └── SCHEMA: bitwarden  -- Password vault
```

**Connection info:**
```
Host: dk400-postgres (internal) / 192.168.20.19:5433 (external)
Admin: homelab_admin / ${POSTGRES_ADMIN_PASSWORD}
DK400: dk400 / ${DK400_DB_PASSWORD}
```

**MANDATORY RULE:** Always backup before structural changes:
```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres pg_dump -U homelab_admin dk400 > /home/doug/backups/dk400_$(date +%Y%m%d_%H%M%S).sql"
```

---

## Private Celery Tasks

### Task Files

| File | Tasks | Purpose |
|------|-------|---------|
| `notifications.py` | `send_telegram()` | Telegram alerts via comms |
| `backup.py` | Various backup tasks | rsync/pg_dump backups |
| `health.py` | `container_monitor`, `daily_report`, `job_monitor` | Health checks |
| `maintenance.py` | `vpn_rotation`, `cleanup_logs`, `pihole_heartbeat` | System maintenance |
| `infrastructure.py` | `sync_dashboard`, `service_reconciliation` | Infrastructure sync |

### Task Classification

**Run Directly in Celery:**
- Container monitoring (SSH + docker ps)
- VPN rotation (SSH script execution)
- All backups (rsync/pg_dump)
- Dashboard sync (HTTP)
- Log cleanup (delete old history)

**Keep in Brain (AI Required):**
- Daily health report (aggregation, AI formatting)
- Log pattern analysis
- Synology scans (Claude Vision OCR)
- NetBox/NetAlertX sync (complex discovery)

---

## Container Health Monitoring

### Configuration (`tasks/health.py`)

```python
CONTAINER_HOSTS = {
    'docker-server': {
        'ssh_target': 'doug@192.168.20.19',
        'docker_cmd': 'docker',
        'critical': [
            'nginx-proxy-manager',
            'portainer',
            'homelab-dashboard',
            'homelab-brain',
            'dk400-web',
            'dk400-postgres',
            'dk400-qbatch',
            'dk400-beat',
        ],
    },
    'synology': {
        'ssh_target': 'doug@192.168.20.16',
        'docker_cmd': 'sudo /usr/local/bin/docker',
        'critical': [
            'gluetun',
            'radarr',
            'sonarr',
            'prowlarr',
        ],
    },
}
```

### Hysteresis Settings

```python
CONTAINER_DOWN_THRESHOLD_MINUTES = 5   # Wait before alerting
ALERT_COOLDOWN_MINUTES = 30            # Don't re-alert same container
```

### State Tracking (Redis)

Keys: `container_down:{host}:{container}`
```json
{
  "first_seen": "2026-01-21T10:00:00",
  "last_alerted": "2026-01-21T10:05:00"
}
```

### Self-Healing Flow

```
Container down detected
         ↓
   Track in Redis, wait 5 minutes
         ↓
   Still down after 5m?
         ↓
   Call Brain /api/containers/heal
         ↓
   Brain attempts: restart → analyze logs → advanced fixes
         ↓
   ┌─────┴─────┐
Healed?     Can't fix?
   ↓            ↓
Clear       Send Telegram
tracking    (only on failure)
```

### Health API Endpoint

DK/400 exposes container health for Dashboard:

```
GET http://192.168.20.19:8400/api/health/services

Response:
{
  "timestamp": "2026-01-21T16:07:13",
  "summary": {"total": 12, "ok": 12, "down": 0, "unknown": 0},
  "services": [
    {"host": "docker-server", "name": "dk400-web", "status": "ok", "message": null},
    ...
  ]
}
```

---

## Backup Configuration

### Paths

```python
SYNOLOGY_BACKUP_BASE = '/volume1/backups/docker-server'
UBUNTU_BACKUP_BASE = '/home/doug/backups/synology'
```

### Backup Tasks

| Task | Source | Destination | Method |
|------|--------|-------------|--------|
| `musiclib_postgres` | Synology .16 | Ubuntu .19 | pg_dump |
| `bitwarden` | Ubuntu .19 | Synology .16 | rsync |
| `nginx_proxy_manager` | Ubuntu .19 | Synology .16 | rsync |
| `home_assistant` | Ubuntu .19 | Synology .16 | rsync |
| `galley` | Ubuntu .19 | Synology .16 | rsync |
| `arrstack` | Synology .16 | Ubuntu .19 | rsync |
| `dk400_postgres` | dk400-postgres | Synology .16 | pg_dump |

---

## VPN Rotation

Stored in `qsys._vpnstate`:

```sql
CREATE TABLE qsys._vpnstate (
    id INTEGER PRIMARY KEY DEFAULT 1,
    last_rotation TIMESTAMP,
    next_rotation TIMESTAMP,
    rotation_count INTEGER DEFAULT 0
);
```

Rotation interval: random 1.2-2.6 days.

---

## Telegram Notifications

```python
from tasks.notifications import send_telegram

send_telegram("🚨 Alert message")
send_telegram("*Bold* and `code`", parse_mode="Markdown")
```

**Comms service:** `http://192.168.20.19:3500/api/send`

---

## Brain Integration

Brain API: `http://192.168.20.19:8420`

Tasks that call Brain:
```python
# Daily health report (AI aggregation)
response = client.post(f'{BRAIN_API}/api/health/daily-report',
                      json={'hours': 24, 'notify': True})

# Container self-healing
response = client.post(f'{BRAIN_API}/api/containers/heal',
                      json={'host': 'docker-server', 'container': 'nginx-proxy-manager'})
```

---

## Testing

### Run Task Manually

```bash
# Via Celery
ssh doug@192.168.20.19 "docker exec dk400-qbatch celery -A celery_app call tasks.health.container_monitor"

# Check result in WRKJOBHST via 5250 terminal
```

### Direct Container Test

```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.database import get_library_objects
print(get_library_objects(\"QSYS\", \"*ALL\")[:5])
'"
```

### Database Query

```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U dk400 -d dk400 -c 'SELECT * FROM qsys.users;'"
```

### Password Reset

```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.users import user_manager
print(user_manager.change_password(\"USERNAME\", \"NEWPASS\"))
'"
```

---

## Default Users

| User | Password | Class | Notes |
|------|----------|-------|-------|
| QSECOFR | QSECOFR | *SECOFR | Security Officer |
| QSYSOPR | QSYSOPR | *SYSOPR | System Operator |
| QUSER | QUSER | *USER | Default User |
| DOUG | TEST | *SECOFR | Test user |

---

## Related Services

| Service | URL | Purpose |
|---------|-----|---------|
| Dashboard | http://192.168.20.19:8080 | Homelab dashboard |
| Brain | http://192.168.20.19:8420 | AI reasoning service |
| Comms | http://192.168.20.19:3500 | Telegram notifications |
| Galley | http://192.168.20.19:8082 | Meal planner |

---

## Troubleshooting

### WebSocket Disconnects

Silent errors cause disconnects. Test screen method:
```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.screens import ScreenManager
from src.dk400.web.session import Session
sm = ScreenManager()
s = Session()
s.user = \"DOUG\"
print(sm._screen_main_menu(s))
'"
```

### Container Can't Find Database

Check hostname resolution:
```bash
ssh doug@192.168.20.19 "docker exec dk400-web ping -c1 dk400-postgres"
```

Verify environment variables in compose.yaml point to `dk400-postgres`.

### Task Not Running

1. Check beat is running: `docker logs dk400-beat --tail 20`
2. Check schedule: `SELECT * FROM qsys._jobscde WHERE status = 'SCHEDULED';`
3. Check Redis connection: `docker exec dk400-redis redis-cli ping`

---

## Critical Lessons

### Database Loss Incident (2026-01-21)

When postgres container was recreated without proper init script, all dk400 data was lost (recovered from backup).

**Prevention:**
1. Init script MUST create dk400 database and user
2. Volume mounts MUST point to correct data directory
3. ALWAYS backup before structural changes
4. Never rely on cached container state

### Duplicate Compose File Incident (2026-01-21)

Containers were accidentally started from `/home/doug/dkSRC/` instead of `/opt/docker-server/homelab-dk400/`, causing dk400-postgres to not run and breaking the entire system.

**Prevention:**
1. NO docker-compose.yml in the repo - removed entirely
2. Server has only ONE compose file at deployment location
3. Deploy script verifies correct directory before running
4. Development happens on Mac, not on server - no dev repos on server

### Phantom Healthcheck Escalation Incident (2026-01-22)

Brain's Claude created an incorrect `postgres-homelab` container (postgres:15-alpine on port 5432) instead of `dk400-postgres`. Root cause: DK/400 was checking a phantom service called "PostgreSQL" that no longer existed in Dashboard config but still had stale tracking keys in Redis.

**What happened:**
1. A healthcheck for "PostgreSQL" existed in Redis cache but was removed from Dashboard
2. DK/400 ran the check, got "Container not found"
3. DK/400 escalated `target="PostgreSQL"` to Brain's `/api/fixer/heal`
4. Brain's Claude misinterpreted and created wrong container

**Redis database layout:**
- **db 0**: Celery broker (job queues)
- **db 1**: Celery results + healthcheck config/tracking

**Stale tracking keys to check:**
```bash
# List health_down tracking keys
ssh doug@192.168.20.19 "docker exec dk400-redis redis-cli -n 1 KEYS 'health_down:*'"

# Delete stale keys
ssh doug@192.168.20.19 "docker exec dk400-redis redis-cli -n 1 DEL health_down:docker:PostgreSQL"
```

**Prevention:**
1. When removing healthchecks from Dashboard, also clear Redis tracking keys
2. Healthcheck config syncs from Dashboard - check `healthcheck_config` key in db 1
3. Monitor for orphaned `health_down:*` keys that reference non-existent checks

### Logging Persistence (2026-01-22)

Docker `json-file` logging driver persists across container **restarts** but NOT **recreations**. Since `deploy.sh` does `docker compose down && up`, logs were lost after each deploy.

**Solution:** Use `journald` logging driver which writes to systemd journal:

```yaml
logging:
  driver: journald
  options:
    tag: dk400-postgres
```

**Querying logs:**
```bash
# All DK/400 logs
journalctl -t 'dk400-*' --since "1 hour ago"

# Specific container
journalctl -t dk400-postgres --since "1 hour ago"

# Follow logs
journalctl -t dk400-qbatch -f
```

All containers use `dk400-` prefix tags for easy filtering.
