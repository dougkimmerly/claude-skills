---
name: robot-schedule
description: "Fortra (HelpSystems) Robot/SCHEDULE as it actually runs on XTL's IBM i — the estate's real job scheduler. Use for ANY question about what is scheduled, when a job runs, why it did not run, reading RBTROB/RBTMSG, adding or verifying a scheduled job, or Robot's date/time encodings. The installed version is R10M01 (Robot 10, ~2006-2010) and most published documentation describes a product two generations newer. NOT dk400's `robot` skill, which is a Celery scheduler named in homage and shares nothing but the name. Companion to `xtl400` (the box itself) and proj-as400-codemap/docs/research/robot-sources.md (where documentation lives)."
triggers:
  - robot schedule
  - robot/schedule
  - fortra
  - helpsystems
  - RBTROB
  - ROBOTLIB
  - OPAL
  - scheduled job
  - what is scheduled
  - job did not run
---

# Robot/SCHEDULE on XTL's IBM i

**The estate's real scheduler.** IBM's own job scheduler is near-empty here; the
schedule that runs the business is Robot's.

**Installed version: `R10M01`** — read it, never assume it:

```sql
SELECT DATA_AREA_LIBRARY, DATA_AREA_VALUE
  FROM QSYS2.DATA_AREA_INFO WHERE DATA_AREA_NAME = 'RBTIVER';
```

Robot 10 is roughly a 2006–2010 product; Fortra ships 13.20. **Most
documentation you will find describes a product two generations newer**, and the
difference is real — the 13.20 guide documents `RBTDEP5`/`RBTDEP9`, neither of
which exists here. Sources ranked by *vintage fit* rather than recency are in
`proj-as400-codemap/docs/research/robot-sources.md`. Fortra does not publish file
layouts at all, so **every field mapping below is provisional and may break on
upgrade.**

## Which library is live

`ROBOTLIB`. `RBTIVER` exists only there, which is the test.

`RBTROB` **also exists in `ROBOTLIBV8`, `ROBOTLIBV9` and `ROBOTMSTV3`, with
different column sets** — a query written for one fails `SQL0206` on the others.
Those are older-version remnants. Do not read them as the schedule, and do not
conclude a job is absent because one of them lacks it.

## ⚠ `JOB_NAME` IS AN SQL SPECIAL REGISTER — AND `RBTROB` HAS NO SUCH COLUMN

**The single most dangerous trap here, because it returns rows instead of an
error.** Measured 2026-09-20:

```sql
SELECT JOB_NAME FROM ROBOTLIB.RBTROB;     -- 748 rows, every one identical:
                                          -- 361374/QUSER/QZDASOINIT
```

That is *your own SQL server job*, not a Robot job. Db2 for i resolves
`JOB_NAME` to the special register when the table has no column of that name,
**silently**. So `WHERE UPPER(JOB_NAME) LIKE '%MAP%'` compares the current job
name against your pattern and returns **zero rows, cleanly** — and a session
concluded from exactly that "the schedule was last touched in 2020". It was not.

**The real columns are `ROBOT_`-prefixed**, with short system names underneath:

| SQL column | System | Holds |
|---|---|---|
| `ROBOT_JOB_NAME` | `JOBNAM` | the job name |
| `ROBOT_JOB_NUMBER` | `KYTIME` | job number |
| `ROBOT_JOB_DESC` | `PROGDS` | description text |
| `ROBOT_JOB_TYPE` | `JOBTYP` | job type |
| `OS_JOB_USER` | `PROFIL` | **the profile it runs as** |
| `START_TIME` | `TIMEST` | start time, **`HHMM`** — see below |
| `CALENDAR_NAME` | `CALNAM` | calendar |

**Always list the columns before writing a query against any Robot file:**

```sql
SELECT COLUMN_NAME, SYSTEM_COLUMN_NAME, COLUMN_TEXT
  FROM QSYS2.SYSCOLUMNS
 WHERE TABLE_SCHEMA = 'ROBOTLIB' AND TABLE_NAME = '<file>'
 ORDER BY ORDINAL_POSITION;
```

Robot's files are externally described with **field text on every column**, so
`SYSCOLUMNS` against `ROBOTLIB` is a data dictionary for *exactly* the installed
version. It outranks every document anywhere.

## Is a job scheduled, and when?

```sql
SELECT ROBOT_JOB_NAME, OS_JOB_USER, START_TIME, ROBOT_JOB_DESC
  FROM ROBOTLIB.RBTROB
 WHERE UPPER(ROBOT_JOB_NAME) LIKE '%<name>%'
    OR UPPER(ROBOT_JOB_DESC) LIKE '%<name>%';
```

Worked example — verifying a job added the same day:
`MAPCOLL · PGMAPPER · 300 · code map collection`, i.e. **03:00 as `PGMAPPER`**.

## ⚠ TWO DIFFERENT TIME ENCODINGS IN THE SAME PRODUCT

Do not carry one file's encoding to another. Verified by range, not assumed:

| Field | Encoding | Example |
|---|---|---|
| `RBTROB.START_TIME` | **`HHMM`** (max observed 2359, plus 9999 sentinels) | `300` = **03:00** |
| `RBTMSG.CMSTIM` | **`HHMMSS`**, no leading zero | `60500` = **06:05:00** |

Read `START_TIME` as `HHMMSS` and `300` becomes 00:03 — six hours wrong, in the
direction that looks plausible. **Check the range before trusting either:**
`SELECT MIN(...), MAX(...)` — a max of 2359 means `HHMM`, a max in the 235959
range means `HHMMSS`.

