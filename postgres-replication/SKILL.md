---
name: postgres-replication
description: Set up, monitor, and troubleshoot PostgreSQL logical replication between dk400-postgres on home and centralsk. Covers publication/subscription patterns, GUC settings tuned for slow-WAN links, sync-worker zombies, slot management, and per-table state in pg_subscription_rel.
---

# PostgreSQL logical replication (cross-site)

This skill is about logical (per-table) replication between home's `dk400-postgres` and centralsk's `dk400-postgres` over Tailscale. Used for `cruising.*` (centralsk → home, ADR 0008) and similar future schemas.

For ADRs: `fixer/docs/decisions/0001-db-replication-strategy.md`, `0007-bidirectional-write-data-sync.md`, `0008-cruising-schema-replication.md`.

## Architecture pattern

- **Publisher** (centralsk for boat-owned schemas): runs at `wal_level = logical`, has a `<schema>_pub` PUBLICATION enumerating included tables, has a `replicator` role with `LOGIN REPLICATION` and SELECT grants, has a pg_hba line allowing replication connections from the subscriber's Tailscale IP.
- **Subscriber** (home): has the same table DDL pre-loaded (logical rep does NOT carry DDL), has a `<schema>_sub` SUBSCRIPTION pointing at the publisher's Tailscale IP.
- **Slot retention** capped via `max_slot_wal_keep_size = 4GB` so a long-offline subscriber can't fill the publisher's WAL disk.

## Setup checklist (publisher side)

```sql
-- One time, requires postgres restart for wal_level
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_slot_wal_keep_size = '4GB';
ALTER SYSTEM SET wal_sender_timeout = '5min';   -- default 60s is too short for slow Tailscale paths
-- Then: docker restart dk400-postgres (or whatever brings it back up)

-- pg_hba.conf inside data volume — append:
-- host    all              replicator       <subscriber-tailscale-ip>/32   scram-sha-256
-- host    replication      replicator       <subscriber-tailscale-ip>/32   scram-sha-256

CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD '<long-random>';
GRANT USAGE ON SCHEMA <schema> TO replicator;
GRANT SELECT ON ALL TABLES IN SCHEMA <schema> TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> GRANT SELECT ON TABLES TO replicator;

CREATE PUBLICATION <schema>_pub FOR TABLE
  <schema>.table1,
  <schema>.table2,
  ...;
```

**Always enumerate tables explicitly** in the publication, not `FOR ALL TABLES IN SCHEMA <schema>`. New tables on the publisher are then a deliberate decision to add to the publication (and to pre-create on the subscriber), not an accidental replication.

## Setup checklist (subscriber side)

```sql
ALTER SYSTEM SET wal_receiver_timeout = '5min';
SELECT pg_reload_conf();

-- Pre-load the schema DDL. Logical replication does NOT carry DDL.
-- Do `pg_dump --schema-only -n <schema>` from publisher, sed to make
-- CREATE SCHEMA idempotent, apply on subscriber.
-- Skip extension-blocked tables on subscriber if any (drop them from
-- the publication instead — see "extension dependencies" below).

CREATE SUBSCRIPTION <schema>_sub
  CONNECTION 'host=<publisher-tailscale-ip> port=5432 dbname=dk400 user=replicator password=<...>'
  PUBLICATION <schema>_pub
  WITH (copy_data = true, create_slot = true, slot_name = '<schema>_sub');
```

## Connecting to each side (psql)

- **Publisher (centralsk, boat):** `ssh doug@192.168.22.15 "docker exec dk400-postgres psql -U dk400 -d dk400 -c '...'"`. The `dk400` role owns the `cruising` schema here.
- **Subscriber (home, docker-server):** `ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U homelab_admin -d dk400 -c '...'"`. **Use `homelab_admin`, not `dk400`** — on home the `dk400` role has no privileges on the `cruising` schema (a `SELECT` errors `permission denied for schema cruising`, and `information_schema.columns` silently returns nothing). DDL for schema-drift fixes (`ADD COLUMN`, `REFRESH PUBLICATION`) runs as `homelab_admin`.

## Diagnostic queries

### Per-table state (subscriber)

```sql
SELECT srsubstate AS state, count(*)
FROM pg_subscription_rel GROUP BY srsubstate ORDER BY srsubstate;
```

