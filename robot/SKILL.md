---
name: robot
description: Understand and troubleshoot dk400's Robot scheduler
triggers:
  - robot
  - scheduler
  - celery
  - schedules not running
  - _jobscde
location: project
---

# Robot Scheduler

Guide for understanding and troubleshooting dk400's Robot job scheduler.

## Architecture

Robot is dk400's job scheduler built on Celery with database-driven scheduling.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         dk400 Container                              │
├─────────────────────────────────────────────────────────────────────┤
│  supervisord                                                         │
│    ├── web (FastAPI on port 8400)                                   │
│    ├── robot (Celery Beat + DatabaseScheduler)                      │
│    └── worker (Celery Worker - executes jobs)                       │
└─────────────────────────────────────────────────────────────────────┘
         │                    │
         │                    ▼
         │          ┌─────────────────────┐
         │          │   dk400-redis       │
         │          │   (message broker)  │
         │          └─────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    qsys._jobscde Table                               │
│            (Source of truth for job schedules)                       │
├─────────────────────────────────────────────────────────────────────┤
│ • DatabaseScheduler reads schedules every 60 seconds                 │
│ • Updates next_run when calculating schedules                        │
│ • Updates last_run after job completion                              │
│ • Changes take effect without restart                                │
└─────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Programs Directory                              │
│              (dk400-homelab/dk400/programs/*.py)                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `dk400/robot/worker.py` | Celery app configuration |
| `dk400/robot/db_scheduler.py` | DatabaseScheduler (reads from _jobscde) |
| `dk400/robot/tasks.py` | Celery tasks (run_program) |
| `dk400/programs/*.py` | Individual program implementations |
| `dk400/programs/__init__.py` | Program registry |

**Deprecated:** `dk400/robot/schedules.py` - legacy hardcoded schedules (no longer used)

## Job Schedule Table (_jobscde)

The source of truth for all job schedules is `qsys._jobscde`:

```sql
-- View all active jobs
SELECT name, command, frequency, schedule_time, next_run, last_run, status
FROM qsys._jobscde
WHERE status = '*ACTIVE'
ORDER BY next_run;

-- Key columns:
-- name: Job identifier (max 20 chars, AS/400 style)
-- command: Program name or legacy task path
-- frequency: *HOURLY, *DAILY, *WEEKLY, *MONTHLY, or numeric seconds
-- schedule_time: Time of day for crontab schedules (HH:MM:SS)
-- next_run: Calculated by DatabaseScheduler
-- last_run: Updated after job completion
-- status: *ACTIVE, *HELD, *DISABLED
```

**⚠️ `command` is the BARE program name** (e.g. `pg_amcheck`), never `run_program pg_amcheck`.
With the prefix, the engine looks up a program literally named `run_program pg_amcheck`,
fails instantly with "Program not found", and the Celery task still reports
`succeeded ... 'success': False` — the job looks alive but never does anything.
Found 2026-07-02: all 8 `HEALTH_*` jobs at BOTH sites were dead this way for weeks
(it's why boat pg corruption went undetected). Audit:
`SELECT name, command FROM qsys._jobscde WHERE command LIKE 'run_program %';`

### Frequency Types

| Frequency | Meaning | Example |
|-----------|---------|---------|
| `*HOURLY` | Every hour at schedule_time minute | minute=0 |
| `*DAILY` | Every day at schedule_time | 08:00:00 |
| `*WEEKLY` | Weekly on days_of_week at schedule_time | MON,WED,FRI |
| `*MONTHLY` | First of month at schedule_time | 04:00:00 |
| `60` | Every 60 seconds (numeric = interval) | - |
| `300` | Every 5 minutes | - |
| `3600` | Every hour (interval style) | - |

## Adding/Removing Programs

### Add a new scheduled program

1. Create program file: `dk400/programs/my_program.py`
   ```python
   async def run(**kwargs):
       # Do work
       return {"status": "ok", "result": ...}
   ```

2. Register in `dk400/programs/__init__.py`:
   ```python
   from . import my_program
   __all__ = [..., "my_program"]
   ```

3. Add schedule in database:
   ```sql
   INSERT INTO qsys._jobscde (name, text, command, frequency, schedule_time, status, created_by)
   VALUES ('MY_PROGRAM', 'Description of job', 'my_program', '*HOURLY', '00:00:00', '*ACTIVE', 'QSECOFR');
   ```

4. Commit and push code changes, restart dk400
5. Schedule takes effect within 60 seconds

### Modify a schedule

```sql
-- Change frequency
UPDATE qsys._jobscde SET frequency = '300' WHERE name = 'MY_PROGRAM';

-- Change schedule time
UPDATE qsys._jobscde SET schedule_time = '06:00:00' WHERE name = 'MY_PROGRAM';

-- Hold a job (stops scheduling)
UPDATE qsys._jobscde SET status = '*HELD' WHERE name = 'MY_PROGRAM';

-- Resume a held job
UPDATE qsys._jobscde SET status = '*ACTIVE' WHERE name = 'MY_PROGRAM';
```

Changes take effect on next scheduler refresh (within 60 seconds).

### Remove a scheduled program

1. Mark inactive in database (preferred - keeps history):
   ```sql
   UPDATE qsys._jobscde SET status = '*DISABLED' WHERE name = 'MY_PROGRAM';
   ```

2. Or delete completely:
   ```sql
   DELETE FROM qsys._jobscde WHERE name = 'MY_PROGRAM';
   ```

3. Optionally remove code if no longer needed

## Diagnostics

### Check if Robot is running

```bash
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep -E 'DatabaseScheduler|celery|robot|beat' | tail -20"
```

**Healthy output:**
```
INFO/Beat: DatabaseScheduler: Loaded 41 active jobs
INFO/ForkPoolWorker-1: Running program: health_check
INFO/ForkPoolWorker-1: Program health_check completed in 12.3s
```

**Unhealthy output:**
```
FATAL: robot entered FATAL state
DatabaseScheduler: Failed to load schedule: connection refused
```

### View scheduled jobs from database

```bash
# All active jobs with next run times
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT name, command, frequency, next_run, last_run
FROM qsys._jobscde
WHERE status = '*ACTIVE'
ORDER BY next_run NULLS LAST
LIMIT 20;\""

# Jobs that haven't run recently
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT name, command, last_run
FROM qsys._jobscde
WHERE status = '*ACTIVE'
  AND (last_run IS NULL OR last_run < NOW() - INTERVAL '1 day')
ORDER BY last_run NULLS FIRST;\""
```

### Check recent job runs

```bash
# From dk400 logs
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep 'Running program\|completed\|failed' | tail -30"
```

### Check scheduler refresh

```bash
# See scheduler loading jobs
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep 'DatabaseScheduler: Loaded' | tail -5"
```

### Trigger a program manually

Run a program immediately without waiting for its next scheduled time:

```bash
ssh doug@192.168.20.19 "docker exec dk400 python3 -c \"
from dk400.robot.worker import app
result = app.send_task('dk400.robot.tasks.run_program', args=['PROGRAM_NAME'])
print(f'Task ID: {result.id}')
\""
```

Then check the result in logs:

```bash
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep 'TASK_ID'"
```

This sends the task through Celery like a normal scheduled run — the worker picks it up, imports the module, and executes `run()`. Useful for verifying code changes after a restart.

### Verify the worker can import programs (silent-failure check)

**Run this after any deploy that adds or changes a program** — and periodically, because this failure mode is silent in the scheduler logs.

```bash
# Fires a known-good program through Celery and shows whether the
# worker resolves it.
ssh <host> "docker exec dk400 celery -A dk400.robot call dk400.robot.tasks.run_program --args='[\"backup_verify\"]' >/dev/null 2>&1; sleep 5; docker logs --since 15s dk400 2>&1 | grep -E 'Program (not found|completed|failed)' | tail -3"
```

- `Program backup_verify completed in Ns` → worker is healthy.
- `Program not found: backup_verify` → worker can't see `/app/programs/` on `sys.path` (see Common Issue 15). Every scheduled task is silently failing.

## Common Issues

### 1. Robot won't start (FATAL state)

**Symptoms:**
```
WARN exited: robot (exit status 2; not expected)
INFO gave up: robot entered FATAL state
```

**Cause:** Usually a syntax error in db_scheduler.py or worker.py

**Fix:**
```bash
# Check syntax
python3 -m py_compile dk400/robot/db_scheduler.py
python3 -m py_compile dk400/robot/worker.py

# Fix errors, then restart
docker restart dk400
```

### 2. Code changes not taking effect (bind-mounted programs)

**Symptoms:** You updated a program file, pulled on the server, but the old behavior persists.

**Cause:** `importlib.import_module()` caches modules after first import. The Celery worker process keeps the old code in memory even though the file on disk changed.

**Fix:** Restart dk400 to reload all program modules:
```bash
ssh doug@192.168.20.19 "docker restart dk400"
```

**Key insight:** Schedule changes (database) take effect within 60 seconds. Code changes (files) require a restart.

### 3. Schedule changes not taking effect

**Cause:** DatabaseScheduler refreshes every 60 seconds

**Fix:** Wait up to 60 seconds, or restart dk400 for immediate effect
```bash
ssh doug@192.168.20.19 "docker restart dk400"
```

### 4. Job not being scheduled (next_run is NULL)

**Symptoms:** Job exists but `next_run` is NULL

**Cause:** Frequency type not supported or command invalid

**Check:**
```sql
SELECT name, frequency, command FROM qsys._jobscde WHERE next_run IS NULL AND status = '*ACTIVE';
```

**Fix:** Use supported frequency format:
- `*HOURLY`, `*DAILY`, `*WEEKLY`, `*MONTHLY`
- Numeric seconds (e.g., `300` for 5 minutes)

### 5. Program not found (orphan job)

**Symptoms:**
```
ModuleNotFoundError: No module named 'dk400.programs.my_program'
Program MYJOB failed: No module named 'dk400.programs.MYJOB'
```

**Causes:**
1. Program not registered in `__init__.py`
2. **Orphan job**: Job exists in `_jobscde` but program was never created or was deleted

**Diagnose:**
```bash
# Check if program file exists
ls dk400/programs/my_program.py

# Check if registered in __init__.py
grep my_program dk400/programs/__init__.py
```

**Fix for orphan job** (scheduled but program doesn't exist):
```sql
-- Disable the orphan job
UPDATE qsys._jobscde SET status = '*DISABLED' WHERE name = 'MYJOB';
```

**Fix for missing registration:**
```python
from . import my_program
__all__ = [..., "my_program"]
```

**Note:** Orphan jobs cause recurring errors that may flood log_analysis issues. Always disable or delete jobs whose programs don't exist.

### 6. Duplicate jobs running the same program

**Symptoms:** A program runs twice per cycle, logs show double entries, issues get double occurrence counts.

**Cause:** Multiple `_jobscde` entries with the same `command` value. Often happens when jobs are renamed to a new convention without disabling the old one.

**Check:**
```sql
SELECT command, COUNT(*), array_agg(name) as job_names
FROM qsys._jobscde
WHERE status = '*ACTIVE'
GROUP BY command
HAVING COUNT(*) > 1;
```

**Fix:** Keep the one following current naming convention (`INFRA_*` for infrastructure), disable the other:
```sql
UPDATE qsys._jobscde SET status = '*DISABLED' WHERE name = 'OLD_JOB_NAME';
```

### 7. Program fails with database error

**Symptoms:**
```
Program xyz failed: column "abc" does not exist
```

**Cause:** Schema mismatch between code and database

**Fix:** Add missing column or fix column type:
```sql
ALTER TABLE schema.table ADD COLUMN IF NOT EXISTS column_name TYPE;
ALTER TABLE schema.table ALTER COLUMN column_name TYPE new_type;
```

### 8. "Could not parse schedule" warning

**Symptoms:**
```
WARNING/Beat: Job MY_JOB: Could not parse schedule (freq=*UNKNOWN)
```

**Cause:** Invalid frequency value

**Fix:** Update to supported frequency:
```sql
UPDATE qsys._jobscde SET frequency = '300' WHERE name = 'MY_JOB';  -- 5 minutes
UPDATE qsys._jobscde SET frequency = '*HOURLY' WHERE name = 'MY_JOB';
```

### 9. Jobs running but last_run not updating

**Symptoms:** Jobs execute (visible in logs) but `last_run` stays NULL or stale

**Cause:** Celery signals are process-local. If you put a signal handler in Beat (scheduler), it won't fire in Worker (where tasks run).

**Key insight:** `last_run` must be updated in `tasks.py` (Worker process), NOT in `db_scheduler.py` (Beat process).

**Check:**
```bash
# Verify jobs are running
docker logs dk400 2>&1 | grep 'Running program' | tail -10

# Check last_run
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT name, command, last_run FROM qsys._jobscde WHERE name = 'HEALTH_CHECK';\""
```

### 10. Command field has old task paths

**Symptoms:** `No module named 'dk400.programs.bitwarden'`

**Cause:** After migrating from `schedules.py`, the `command` field may have old paths like `tasks.backup.bitwarden` instead of program names like `backup_bitwarden`.

**Check:**
```sql
SELECT name, command FROM qsys._jobscde WHERE command LIKE 'tasks.%';
```

**Fix:** Update command to match actual program name in `dk400/programs/`:
```sql
UPDATE qsys._jobscde SET command = 'backup_bitwarden' WHERE name = 'BKP_BITWARDEN';
UPDATE qsys._jobscde SET command = 'backup_dk400' WHERE name = 'BKP_DK400';
-- etc.
```

### 11. asyncpg SQL parameter syntax errors

**Symptoms:** `invalid input syntax for type interval: "%s days"`

**Cause:** asyncpg uses `$1`, `$2` placeholders, NOT `%s`. You cannot embed parameters inside strings.

**Wrong:**
```python
await conn.execute("DELETE FROM t WHERE ts < NOW() - INTERVAL '%s days'", days)
```

**Correct:**
```python
await conn.execute("DELETE FROM t WHERE ts < NOW() - INTERVAL '1 day' * $1", days)
```

## Restart Checklist

When you need to restart dk400:

1. [ ] Verify db_scheduler.py syntax: `python3 -m py_compile db_scheduler.py`
2. [ ] Verify worker.py syntax: `python3 -m py_compile worker.py`
3. [ ] Commit changes: `git add -A && git commit -m "message"`
4. [ ] Push: `git push`
5. [ ] Restart: `docker restart dk400`
6. [ ] Verify: `docker logs dk400 2>&1 | grep DatabaseScheduler | tail -5`

## WRKJOBSCDE (Work with Job Schedule)

The `_jobscde` table is designed to be viewed/edited like AS/400's WRKJOBSCDE command:

```sql
-- Show all jobs like WRKJOBSCDE
SELECT
  name,
  LEFT(text, 30) as description,
  frequency,
  to_char(schedule_time, 'HH24:MI') as time,
  status,
  to_char(next_run, 'MM-DD HH24:MI') as next_run,
  to_char(last_run, 'MM-DD HH24:MI') as last_run
FROM qsys._jobscde
ORDER BY name;

-- Hold a job (like option 3)
UPDATE qsys._jobscde SET status = '*HELD' WHERE name = 'JOB_NAME';

-- Release a job (like option 6)
UPDATE qsys._jobscde SET status = '*ACTIVE' WHERE name = 'JOB_NAME';
```

### 12. Program needs access to files outside container

**Symptoms:** Program can't find files, path doesn't exist

**Cause:** dk400 container doesn't have access to host paths or other container volumes.

**Example:** `recipe_scan` needs access to `/opt/docker-server/galley/scans`

**Fix:** Add volume mount in `compose.yaml`:
```yaml
volumes:
  - /opt/docker-server/galley/scans:/galley-scans
```

Then update program to use container path (`/galley-scans`), recreate container:
```bash
docker compose up -d dk400
```

### 13. Job references retired service

**Symptoms:** Job fails connecting to old URL/port, or service no longer exists

**Example:** `DASH_HC_SYNC` was connecting to Dashboard on port 8081, but Dashboard was replaced by Command Centre on port 8080.

**Fix:** Either update the job to use the new service, or delete if obsolete:
```sql
-- Delete obsolete job
DELETE FROM qsys._jobscde WHERE name = 'DASH_HC_SYNC';

-- Or hold while investigating
UPDATE qsys._jobscde SET status = '*HELD' WHERE name = 'MY_JOB';
```

### 15. "Program not found" on every scheduled task (silent catastrophic failure)

**Symptoms:**
- Jobs appear to schedule normally (`DatabaseScheduler: Loaded N active jobs`)
- Logs show `Running program: <name>` immediately followed by `Program not found: <name>`
- `qsys._jobhst` is empty; `qsys._jobscde.last_run` stops updating
- Backup directories, monitoring outputs, etc. silently stop being fresh
- No Telegram alert — the task "succeeded" from Celery's POV (it returned `success: False` without raising)

**How this hides:** `run_program` catches `ModuleNotFoundError`, logs an error, and returns a dict with `success: False`. Celery counts that as a successful task invocation, so `_jobhst` and `last_run` are never written to, and nothing triggers an alerting path. The only signal is "things aren't fresh anymore," which takes weeks to notice.

**Root cause:** The Celery worker is invoked as `/usr/local/bin/celery` (a Python script). When Python runs a script, it sets `sys.path[0]` to the script's directory (`/usr/local/bin`), **not** the working directory. Deployment-specific programs in `/app/programs/` are therefore invisible to `importlib.import_module("programs.X")`.

Manual `docker exec dk400 python -c "from programs import X"` works because a bare `python` invocation puts cwd (`""`) on `sys.path`. The discrepancy between that and the worker's real behaviour is what makes this hard to spot.

**Fix:** Add `PYTHONPATH=/app` to the supervisord `[program:robot]` block:

```ini
[program:robot]
command=celery -A dk400.robot.worker worker --beat --loglevel=info
directory=/app
environment=PYTHONPATH="/app"
...
```

Then rebuild and recreate the container:

```bash
ssh <host> "cd <dk400 repo> && git pull && docker compose up -d --build dk400"
```

After deploy, run the import-sanity check in the Diagnostics section to confirm the worker actually resolves programs.

**When this was found:** 2026-04-16. Scheduled backups on home had been silently failing since 2026-02-20 — roughly two months of no protection. Discovered only because boat's new `backup_verify` flagged staleness, which traced back to the same root cause.

### 14. Timezone-aware vs naive datetime comparison

**Symptoms:** `can't compare offset-naive and offset-aware datetimes`

**Cause:** Python code uses `datetime.now(timezone.utc)` (timezone-aware) but database column is `TIMESTAMP` without timezone (naive). Comparison fails.

**Example:** `vpn_rotation` failed because `qsys._vpnstate` had `TIMESTAMP` columns but code compared with `datetime.now(timezone.utc)`.

**Check:**
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'qsys' AND table_name = '_mytable';
-- Look for "timestamp without time zone" vs "timestamp with time zone"
```

**Fix:** Alter columns to use timezone-aware type:
```sql
ALTER TABLE qsys._mytable
  ALTER COLUMN my_timestamp TYPE TIMESTAMPTZ;
```

**Prevention:** Always use `TIMESTAMPTZ` for timestamp columns, never `TIMESTAMP`.

## Database Permission Changes

**CRITICAL: Before changing table ownership or permissions:**

1. Check who currently connects to those tables:
   ```sql
   SELECT usename, application_name, query
   FROM pg_stat_activity
   WHERE query LIKE '%table_name%';
   ```

2. Check existing grants:
   ```sql
   SELECT grantee, privilege_type
   FROM information_schema.table_privileges
   WHERE table_schema = 'schema' AND table_name = 'table';
   ```

3. Preserve existing access when changing ownership:
   ```sql
   -- After changing ownership, re-grant to previous users
   GRANT SELECT, INSERT, UPDATE, DELETE ON schema.table TO previous_user;
   ```

**Why this matters:** Multiple services connect as different users. Changing ownership removes grants to other users, breaking services that were working.

Example: `command-centre` connects as `dk400`, but `qsys._jobscde` was owned by `fixer`. Changing ownership without granting to `dk400` broke command-centre.

**Connection pool caching:** After adding new grants, services with connection pools may not pick up the new permissions until restarted. If grants are in place but permission errors persist, restart the affected service:
```bash
docker restart command-centre
```

### Troubleshooting Permission Errors

When you see `permission denied for table X` in postgres logs:

1. **Verify grants exist:**
   ```sql
   SELECT grantee, privilege_type
   FROM information_schema.table_privileges
   WHERE table_schema = 'qsys' AND table_name = '_jobscde';
   ```

2. **Test direct query as the affected user:**
   ```bash
   docker exec dk400-postgres psql -U dk400 -d dk400 -c "SELECT COUNT(*) FROM qsys._jobscde;"
   ```

3. **If direct query works but app still fails** → connection pool caching. Restart the service:
   ```bash
   docker restart command-centre
   ```

4. **If direct query also fails** → grants are missing. Add them:
   ```sql
   GRANT SELECT, INSERT, UPDATE, DELETE ON qsys._jobscde TO dk400;
   ```

**Note:** Postgres logs don't show the username by default. To identify which user is getting errors, check which services query those tables and test each user directly.

## Database Schema Philosophy

**dk400 does NOT auto-create tables on startup.** This follows AS/400 practice:

- Tables are created once during initial setup
- Schema changes are done deliberately with ALTER TABLE
- Programs don't check "does this table exist?" every time

The `init_database()` function in `database.py` is a no-op. If you need to add a table or column:

```sql
-- Add a column
ALTER TABLE qsys.mytable ADD COLUMN new_col VARCHAR(100);

-- Add a table (one time, not in startup code)
CREATE TABLE qsys.newtable (...);
```

**Why not auto-create?**
- Permission errors on tables owned by other apps
- No versioning of schema changes
- Wasted effort checking 50+ tables every boot
- Risk of unintended modifications

## Related

- **Health monitor skill**: `.claude/skills/health-monitor/skill.md`
- **Issue review skill**: `.claude/skills/issue-review/skill.md`
- **Programs reference**: `fixer/docs/programs.md`
