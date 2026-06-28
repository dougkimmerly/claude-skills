---
name: fixer-issue
description: How to build dk400 programs that create, update, and resolve fixer issues — call signature, naming conventions, severity guide, dedup semantics, gotchas
triggers:
  - report_issue
  - create issue
  - fixer issue
  - build program that creates issues
  - issue from program
location: universal
---

# Building Programs That Create Fixer Issues

Reference for CC instances building dk400 programs that report issues to `fixer.unified_issues`.

For issue *lifecycle and status semantics* (resolved/ignored/reopen behavior), see the `issues` skill instead.

---

## Quick Start

```python
from dk400.programs import report_issue

result = await report_issue.run(
    issue_type="disk_space",
    target="docker-server",
    error_message="Root filesystem at 94% (threshold: 90%)",
    severity="error",
    host="192.168.20.19",
)
# result["is_new"] → True/False
# result["issue_id"] → int
```

---

## All Parameters

```python
await report_issue.run(
    issue_type="disk_space",       # Required. Snake_case. What KIND of problem.
    target="docker-server",        # Required. What specific thing is affected.
    error_message="...",           # Human-readable description of the problem.
    severity="warning",            # critical | error | warning (default) | info
    host="192.168.20.19",          # Optional. IP/hostname where it occurred.
    category="storage",            # Optional. Grouping label for /issue-review.
    metadata={"threshold": 90},    # Optional dict — survives as JSONB.
    send_notification=True,        # Telegram alert? Only fires for critical/error.
)
```

**Legacy aliases** (backwards compat — don't use in new code):
`source_type=` → `issue_type=`, `source_name=` → `target=`, `title=` / `message=` → `error_message=`

---

## Return Value

```python
{
    "issue_id": 42,           # fixer.unified_issues.id
    "is_new": True,           # False if issue already existed
    "reopened": False,        # True if was resolved/fix_applied and recurred
    "occurrence_count": 1,    # Total times this issue has fired
    "status": "new",          # Current status after this call
}
```

Use `is_new` to decide whether to take additional action (e.g., log extra context). Use `reopened` to detect recurrences after a fix.

---

## Dedup Key

Hash of: `issue_type + target + host`

Same triple → same issue row, `occurrence_count` increments.
Different triple (even one field different) → new issue row.

**Design your triple carefully.** If `target` is too specific (e.g., includes a timestamp), every call creates a new row. If too broad (e.g., always `"system"`), unrelated errors collapse into one issue.

Good targets: service name, device name, container name, IP address.
Bad targets: log line excerpts, timestamps, dynamic counts.

---

## issue_type Naming Convention

- **snake_case**, descriptive of the problem class, not the detector
- Existing types in use (match these for consistency, create new if genuinely different):

| issue_type | Used for |
|---|---|
| `down` | Service/device not responding |
| `health_check` | Generic health check failure |
| `disk_space` | Filesystem near-full |
| `network_connectivity` | Ping/reachability failure |
| `container_restarts` | Container restart-looping |
| `system_health` | General system health degradation |
| `system_resources` | CPU/memory/load issues |
| `backup_failure` | Backup job failed |
| `backup` | Backup-related (use `backup_failure` for errors) |
| `pg_amcheck_failure` | Postgres btree corruption detected |
| `pg_dump_structural_corruption` | Dump integrity check failed |
| `unexpected_up` | Service running when it shouldn't be |
| `pihole_heartbeat` | Pi-hole sync/heartbeat failure |
| `docs_drift` | Documentation out of sync with reality |
| `discovery` | Unknown device/container found |
| `signalk_discovery` | SignalK webapp not in NetBox |

---

## Severity Guide

| Severity | When to use | Telegram? |
|---|---|---|
| `critical` | System down, data loss risk, boat stranded | Yes |
| `error` | Functionality broken, needs human attention | Yes |
| `warning` | Degraded but limping; action eventually needed | No |
| `info` | FYI; no action required | No |

Telegram fires only for `critical` and `error` (enforced in `report_issue.run()`).
This matches the homelab Telegram policy: actionable emergencies only, not noise.

When in doubt, use `warning`. Reserve `error` for things that are actually broken.

---

## Updating Status Programmatically

```python
await report_issue.update_status(
    issue_id=42,
    new_status="resolved",          # new | investigating | fix_applied | resolved | ignored
    actor="dk400",                  # Who is making the change
    summary="Disk usage dropped to 72% after log cleanup",
)
```

Prefer `report_issue.update_status()` over raw SQL updates — it writes to `issue_actions` automatically.

---

## Writing Directly to issue_actions

If you need to log a remediation attempt, write directly:

```python
from dk400.db import get_connection

async with get_connection() as conn:
    await conn.execute("""
        INSERT INTO fixer.issue_actions
            (issue_id, action_type, actor, summary)
        VALUES ($1, $2, $3, $4)
    """,
        issue_id, "remediation_success", "dk400",
        "Restarted container; health check passing again",
    )
```

**`actor` is NOT NULL with no default** — always include it. Common values: `dk400`, `claude`, `manual`, `auto`, `runbook`.

Valid `action_type` values: `created`, `updated`, `reopened`, `status_change`, `telegram_sent`, `remediation_success`, `remediation_failed`, `escalated`.

---

## category Field

Optional grouping label shown in `/issue-review`. Use a short noun:

`storage` `network` `database` `backup` `monitoring` `security` `media` `boat` `discovery`

Skip `category` for high-frequency probe issues (`health_check`, `discovery`, `signalk_discovery`) — the `/issue-review` clean lens filters them out by `source_type` already.

---

## Gotchas

- **f-string issue_type**: `issue_type=f"..."` with a missing variable silently creates weird issue_type strings. Use a constant for the type, format only the target/message.
- **Don't use legacy aliases in new code**: `source_type`, `source_name`, `title`, `message` — they still work but muddy the codebase.
- **send_notification=False**: Use this when your program fires many times before a human can act (e.g., a per-minute probe). Telegram at 60/hour is noise.
- **actor NOT NULL**: Every direct INSERT into `issue_actions` needs an `actor` value or it will fail.
- **Boat vs home**: Same `report_issue` program is deployed to both centralsk (`dk400-boat`) and home (`dk400-homelab`). Issues land in the local `fixer.unified_issues` — they are NOT cross-site replicated (by design).

---

## Related

- **`issues` skill**: Status semantics, auto-reopen behavior, lifecycle diagram, SQL queries for issue review
- **`robot` skill**: How to schedule a program in dk400 (Celery Beat, `_jobscde`)
- **Telegram policy** (feedback memory): Telegram for actionable emergencies only — don't set `send_notification=True` for `warning`/`info`
