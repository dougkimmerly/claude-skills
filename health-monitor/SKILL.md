---
name: health-monitor
description: Diagnose and fix health monitoring issues
triggers:
  - health monitor
  - health check
  - health_check not working
location: project
---

# Health Monitor Troubleshooting

Guide for diagnosing and fixing health monitoring issues in the homelab.

## Architecture

Health monitoring is a **dk400 program**, not a separate daemon.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      dk400 Robot Scheduler                           │
│                    (runs health_check every 60s)                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│              health_check.py Program                                 │
│          (dk400-homelab/dk400/programs/health_check.py)             │
├─────────────────────────────────────────────────────────────────────┤
│ 1. Reads targets from NetBox (VMs/devices with check_enabled=true)  │
│ 2. Performs HTTP/HTTPS, TCP, ping, or docker checks                 │
│ 3. Writes results to qsys._healthchk_* tables                       │
│ 4. Cleans up orphan entries (deleted/disabled targets)              │
│ 5. Detects flapping (3+ status changes in 10 min)                   │
│ 6. Creates issues via report_issue for failures                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Key insight:** There is NO separate health-monitor container. The homelab-brain repo's health_monitor daemon is deprecated - all health checking runs through dk400.

## Key Files

| File | Purpose |
|------|---------|
| `dk400-homelab/dk400/programs/health_check.py` | Main health check program |
| `dk400-homelab/dk400/robot/schedules.py` | Schedule (every 60 seconds) |
| `qsys._healthchk_status` | Current status per target |
| `qsys._healthchk_flapping` | Flapping detection state |

## Database Tables

### qsys._healthchk_status
Current status for each monitored target.

```sql
-- Check current status
SELECT target_name, status, error_message, last_check
FROM qsys._healthchk_status
ORDER BY status DESC, target_name;

-- Find down services
SELECT target_name, status, error_message, last_check
FROM qsys._healthchk_status
WHERE status = 'down';
```

### qsys._healthchk_flapping
Tracks status changes to detect flapping.

```sql
-- Schema (as of Jan 2026)
target_key TEXT PRIMARY KEY
state_changes TEXT  -- JSON array of recent changes
last_change TIMESTAMPTZ
is_flapping BOOLEAN
window_start TIMESTAMPTZ
last_alert_at TIMESTAMPTZ
```

## Diagnostic Steps

### Step 1: Check if health_check is running

```bash
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep health_check | tail -10"
```

**Look for:**
- `Running program: health_check` - Program is being scheduled
- `Program health_check completed` - Successful run
- `Program health_check failed:` - Error occurred

### Step 2: Check for schema errors

Common error patterns:

| Error | Cause | Fix |
|-------|-------|-----|
| `column "X" does not exist` | Schema mismatch | Add missing column with ALTER TABLE |
| `'str' object cannot be interpreted as an integer` | Column type mismatch | ALTER COLUMN to correct type |
| `relation "X" does not exist` | Missing table | Check if migrations ran |

**Example fixes:**
```sql
-- Add missing column
ALTER TABLE qsys._healthchk_flapping ADD COLUMN IF NOT EXISTS last_change TIMESTAMPTZ;

-- Fix column type
ALTER TABLE qsys._healthchk_flapping ALTER COLUMN state_changes TYPE TEXT;
```

### Step 3: Check Robot scheduler status

```bash
# Is robot running?
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep -E 'robot|celery' | tail -20"

# Check for syntax errors in schedules
ssh doug@192.168.20.19 "python3 -m py_compile /home/doug/dkSRC/infrastructure/dk400-homelab/dk400/robot/schedules.py && echo 'Syntax OK'"
```

**If robot crashed:**
- Check schedules.py for syntax errors
- Fix the file and restart: `docker restart dk400`

### Step 4: Check NetBox targets

```bash
# How many targets have check_url set?
ssh doug@192.168.20.19 'source /home/doug/dkSRC/infrastructure/homelab-brain/.env && curl -s -H "Authorization: Bearer $NETBOX_API_TOKEN" "http://192.168.20.19:8000/api/virtualization/virtual-machines/?has_primary_ip=true&limit=200" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len([r for r in d[\"results\"] if r[\"custom_fields\"].get(\"check_url\")]))"'
```