## Dates

- **Dates are `CYYMMDD` as a 7-digit number** — `1260914` = 2026-09-14, leading
  digit is the century. **`DATE(...)` does not parse this and does not fail
  usefully.**
- `proj-as400-codemap` carries an `RBTSTAMP` SQL function that converts Robot's
  date format; borrow it rather than rewriting the arithmetic.

## Finding a recent change

**`RBTROB.LAST_UPDATE_TIME` is not reliable** — its newest value was 2020-12-18
on a day a job was demonstrably added. **`ROBOTLIB.RBTCS_CMD_SETS` is**, and it
names the person:

```sql
SELECT CMD_SET_NAME, LAST_UPDATE_TIME, LAST_UPDATE_USER
  FROM ROBOTLIB.RBTCS_CMD_SETS
 ORDER BY LAST_UPDATE_TIME DESC FETCH FIRST 5 ROWS ONLY;
```

Command sets join to jobs by `CMD_SET_OID`.

## `RBTMSG` is a MESSAGE table, not a run table

- Up to **26 rows** share one `(CMRNAM, CMRJOB, CMSDAT, CMSTIM)`. Treating a row
  as a run violates any primary key on that tuple — `SQL0803`. **Aggregate to
  the run.**
- **`CMRJOB` is blank for some jobs**, so the tuple does not always identify a
  run. Run counts for those jobs are unreliable; unresolved.
- **`CMMSEV` is `A(1)`** and holds letters (`C`, `W`, `T`), not a number.
  **`CMRJOB` is `A(12)`**, zero-padded, not an integer.
- **`RBTROB.HIST_RETENTION` is per job.** For retentions 3, 7, 12, 14 and 30 the
  stored runs match exactly; for 6 and 40 — the two big populations — they do
  not, and why is unresolved. **Do not quote a run count per job.**

## What the schedule is, and what it is not

- **A scheduled entry is a command, not a program.** Schedule-to-program needs a
  second hop, and it is not always resolvable.
- **The schedule is a graph, not a list** — reactive jobs, groups, and OPAL
  event logic. A flat listing of `RBTROB` understates the dependencies badly.
- **Work exists outside Robot**: IBM job schedule entries, never-ending
  subsystem jobs, autostart jobs, and submitted work. "Not in Robot" is not
  "not scheduled".
- **Prefer the product's own reporting** over reverse-engineered SQL where it
  exists — `RBT409A` (job command list), `RBT443` (job record list),
  `RBT461`/`RBT463` (prerequisite and reactive cross-reference), `RBTJOB2RUN`,
  and the query engine via `RBTPRTQRYR`. They ship with the install, so they are
  version-correct by construction.

## Adding a job

What `MAPCOLL` needed, as a template:

| | |
|---|---|
| Command | `RUNSQL SQL('CALL SCHEMA.PROC()') COMMIT(*NONE)` |
| User | the profile the work's authority belongs to — **not a default** |
| Time | pick it from evidence, not habit (below) |

**Verify the exact command string before handing it over**, by running it
through `QSYS2.QCMDEXC` as the intended profile. Dot-qualified SQL names work
under `RUNSQL`'s default naming — measured, not assumed.

**⚠ `SAV*` job names are `Savoie`, a division — NOT saves.** A search for
backup jobs on name or description returns 41 of them and every one is a false
positive. **There are no backup jobs in Robot at all:** on this estate the
**backups run from the HA box**, off the MIMIX replica, so production is never
quiesced for them (Doug, 2026-09-20). This matters twice — a scheduled overnight
job on the primary has no save window to avoid, and "I found the backup job" is
a claim to check hard.

**Choosing a time from evidence.** `proj-as400-codemap`'s collector keeps an
observed run ledger (`XTLPGMMAP.MAPRUN`) — job starts by hour, from what
actually ran. On this estate, observed starts: **06:00 is the morning batch (2,006)**, 01:00
and 00:00 are busy, and **03:00–05:00 and 19:00–22:00 are quiet.**

Cross-check against what is *scheduled*, which is a different question — jobs
per hour from `RBTROB`: `00`=73, `01`=7, `02`=11, `03`=10, `04`=19, `05`=61,
`06`=105, `07`=83. The 01:00–04:00 trough sits between the midnight batch and
the morning surge.

**Then look at the actual neighbours, not just the hour count.** `RGZPFM` jobs
take exclusive locks and one runs at 03:30; a five-minute job at 03:00 clears
it, a twenty-minute one would not. Journal receivers also roll about 01:05, so
anything reading journals wants to be after that.

## ⚠ Robot reporting success is not evidence the work happened

A job that traps its own errors — deliberately, so one failure does not cost the
rest of the run — **ends normally on a night when it collected nothing**. Robot
can only report how the command ended.

**Monitor the work's own ledger, not the scheduler's status.** For the map
collector that is `XTLPGMMAP.MAPRUNLOG` via
`proj-as400-codemap/tools/queries/collector-health.sql`. Any job built on the
same principle needs the same treatment.

## Before you report anything about the schedule

1. Did you list the columns first, or assume a name? (`JOB_NAME` above.)
2. Is the query against `ROBOTLIB`, or an older version library?
3. Did you decode `CYYMMDD` and the no-leading-zero times?
4. Are you reporting the schedule, or the schedule *plus* the work outside it?
5. Is the field mapping you used provisional — and did you say so?