State letters:
- `i` — initialize (queued, waiting for sync worker)
- `d` — data copy in flight
- `f` — finished copy, awaiting catch-up
- `s` — syncdone, transitioning to streaming
- `r` — ready (now part of the main streaming slot)

Goal is all-`r`. If `i`/`d` counts stop changing for minutes, see "stuck sync workers" below.

### Active workers (subscriber)

```sql
SELECT pid, received_lsn, last_msg_receipt_time
FROM pg_stat_subscription;
```

Expect 1 apply worker (`received_lsn` non-null, `last_msg_receipt_time` recent) plus 0–N sync workers. Stale `last_msg_receipt_time` (>1 min old) on a sync worker = zombie.

### Walsenders (publisher)

```sql
SELECT pid, state, wait_event_type, wait_event, application_name, backend_start
FROM pg_stat_activity
WHERE backend_type LIKE '%walsender%';
```

State / wait combinations:
- `streaming` + `WalSenderWaitForWAL` — main slot, healthy idle.
- `startup` for application_name `pg_<oid>_sync_<relid>...` — sync worker not yet streaming. Brief OK; sustained = stuck.
- `active` + `ClientWrite` — TCP back-pressure. Subscriber isn't reading fast enough. Usually a network problem (see `tailscale` skill).
- `idle in transaction` + `ClientRead` — publisher done sending, waiting for subscriber to ACK. Subscriber-side issue.

### Slot health (publisher)

```sql
SELECT slot_name, plugin, slot_type, active, active_pid, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots ORDER BY slot_name;
```

Main slot should be `active=t`. Sync slots (`pg_<oid>_sync_*`) appear during initial copy and go away when each table reaches `r` state. Stale-but-inactive sync slots = leftovers from killed workers; clean up with `SELECT pg_drop_replication_slot('<name>')`.

## Common stuck states & fixes

### Sync workers zombie out (per_subscription_rel stuck in `d`)

**Symptom:** `pg_subscription_rel` shows tables stuck in `d` for minutes; `pg_stat_subscription` shows worker PIDs with `last_msg_receipt_time` minutes old. `max_logical_replication_workers` slots full of zombies, no new sync workers spawn.

**Fix:**

```sql
-- Subscriber: kill the zombie processes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE backend_type = 'logical replication worker' AND state IS NULL;

-- Publisher: clean up stale sync slots
SELECT pg_drop_replication_slot(slot_name)
FROM pg_replication_slots
WHERE slot_type = 'logical' AND active = false AND slot_name LIKE 'pg_%_sync_%';
```

After kill, fresh sync workers spawn automatically. With `max_sync_workers_per_subscription = 2` (default), tables process two at a time. If many zombies persist, the GUC value caps how many sync workers can run; raise it temporarily if needed.

### Worker timeouts on slow links

**Symptom:** Postgres log says `terminating logical replication worker due to timeout`. Sync workers cycle every 60s.

**Fix:** Bump both ends to 5 min and reload:

```sql
-- Publisher
ALTER SYSTEM SET wal_sender_timeout = '5min';
SELECT pg_reload_conf();

-- Subscriber
ALTER SYSTEM SET wal_receiver_timeout = '5min';
SELECT pg_reload_conf();
```

Existing workers keep their old timeout values; bounce them via `ALTER SUBSCRIPTION ... DISABLE` then `ENABLE`, or terminate and let them respawn.

### After MTU/network change, replication still stalled

**Symptom:** Network path tests fast (e.g., `psql -c` from subscriber container takes <1s), but sync workers still stuck.

**Cause:** Existing replication TCP connections cached the old (broken) path. Workers won't pick up the fix.

**Fix:**

```bash
# Both hosts:
sudo ip route flush cache

# Subscriber: kill workers; they reconnect via the now-fixed path
docker exec dk400-postgres psql -U <admin> -d dk400 -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity \
   WHERE backend_type = 'logical replication worker' AND state IS NULL;"
```

### Slot `wal_status = lost` (silent break)

**Symptom:** Subscriber apply worker crash-loops with `ERROR: could not start WAL streaming: ERROR: can no longer get changes from replication slot "<sub>"`. On the publisher: `SELECT slot_name, wal_status, restart_lsn FROM pg_replication_slots` shows `wal_status='lost'`, `restart_lsn=NULL`. Subscription stays enabled but no `pid` in `pg_stat_subscription`.

