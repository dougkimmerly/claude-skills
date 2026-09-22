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

## ⚠ Resolving a scheduled job to the COMMANDS it runs — the join that works

**`RBTROB.CMD_SET_OID` is `0` on almost every job, so it is not the link** (see
the `xtl400` skill's warning not to conclude a job has no command from it). The
link that works, measured 2026-09-22 on XTL:

**`RBTCS_CMD_SETS.CMD_SET_NAME` holds the ROBOT JOB NUMBER**, zero-padded to 12
characters (`000000001364`) — not a name. So the chain is job → command set by
*number*, command set → commands by OID:

```sql
SELECT R.ROBOT_JOB_NAME, C.CMD_LINE_NUMBER, CAST(C.CMD_STRING AS VARCHAR(120))
  FROM ROBOTLIB.RBTROB R
  JOIN ROBOTLIB.RBTCS_CMD_SETS S
    ON CAST(S.CMD_SET_NAME AS CHAR(12)) = CAST(R.ROBOT_JOB_NUMBER AS CHAR(12))
  JOIN ROBOTLIB.RBTCMD C ON C.CMD_SET_OID = S.CMD_SET_OID
 WHERE R.ROBOT_JOB_NAME = '<job>'
 ORDER BY C.CMD_LINE_NUMBER;
```

That is what turns *"a job called `FOURKITES` exists"* into *"it runs
`CALL PGM(PARTNCSVCL) PARM('01')` every fifteen minutes"* — the second hop the
section below calls "not always resolvable" is resolvable this way for ordinary
command jobs.

**Searching `RBTCMD` alone still misses things**, and knowing why saves a wrong
negative: a `LIKE '%FOURKITE%'` over `CMD_STRING` returns nothing for that job,
because the vendor's name appears only in the job name and description and in
the *program's* source. Search `RBTROB.ROBOT_JOB_DESC` too, and remember the
command names a program, not a purpose.

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
- **Every column has a long name as well as the six-character one**, and the
  long names are self-documenting: `JOB_NAME`, `ROBOT_JOB_NUMBER`,
  `JOB_STATUS`, **`MSG_TEXT`** (`CHAR(60)`), `OS_JOB_NAME`, `OS_JOB_USER`,
  `OS_JOB_NUMBER`, `OS_JOB_START_TIME`, `OS_JOB_END_TIME`, `TIME_STAMP`. Prefer
  them. There is **no `CMTEXT`** — guessing it by pattern from `CMRNAM`/`CMMSEV`
  gets `SQL0206`. Get the list from `QSYS2.SYSCOLUMNS`; `COLUMN_TEXT` carries
  Fortra's own field text for each one.

## ⚠ "Error On Submit Job Setup" — Robot fired, the machine refused

Measured on XTL 2026-09-21. **This is the failure mode where the scheduler
works perfectly and your job never exists**, and it is invisible to any
monitoring your job does itself:

```
JOB_NAME  JOB_STATUS  MSG_TEXT                                          OS_JOB_START_TIME  OS_JOB_END_TIME
MAPCOLL   E           Error On Submit Job Setup for Robot Job MAPCOLL    30000              30001
```

**One second, severity `E`, and nothing else anywhere.** The job's own tables
are empty — not a failure row, *no row* — because the program never ran. So a
collector that carefully distinguishes *reached it and found nothing* from
*could not reach it* still reports the last successful run and no error.

**Check the schedule fired before you debug the program.** `RBTMSG` is the only
place that knows:

```sql
SELECT JOB_NAME, JOB_STATUS, MSG_TEXT, OS_JOB_NAME, OS_JOB_USER,
       OS_JOB_START_TIME, OS_JOB_END_TIME
  FROM ROBOTLIB.RBTMSG WHERE JOB_NAME = '<job>'
 ORDER BY TIME_STAMP DESC FETCH FIRST 5 ROWS ONLY
```

**What to rule out, in this order** — the first three are cheap and were all
fine in the measured case:

1. The schedule entry itself — `SCHED_RUN_TIME_1`, the `RUN_FLAG_*` day flags,
   `CALENDAR_NAME`.
2. **The job queue exists and is released** — `QSYS2.JOB_QUEUE_INFO`, and check
   `MAXIMUM_ACTIVE_JOBS`, since `MAXACT(1)` on a shared queue is a different
   failure that looks like a slow one.
3. The `OS_JOB_USER` profile is `*ENABLED` and not `PASSWORD(*NONE)` —
   `QSYS2.USER_INFO`, and note a profile can always read its **own** row when
   an ordinary profile cannot read anyone else's.
4. ~~**Then: can Robot's own profile submit a job AS that user?**~~
   **⚠ RESOLVED 2026-09-21, AND THIS WAS THE WRONG ANSWER.** It was carried
   here as "the leading candidate" for a day and sent a session chasing an
   authority that was never the problem.

**STOP RULING THINGS OUT AND READ THE JOB LOG. The answer is in it.**

The `JLOG<hhmmss>` spooled file named in `MSG_TEXT` *is* the diagnosis, and
the real cause was three ordinary messages sitting in it:

```
CPF1266  User <profile> not authorized to library QRDARS
CPF1266  User <profile> not authorized to library XTLBC
CPF1338  Errors occurred on SBMJOB command
```

**The job inherited a library list it had no authority to.** With
`JOBD(*RBTDFT)` the submitted job takes the standard application library
list — twenty-odd libraries — and a least-privileged batch profile is
excluded from some of them. `SBMJOB` then fails before the program exists.

**The tell that should redirect you immediately: the same error under two
different submitters.** In the measured case it failed at 03:00 under
`RBTUSER` and again at 11:08 under a named human. Nothing about the
*submitter* can explain that — it is the **submitted job's own definition**.
Check that first and you save a day.

**The fix is a job description of the application's own**, with a minimal
`INLLIBL`, rather than granting the batch profile access to libraries it
never reads. Worked instance: `proj-as400-codemap` ADR 0016 and
`mapcoll/install/runtime.sql`.

**Reading the log is the hard part, not the diagnosis.**
`SYSTOOLS.SPOOLED_FILE_DATA` returns **zero rows, no error**, for a spooled
file you do not own, and `QUSRSYS/QEZJOBLOG` is `DSPDTA(*NO)`. Either own the
file or set `DSPDTA(*YES)` on a queue you can reach — see the `xtl400` skill.
**Give any job you schedule its own output queue with `DSPDTA(*YES)`**, or its
failures are undiagnosable by you.

## `JOB_HAS_MONITOR = 0` means the job cannot report its own failure

`RBTROB.JOB_HAS_MONITOR` is `0` by default, and a job without a monitor fails
**silently** — no message, no alert, nothing. In the measured case a total
failure of a project's only unattended component went unnoticed for seven
hours and was found only because someone had written down to check that
morning.

**So for any job that matters, two separate things are needed and neither
implies the other:** the job must run, *and* something must notice when it does
not. Check it explicitly when adding a job:

```sql
SELECT ROBOT_JOB_NAME, JOB_HAS_MONITOR FROM ROBOTLIB.RBTROB
 WHERE ROBOT_JOB_NAME = '<job>'
```

Per-job monitors live in `ROBOTLIB.RBTJM` (overrun, underrun, late-start, and
the action for each). **A monitor is a commitment, not a setting** — somebody
starts receiving its alerts, so adding one is a conversation with whoever
operates the estate, not a config change.

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

## ⚠ HOW TO HAND DOUG A JOB TO KEY IN — THE STANDARD FORMAT

**Doug keys Robot jobs by hand on the green screen. He does not read a table of
SQL column names.** Hand him anything else and he has to translate it while
typing, which is the work he delegated.

**The standard is: reproduce the screen.** One block per panel, in panel order,
fields in the order they appear on that panel, using **the screen's own labels
and spelling** — not the SQL column names, not your own wording. A value he
leaves alone is shown as `(leave)`, never omitted, so he never has to wonder
whether you forgot it or meant the default.

Screen-by-screen field maps are below. **Fill them from the box before you
present anything** — read an existing job that works and copy its values, rather
than deriving them from what the fields ought to be.

Format, exactly:

```
RBT201  Initial Job Setup                    ── screen 1 of N

  Job Type . . . . . . C
  Job Name . . . . . . MAPDERIVE
  Desc . . . . . . . . pgm map derived harvests
  Application  . . . . MAPPER
  Notes  . . . . . . . (leave)

  RUN INFORMATION
  Run Times  . . . . . 4:15      (slots 2-8 leave)
  Run Days Y/WK/L  . . Y on all seven
  Schedule Override  . (leave)

  F10=Next Option
```

**After he keys it, read it back from `RBTROB` and diff it against what you
asked for.** Not to check his typing — to catch the fields a later panel
defaults that neither of you named. That is how `OS_JOB_USER = *RBTDFT` was
found on `MAPDERIVE` (2026-09-22), which would have failed the job completely.

### Screen 1 — `RBT201` *Initial Job Setup for Job Number NNNNNNNNNNNN*

Verified against the live screen and read back from `RBTROB`, 2026-09-22.

| Screen label | `RBTROB` column | System | Notes |
|---|---|---|---|
| **Job Type** | `ROBOT_JOB_TYPE` | `JOBTYP` | `C` = Command. **F4 prompts** |
| **Job Name** | `ROBOT_JOB_NAME` | `JOBNAM` | 10 chars |
| **Desc** | `ROBOT_JOB_DESC` | `PROGDS` | |
| **Application** | `APP_OID` → `RBTAP_APPLICATIONS.APP_NAME` | `RTAPOID` | **A NAME ON SCREEN, AN OID IN THE TABLE.** `MAPPER` = 303. `MAPCOLL` has 0 — no application |
| **Notes** | `ROBOT_JOB_NOTES` | `RBNOTE` | |
| **Run Times** ×8 | `SCHED_RUN_TIME_1`…`_8` | `TIMES1`…`8` | Keyed `4:30`, **stored `430`** — `HHMM`, no leading zero |
| **Run Days** `Y/WK/L` | `RUN_FLAG_MON`…`SUN` | `MONDO`…`SUNDO` | `Y`=every week, `WK`=week number, `L`=last week of month |
| **Schedule Override Code** | `SCHED_OVRRD` | `SCHOVR` | F4 prompts |

**`START_TIME` is not on this screen.** Robot mirrors `SCHED_RUN_TIME_1` into it.
Do not ask Doug for a start time; ask for run times.

Keys: `F3`=Exit · `F4`=Prompt · **`F10`=Next Option** · `F12`=Previous ·
`F21`=Command Line · `F23`=More Options.

### Screen 2 — `RBT292M1` *Robot Command Entry* (`F10` from screen 1)

The command list. Header reads *"Commands for job . . . : MAPDERIVE"*.

```
  Opt  Seq   Command                                            Error
   _    1    RUNSQL SQL('CALL XTLPGMMAP.MAPDICTH()') COMMIT(*NONE)  C
   _    2    RUNSQL SQL('CALL XTLPGMMAP.MAPHDRS()')  COMMIT(*NONE)  C
```

Options: `1`=Select · `4`=Delete · `7`=Insert.
Keys: `F3` · `F4`=Prompt · `F7`=Reserved Cmd Variables · `F8`=Command Finder ·
**`F10`=Next Option** · `F12`=Previous · `F24`=More keys.

| Screen column | Table | Column |
|---|---|---|
| Seq | `RBTCMD` | `CMD_LINE_NUMBER` |
| Command | `RBTCMD` | `CMD_STRING` |
| **Error** | `RBTCMD` | **`CMD_ERROR_HANDLING`** — `C` on screen = `2` stored |

### Screen 3 — `RBT291` *Extended Command Entry* (`1`=Select a line)

Where one command is defined in full.

| Screen label | Column | Notes |
|---|---|---|
| Sequence number | `CMD_LINE_NUMBER` | |
| **Command Error Processing** | **`CMD_ERROR_HANDLING`** | **`1`=Ignore, `2`=Cancel.** Cancel means a failure here stops every LATER sequence |
| Command | `CMD_STRING` | **A MULTI-LINE BOX**, ~8 lines with `More...` |

**⚠ NO CONTINUATION CHARACTERS.** The screen says it outright: *"Continuation
symbols are not allowed or necessary."* A long command is simply typed across
the lines of the box. **Never hand Doug a command broken with `+` or `-`** — the
box does the wrapping, and a continuation character is a syntax error.

Three more rules printed on that screen, all worth knowing before you compose a
command:

- **Variable substitution is `@n`** — `@1`, `@2`.
- **Every command must have an OS batch *and* interactive entry code.**
- **Nested Robot commands start with `¢`** — `OVR2` is written `¢OVR2`.

**`CMD_ERROR_HANDLING = 2` (Cancel) is the house convention and should be left
alone: 1,115 commands on this estate use it against 6 using Ignore.** For a job
whose procedures trap their own errors it makes no practical difference, and
knowing why is the point: an SQL procedure with its own `EXIT`/`CONTINUE`
handler ends NORMALLY after an internal failure, so `RUNSQL` succeeds and Cancel
never fires. **Cancel only catches a structural failure — a mistyped schema, a
missing procedure, an authority wall — and those break every command in the set
equally.** It is one more reason not to read Robot's completion status as
evidence the work happened.

**`RBTCMD.LAST_UPDATE_TIME` and `LAST_UPDATE_USER` are RELIABLE** — they carry
real dates and real names (`BARRY`, 2015). This is the opposite of
`RBTROB.LAST_UPDATE_TIME`, which is stuck at `0001-01-01` even on a job created
minutes ago. **To find out when a job's work last changed, read `RBTCMD`, not
`RBTROB`.**

### Screen 4 — `RBT202` *Advanced Scheduling* (`F10` from screen 2)

*"CHOOSE ONE TO SCHEDULE OTHER THAN BY DAY OF THE WEEK"*. **Usually left
entirely blank** — a job that runs on days of the week needs nothing here — but
it is where a large, easily-missed part of the estate's schedule lives.

| Screen option | `RBTROB` columns | System |
|---|---|---|
| `(INDAY)` start date + every *n* days, day type Work/Calendar/Non-Working | `INDAY_START_DATE`, `INDAY_INTERVAL`, `INDAY_DAY_TYPE` | `SDTINC`, `INCDAY`, `INCCOD` |
| **`(EVERY)` run every *n* minutes** | **`EVERY_INTERVAL`**, `EVERY_RANGE_START`, `EVERY_RANGE_END` | `EVRMIN`, `EVELOW`, `EVEHIH` |
| `(DATE)` dates in a Date Object | `DATE_OBJECT_NAME` | `RTDONM` |
| `(REACT)` when prerequisites are satisfied | `JOB_IS_REACTIVE` | `RTRACT` |
| `(DAYNO)` day numbers of the month + day type | `DAYNO_DAY_1`…`_4`, `DAYNO_DAY_TYPE` | `PROCD1`…`4`, `DAYCOD` |
| *which one was chosen* | `ADV_SCHED_CODE`, `ADV_SCHED_USED` | `ACTION`, `ADVSCH` |

`ADV_SCHED_CODE` holds the literal keyword — `EVERY` — and `ADV_SCHED_USED` is
`X`. Verified on `FOURKITES`: `EVERY` / `X` / `EVERY_INTERVAL = 15`.

### ⚠ COUNTING JOBS BY `START_TIME` UNDERSTATES THE LOAD, AND I DID IT

**83 jobs on this estate run on an interval, and they appear at NO start time
at all.** Measured 2026-09-22 — 15 min ×26, 60 ×22, 30 ×14, 10 ×6, 120 ×6.
**Most carry no range**, so they run right through the night.

A `GROUP BY START_TIME` to find a quiet slot therefore answers *"when does
nothing else START"*, which is not the same as *"when is the box quiet"*. It is
still the right way to avoid a pile-up of scheduled work — but say which
question you answered, and add the interval jobs to the picture.

**⚠ `EVERY_RANGE_START`/`_END` are CHARACTER, not numeric, and inconsistently
formatted.** Observed values include blank, `0600`/`2100`, and `00550`/`02350`.
A numeric comparison against them returns nothing and raises no error.

### Screen 5 — `RBT205` *Exception Scheduling* (`F10` from screen 4)

Also usually blank. *"MISCELLANEOUS SCHEDULING EXCEPTIONS"* and *"EXCEPTION
SCHEDULING OBJECTS"*.

| Screen label | `RBTROB` column | System | Notes |
|---|---|---|---|
| Run on non-working day | `RUN_ON_NONWORK_DAY` | `HOLRUN` | **`Y`=Yes, `N`=No, `F`=Run after, `B`=Run before** — four values, not a flag |
| **Start executing job only between times __ and __** | **`EVERY_RANGE_START` / `EVERY_RANGE_END`** | `EVELOW` / `EVEHIH` | ⚠ see below |
| Make this a Submit-Delay model job | `SUBMIT_DELAY_TYPE` | `RTTSMV` | F4 prompts Compare Options |
| Don't run on dates listed in Date Object | **unresolved** | | Not `DATE_OBJECT_NAME` — see below |
| Execute schedule instructions in OPAL Object | `OPAL_NAME` | `RTOPNM` | |

**⚠ `EVERY_RANGE_START`/`_END` IS NOT ABOUT `(EVERY)`.** The SQL name says it is;
the screen says *"Start executing job only between times"*, and it applies to any
job. Proof: **10 jobs have the range set with `EVERY_INTERVAL = 0`**, and 44 jobs
use it in total. Reading it as "the interval job's window" misreads 10 jobs and
misses an execution window on 44.

**⚠ The exception Date Object is NOT `DATE_OBJECT_NAME`.** That column is set on
exactly the 6 jobs whose `ADV_SCHED_CODE = 'DATE'` — the screen-4 *include*
list — and on nothing else. Where the screen-5 *exclude* list is stored is
**unresolved**, and no job on this estate appears to use it. Do not report a
job as having no date exclusions on the strength of that column.

### Screen 6 — `RBT203` *Output Options* (`F10` from screen 5)

For an ordinary job **the only field typed here is the Output Queue.**

| Screen label | `RBTROB` column | System | Default |
|---|---|---|---|
| **Output Queue** | `OS_OUTQ_NAME` | `RBOUTQ` | `*RBTDFT` |
| Library | `OS_OUTQ_LIB_NAME` | `OUTQLB` | `*RBTDFT` |
| Print text | `SPLF_PRINT_TEXT` | `PRTTXT` | blank |
| Number of copies (1–255) | `SPLF_COPIES` | `RBCOPY` | `0` |
| Output priority (1–9) | `OS_JOB_OUTPTY` | `OUTPRY` | `0` |
| Use Report Distribution? | `USE_REPORT_DIST` | `URPDST` | `N` — **`Y`=Yes, `N`=No, `R`=Robot Reports** |

**Typing `*JOBD` in Output Queue clears the Library field**, and that pairing is
what you want for an application with its own job description: the queue comes
from the `JOBD`, which is where you can set `DSPDTA(*YES)` and actually read
your own job logs. Leaving the shipped `*RBTDFT`/`*RBTDFT` sends job logs to
Robot's default queue, where `SYSTOOLS.SPOOLED_FILE_DATA` returns **zero rows
and no error** for a file your profile does not own.

Keys add `F15`=Select PreReq here — the reactive-job prerequisite list.

**⚠ The *Job date calculator* is only partly resolved.** The screen shows
*"Start with date type . . : `1`  F4  System Date"*, *"Date, Day Nbr, + or −
Days"* and a computed *"Equals the job date"*. `OS_JOB_DATE_VALUE` (`JOBDAT`)
is `0` on every job examined, and `OS_JOB_DATE_CODE` (`DTCODE`) holds
**blank ×437, `+` ×169, `Q` ×146** — which is not the `1` on the screen.
**Where the date type is stored, and what `Q` means, is UNRESOLVED.** Do not
report a job's effective date from these columns.

## What Robot can do, and what XTL actually uses — census 2026-09-22

**Read this before proposing a scheduling improvement.** 752 jobs.

| Capability | Column | Jobs using it | |
|---|---|---|---|
| Runs other than by day of week | `ADV_SCHED_CODE` | **162 (22%)** | `EVERY` 83 · `DAYNO` 45 · `INDAY` 28 · `DATE` 6 |
| Maximum run time + action | `MAX_RUN_DURATION` / `MAX_RUN_ACTION` | **364 (48%)** | action `1` ×295, `2` ×69; durations 2–960 |
| Schedule override code | `SCHED_OVRRD` | 191 (25%) | |
| Execution-time window | `EVERY_RANGE_START/_END` | 44 (6%) | |
| Reactive (prerequisite) jobs | `JOB_IS_REACTIVE` | 13 | |
| **Job monitor** | **`JOB_HAS_MONITOR`** | **11 (1.5%)** | |
| Non-working-day handling other than `Y` | `RUN_ON_NONWORK_DAY` | 2 | |
| OPAL schedule logic | `OPAL_NAME` | 1 | |
| Submit-Delay model | `SUBMIT_DELAY_TYPE` | **0** | shipped, never used here |

**The gap that matters: 364 jobs have a maximum run time, 11 have a monitor.**
They are different mechanisms and must not be conflated — a max run time catches
a job running too LONG; a monitor is what notices a job that did not run, ran
too SHORT, or started late. **On this estate 741 jobs can fail silently**, which
is the same finding that cost seven hours on 2026-09-21, now quantified.

**A monitor is a commitment, not a setting** — somebody starts receiving its
alerts — so proposing them is a conversation with whoever operates the estate,
not a config change. But the 48%-versus-1.5% split is the single clearest
improvement available in this schedule.

### What a BLANK job looks like — the defaults, so you know what NOT to ask for

Read from a freshly-added empty job (1828) the moment it was created. **Anything
matching this column was never keyed**, which is how you tell a deliberate
setting from a shipped one:

| | Default |
|---|---|
| `OS_JOB_USER`, `OS_JOBD_NAME`/`_LIB`, `OS_OUTQ_NAME`, `OS_JOBQ_NAME`/`_LIB` | **all `*RBTDFT`** |
| `CALENDAR_NAME` | `*RBTDFT` |
| `ENV_NAME` | `STANDARD` |
| `HIST_RETENTION` | `40` |
| `RUN_ON_NONWORK_DAY` | `Y` |
| `JOB_HAS_MONITOR`, `CMD_SET_OID`, `APP_OID` | `0` |
| `LAST_UPDATE_TIME` | `0001-01-01` — **and it stays that way**, see above |

**⚠ `OS_JOB_USER` defaults to `*RBTDFT`, and for a least-privileged application
that is a total failure, not a fallback.** A schema owned `AUT(*EXCLUDE)` gives
`SQL0551` to every other profile, so the job runs, finds nothing it may touch,
and the work silently never happens. **Always name the user profile explicitly
and always read it back.**

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