## Common Issues

### 1. Health checks not running

**Symptoms:** `_healthchk_status.last_check` is stale

**Diagnose:**
```bash
# Check last check time
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"SELECT MAX(last_check) FROM qsys._healthchk_status;\""

# Check dk400 logs for errors
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep -E 'health_check|error' | tail -20"
```

**Common causes:**
- Robot scheduler crashed (check schedules.py syntax)
- Database schema mismatch
- NetBox API token expired

### 2. Service shows "down" but is actually up

**Diagnose:**
```bash
# Check what health_check sees
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"SELECT target_name, error_message FROM qsys._healthchk_status WHERE target_name LIKE '%service_name%';\""

# Manual check
curl -I http://service_url
```

**Common causes:**
- Wrong check_url in NetBox (check for redirects - use final URL path)
- Service behind VPN (not accessible from dk400)
- Check timeout too short
- **Flakey primary NIC on a multi-homed host.** Ping checks without a `check_url` fall back to the device's `primary_ip4`. If `primary_ip4` is an unreliable interface (e.g. WiFi on a box that's also wired), the check false-alarms DOWN while the host is up on its other NIC. Fix: point `primary_ip4` at the reliable interface. (55videoserver 2026-06-13: ~13k false DOWNs because primary was WiFi `.201`; set primary to Ethernet `.12` — both NICs stay assigned, the flakey one just isn't the up/down signal.)

**Error message interpretation (since Jan 2026):**
- `Device unreachable: {host}` → Ping failed, likely network/power issue
- `Service down (device pingable): {error}` → Ping works but HTTP failed, application issue
- `HTTP 5xx` → Service responding but with error

### 3. Stale entries for removed services

**Fix:** Mark as decommissioned in NetBox (don't delete):
```bash
# Find the VM ID
curl -s -H "Authorization: Bearer $TOKEN" "http://192.168.20.19:8000/api/virtualization/virtual-machines/?name__ic=service_name"

# Update status to decommissioning
curl -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"status": "decommissioning"}' \
  "http://192.168.20.19:8000/api/virtualization/virtual-machines/{ID}/"
```

**Why not delete:** Keeps historical context. Health_check skips non-active VMs automatically.

### 3b. SignalK webapp discovery drift ("webapp missing on <SK server>")

`check_signalk_webapp_discovery()` (in `health_check.py`) compares every NetBox `ipam_service` attached to a SignalK VM against that server's live `/skServer/webapps`, raising a **"missing"** issue for any NetBox service not present on the server.

**Diagnose** — establish ground truth before touching NetBox:
```bash
# what the probe actually compares against (the VM's check_url host; strip /admin)
curl -s http://<sk-host>/skServer/webapps | python3 -c 'import sys,json;[print(w["name"]) for w in json.load(sys.stdin)]' | sort
# what NetBox thinks is on that VM
psql ... -c "SELECT id,name FROM netbox.ipam_service WHERE parent_object_id=<vm_id> ORDER BY name;"
```
A **"missing" webapp means it was retired or moved** off that server (NetBox is stale) — not that it crashed. Reconcile NetBox to reality: remove the stale `ipam_service`, or move it to the SK VM that now hosts it. **Caveat:** the probe has no *retired* concept, so a retired webapp re-flags every cycle until its service record is removed — which conflicts with mark-don't-delete (tracked as enhancement #746: make the probe skip a retired-tagged service). Worked example 2026-06-13: 5 Nav Net webapps (boat-log-app, crew-checklist, passage-planner, sail-work-planner, signalk-maintenance-jobs) moved to centralsk:3000 / rewritten+retired; removing the 5 stale services stopped ~190k false "missing" occurrences.

### 4. Duplicate monitoring (container_health vs health_check)

**Resolution:** container_health was removed in Jan 2026. All monitoring now goes through health_check which:
- Reads targets from NetBox (single source of truth)
- Performs HTTP checks (confirms service responds, not just container runs)
- Respects NetBox status (skips decommissioned/offline)

### 5. NetBox changes not reflected in health status

**Symptoms:** Audit shows "missing" items that should be monitored, or names don't match

**Causes and fixes:**

| Change in NetBox | Impact | Fix |
|------------------|--------|-----|
| Renamed device/VM | Old name in `_healthchk_status`, audit shows "missing" | Update `target_name` in status table |
| Status changed to "offline"/"planned" | Device skipped by health_check | Set status to "active" if device is running |
| check_enabled on non-active device | Audit expects entry that won't exist | Set `check_enabled=false` on planned/offline devices |

**Manual fix for renamed item:**
```sql
UPDATE qsys._healthchk_status
SET target_name = 'NewName'
WHERE target_id = ID AND target_type = 'vm';
```

### 6. Issues not auto-resolving when device recovers

**Symptoms:** Device is UP but issue stays open/escalated

**Cause:** The `resolve_health_issue()` function must check BOTH statuses:
```sql
WHERE status IN ('open', 'escalated')  -- NOT just 'open'
```

**Check:** Look at issue status vs health status:
```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT ui.source_name, ui.status as issue_status, hs.status as health_status
FROM fixer.unified_issues ui
LEFT JOIN qsys._healthchk_status hs ON ui.source_name = hs.target_name
WHERE ui.status NOT IN ('resolved', 'ignored')
  AND hs.status = 'up';\""
```

If issues show with health_status='up', the auto-resolve isn't working.

### 6. Dashboard replaced by Command Centre

**Background:** The old Dashboard ran on port 8081. It was replaced by Command Centre on port 8080.

**Affected jobs:**
- `DASH_HC_SYNC` - was syncing health config from Dashboard API (deleted, obsolete)

**Command Centre health check:** Already configured in NetBox and monitored by health_check. No separate sync job needed.

```bash
# Verify Command Centre is being monitored
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT target_name, status, last_check FROM qsys._healthchk_status WHERE target_name ILIKE '%command%';\""
```

## Modifying Health Checks

### Add a new target
1. In NetBox, set these custom fields on the VM/device:
   - `check_enabled: true`
   - `check_url: http://service:port/health` (required for http/https/tcp)
   - `check_type: http` (or `https`, `tcp`, `ping`, `docker`)
   - `expected_status: 200`
   - `alert_grace_hours: 12` (optional, added 2026-07-02) — for flaky-link devices:
     a DOWN issue is only created after the target has been down continuously this
     many hours (down-since = `qsys._healthchk_status.last_status_change`). Status
     tracking still updates every run. Example: MagicMirror Pi on flaky WiFi.

### Check type specifics

| Type | check_url required? | Notes |
|------|---------------------|-------|
| http/https | Yes | URL to check |
| tcp | Yes | host:port format |
| ping | No | Uses primary_ip4 from NetBox if check_url not set |
| docker | No | Uses `container_name` custom field, cluster determines host |
| none | N/A | Explicitly disabled, won't be checked |

### Docker container checks
For VMs representing Docker containers:
1. Set `check_type: docker`
2. Set `container_name: actual-container-name` (if different from VM name)
3. Assign VM to correct cluster (Synology, DK/400, NetBox, etc.)

The cluster determines which host to SSH to for docker inspect.

### Change check frequency
Update in database (schedules now in `_jobscde`, not schedules.py):
```sql
UPDATE qsys._jobscde SET frequency = '30' WHERE name = 'HEALTH_CHECK';  -- 30 seconds
```
Changes take effect within 60 seconds (scheduler refresh interval).

### Disable checks for a service
In NetBox, either:
- Set `check_enabled: false`, or
- Set status to `offline`, `planned`, or `decommissioning`

**Status meanings:**
- `active` - Normal operation, will be checked
- `offline` - Powered off intentionally (e.g., seasonal equipment)
- `planned` - Not yet deployed
- `decommissioning` - Being retired, kept for history

## Recovery Checklist

When health monitoring breaks:

1. [ ] Check dk400 logs for errors
2. [ ] Verify schedules.py has valid syntax
3. [ ] Check database schema matches code expectations
4. [ ] Verify NetBox API is accessible
5. [ ] Restart dk400 if needed: `docker restart dk400`
6. [ ] Wait 60s and verify health_check runs

## Tracing Where Services Actually Run

**CRITICAL:** Don't assume a service runs where DNS points or where containers exist. Always trace the full path.

### The Mistake to Avoid

Seeing containers on a host + DNS pointing there ≠ service runs there.

Common setup: DNS → reverse proxy → actual backend (different host)

### Diagnostic Steps

**Always follow this sequence:**

```bash
# 1. Check DNS resolution
dig +short service.kbl55.com

# 2. Check if there's a reverse proxy (NPM, nginx, traefik)
ssh doug@192.168.20.19 "docker ps | grep -i 'nginx\|proxy\|npm\|traefik'"

# 3. Check proxy config - WHERE does it forward to?
ssh doug@192.168.20.19 "docker exec nginx-proxy-manager grep -h 'set \$server' /data/nginx/proxy_host/*.conf"

# 4. Verify the actual backend responds
curl -s -o /dev/null -w "%{http_code}" "http://BACKEND_IP:PORT" --connect-timeout 5

# 5. Only THEN conclude where the service runs
```

### Red Flags That Your Conclusion Is Wrong

| Red Flag | What It Means |
|----------|---------------|
| Container has empty data directories | Not the real service |
| Container has no root folders configured (arr apps) | Not the real service |
| User sees activity but container looks unused | Wrong container |
| Container started manually (no compose labels) | Likely orphan/test |

### Example: Arr Stack

```bash
# Wrong approach: "I see sonarr container on docker-server, DNS points there, so sonarr runs on docker-server"

# Right approach:
dig +short sonarr.kbl55.com                    # → 192.168.20.19
# But then check NPM:
docker exec nginx-proxy-manager grep -A2 'sonarr' /data/nginx/proxy_host/*.conf
# set $server "192.168.20.16"                  # → Actually proxies to Synology!

# Verify Synology responds:
curl -s -o /dev/null -w "%{http_code}" "http://192.168.20.16:8989"  # → 302 (working)
```

### When Containers Exist But Shouldn't

If you find orphan containers:
1. Check if they have compose labels (`com.docker.compose.project`)
2. Check when they were created (`docker inspect --format '{{.Created}}'`)
3. Check if data directories are empty
4. If orphans, remove them: `docker stop X && docker rm X`

## SignalK Plugin Health Checks

health_check.py monitors SignalK plugins for errors on all configured servers.

### How It Works

1. Queries `/skServer/plugins` on each SignalK server (requires admin auth)
2. Checks for enabled plugins with non-empty `statusMessage` (indicates error)
3. Creates issues for any failing plugins

### Configuration

Tokens stored in dk400 `.env` file:
```
SIGNALK_TOKEN_HOMESK=<jwt>
SIGNALK_TOKEN_NAVNET=<jwt>
SIGNALK_TOKEN_POWERNET=<jwt>
```

Tokens also stored in Bitwarden:
- `SignalK - HomeSK Admin Token`
- `SignalK - Nav Net Admin Token`
- `SignalK - Power Net Admin Token`

### Generating New Tokens

If a token expires or server's secretKey changes:
```bash
ssh doug@<server> 'node -e "
const crypto = require(\"crypto\");
const fs = require(\"fs\");
const sec = JSON.parse(fs.readFileSync(\"/home/doug/.signalk/security.json\"));
const h = Buffer.from(JSON.stringify({alg:\"HS256\",typ:\"JWT\"})).toString(\"base64url\");
const p = Buffer.from(JSON.stringify({id:\"admin\",iat:Math.floor(Date.now()/1000)})).toString(\"base64url\");
const s = crypto.createHmac(\"sha256\",sec.secretKey).update(h+\".\"+p).digest(\"base64url\");
console.log(h+\".\"+p+\".\"+s);
"'
```

For HomeSK (runs in docker):
```bash
ssh doug@192.168.20.19 'docker exec signalk node -e "..."'
```

Update in both `.env` file and Bitwarden, then restart dk400.

## Related

- **Robot skill**: `.claude/skills/robot/skill.md` - dk400 scheduler details
- **Issue review**: `.claude/skills/issue-review/skill.md` - Handle issues created by health_check