**Cause:** Subscriber was disconnected long enough that publisher's WAL exceeded `max_slot_wal_keep_size`, so the slot was invalidated. Once `lost`, there is no recovery — the WAL the subscriber needed is gone.

**How it happens silently:** the subscription remains `subenabled=true` and `pg_subscription_rel` keeps all tables in `r` state — only the absence of a worker `pid` and the publisher's `lost` status reveal the break. Saw this 2026-05-27: replication went down 2026-05-06 during the home `dk400-postgres` image rebuild (ADR 0009); subscriber didn't reconnect fast enough; slot invalidated; no alert until 21 days of data drift caught it.

**Detection (run regularly!):** combined publisher + subscriber check:
```sql
-- Publisher
SELECT slot_name, wal_status, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag
FROM pg_replication_slots WHERE slot_type='logical';
-- Any wal_status='lost' = break. Any wal_status='extended' = approaching cap.

-- Subscriber
SELECT subname, pid, last_msg_receipt_time, EXTRACT(EPOCH FROM (now()-last_msg_receipt_time))::int AS lag_s
FROM pg_stat_subscription;
-- pid=NULL means apply worker is dead/looping. Cross-check publisher logs.
```

**Recovery (= "Full subscription reset" below).** Save the new replicator password somewhere durable before running CREATE SUBSCRIPTION — the conninfo string isn't recoverable from `pg_subscription` after drop.

**Prevention:** raise `max_slot_wal_keep_size` so the publisher tolerates longer subscriber outages without invalidating. Boat now at 32 GB (NVMe ~700 GB free; storage-mode write rates make 32 GB worth weeks of slack). Trade-off: a stuck/zombie slot can fill disk if you set this too high or to `-1`.

### Full subscription reset (last resort)

If the subscription is in a state nothing else fixes:

```sql
-- Subscriber:
ALTER SUBSCRIPTION <schema>_sub DISABLE;
ALTER SUBSCRIPTION <schema>_sub SET (slot_name = NONE);  -- so DROP doesn't fail trying to drop the slot
DROP SUBSCRIPTION <schema>_sub;

-- Publisher: drop main + sync slots
SELECT pg_drop_replication_slot('<schema>_sub');
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE slot_name LIKE 'pg_%_sync_%';

-- Subscriber: TRUNCATE all replicated tables (CREATE SUBSCRIPTION with copy_data
-- expects empty tables on the subscriber side)
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = '<schema>' LOOP
    EXECUTE 'TRUNCATE <schema>.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

-- Subscriber: recreate
CREATE SUBSCRIPTION ... ;
```

## Extension dependencies

Tables that use extension types (PostGIS `geography`, pgvector `vector`) need the extension on **both** publisher and subscriber. If the subscriber doesn't have the extension:

1. Don't try to apply the table's DDL on the subscriber — it will fail at the column type. The `CREATE TABLE` from `pg_dump --schema-only` will error out.
2. Drop the table from the publication so logical replication doesn't try to ship it.
   ```sql
   ALTER PUBLICATION <schema>_pub DROP TABLE <schema>.<table>;
   ```
3. Document it as deferred until the extension lands. When the extension is added, re-create the table DDL, re-add to the publication, and `ALTER SUBSCRIPTION ... REFRESH PUBLICATION` on the subscriber.

Known cases (current as of 2026-05-06):
- All previously-deferred tables are now replicated: home dk400-postgres was upgraded to a pgvector + PostGIS image (ADR 0009, 2026-05-06). `cruising.moorages` and `cruising.job_embeddings` are now in `cruising_pub` (57 tables total). `imaging.document_chunks` is created on home and the imaging-service worker syncs chunks via app-level `/sync/*` (per imaging-service ADR 0003).
- **Extension-install gotcha:** when running `CREATE EXTENSION vector` (or postgis), the extension lands in the first schema in the executing role's `search_path`. `homelab_admin` on home defaults to `fixer` first — extensions ended up in `fixer.*`, breaking `imaging/schema/003-document-chunks.sql` which references `vector(768)` unqualified. Fix: `DROP EXTENSION ... CASCADE; SET search_path TO public; CREATE EXTENSION ... SCHEMA public;`.

## Schema migration drift

Logical replication does NOT carry DDL. When a column is added to `cruising.jobs` on centralsk:

1. Apply the same DDL on home (idempotently — `ADD COLUMN IF NOT EXISTS`).
2. On home: `ALTER SUBSCRIPTION <schema>_sub REFRESH PUBLICATION` so the subscription picks up the new column shape.

If a NEW table is added to centralsk's `cruising` schema that should replicate:

1. `pg_dump -s -t <schema>.<newtable>` on centralsk → apply on home.
2. `ALTER PUBLICATION <schema>_pub ADD TABLE <schema>.<newtable>` on centralsk.
3. `ALTER SUBSCRIPTION <schema>_sub REFRESH PUBLICATION` on home.

If a table is added but should NOT replicate (e.g. new raw-telemetry table per ADR 0008 summary-shipping pattern), do nothing — the explicit publication list keeps it out by default.

### Drift on a PUBLISHED table blocks the WHOLE stream (seen 2026-06-05)

Any un-appliable change to a published table makes the apply worker **crash-loop and halt the entire `cruising` apply stream** — so `vessel_log` and everything else silently freeze, even though only one table drifted. The cruising-app evolves the boat schema often; this recurs.

- **Symptom / canary:** the MagicMirror "DSII Stats" box goes stale while the boat is fine. `cruising.vessel_log` on home stops advancing; on the boat it's current.
- **The misleading part:** `pg_stat_subscription` shows a worker `pid` and a tiny `lag` (3s) — but that's just **keepalives**. The real tells: `received_lsn` is **NULL** (not streaming), the **publisher slot is `active=f`** with WAL piling up (`pg_wal_lsn_diff(...) > 0`), and the home Postgres log crash-loops every ~5s.
- **Find the actual error** in the subscriber log: `docker logs dk400-postgres | grep -iE "logical replication|violates|missing"`. Two forms seen: `target relation "cruising.port_visits" is missing replicated columns` (boat added columns) and `violates check constraint "..._check"` (boat **dropped/relaxed** a CHECK that home still enforces).
- **Fix:** make the home table accept the boat's rows — `ADD COLUMN IF NOT EXISTS` for new columns; for a constraint the boat dropped, `DROP CONSTRAINT IF EXISTS` on the replica (the boat is the validated source). Then the worker resumes and drains the backlog automatically.
- **psql gotchas that bit here:** (1) a multi-statement `psql -c "ALTER TABLE …; ALTER TABLE …; ALTER SUBSCRIPTION … REFRESH;"` runs as ONE implicit transaction — and `REFRESH PUBLICATION` **cannot run in a transaction**, so its error **rolls back the ALTER TABLEs too** (they print "ALTER TABLE" then silently revert). Run each `ALTER TABLE` in its own `-c`, and `REFRESH PUBLICATION` as a standalone `-c`. (2) the apply worker caches relcache — a worker that started mid-DDL may error one more cycle, then a freshly-started worker picks up the change.

**Detection gap:** nothing proactively alerts on this — the mirror was the only signal, after ~9h. A dk400 replication-health check (apply-worker crash-loop / `active=f` slot / growing lag) is the right fix.

## Cross-site state (current as of 2026-05-06)

- Publisher: centralsk `dk400-postgres` (image `centralsk/postgres:pg16`), `wal_level=logical`, `wal_sender_timeout=5min`, `max_slot_wal_keep_size=32GB` (bumped 2026-05-27 from 4GB after a 21-day silent break — see "Slot lost" pattern below).
- `replicator` role with REPLICATION attribute; password in Bitwarden / fixer's secret store.
- `cruising_pub` enumerates 57 tables (operational + summary + `moorages` + `job_embeddings`; raw telemetry excluded by ADR 0008's summary-shipping pattern).
- Subscriber: home `dk400-postgres` (image `dk400-postgres:pg16`, built from `dougkimmerly/dk400-postgres-image`), `wal_receiver_timeout=5min`.
- `cruising_sub` subscription, slot active on publisher, all 57 tables in `r`.
- pg_hba on centralsk: `host replication replicator 100.121.19.37/32 scram-sha-256` and `host all replicator 100.121.19.37/32 scram-sha-256`.
- Both hosts run `pgvector 0.8.2` and `PostGIS 3.x` (centralsk 3.4 — pre-Phase-5; home 3.6.3 — post-Phase-5; will converge on next centralsk rebuild). Image source-of-truth: github.com/dougkimmerly/dk400-postgres-image.
