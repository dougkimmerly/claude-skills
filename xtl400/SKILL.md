---
name: xtl400
description: "Work against XTL's real IBM i / AS/400 estate — the two-partition pair behind xtl400.xtl.com. Use for ANY query, extraction or diagnosis on XTL's 400: which box to talk to and why the answer changes, the read-only boundary and what QTEMP buys you, the release-7.3 SQL traps that reject valid-looking statements, and the blind spots that make a confident answer wrong. NOT dk400 (that is the `homelab-dk400` skill). Fortra Robot/SCHEDULE as it runs on this estate IS covered here -- the `robot` skill is a different product entirely (dk400's Celery scheduler) and does not apply. Consulted by proj-as400-codemap, proj-security, proj-imaging and kb-xtl400."
triggers:
  - xtl400
  - xtl 400
  - xtl as400
  - xtl iseries
  - XTLTOR
  - XTLMTL
  - ROBOTLIB
  - I93CSTMNEW
  - q400
  - cmd400
location: project
---

# XTL's AS/400

**First rule: ask the box.** Vendor documentation, web search and plausible
reasoning each lost to a single query on 2026-09-16 — five times in one day. This
estate is thirty years old, two product generations behind, and split across two
partitions whose roles swap. Every external source describes something adjacent
to it rather than it.

## Where the specifics live

This skill is the **method and the traps**. The estate's current facts live in
the repos, and duplicating them here would guarantee drift:

| Need | Go to |
|---|---|
| Hostnames, roles, serials | `proj-as400-codemap/tools/boxes.tsv` |
| Saved queries + the runners | `proj-as400-codemap/tools/` |
| Measurements, with their caveats | `proj-as400-codemap/docs/research/index.md` |
| Decisions (read-only boundary, storage, scope) | `proj-as400-codemap/docs/adr/` |
| Extracted source, captures | `kb-xtl400/` |
| IBM i / RPG / CL platform reference | `kb-ibm400` (MCP-exposed) |
| Security posture, findings, the access wall | `proj-security` — **counts and pointers only** |

## Connecting

**Credentials come from SOPS, never a plaintext file, and the profile is a
per-project choice.** `x400 <profile> <command>` decrypts one profile out of
`homelab-secrets` `secrets/home/xtl400.sops.yaml` and exports
`XTL400_USER`/`XTL400_PASSWORD` for that command only. That file is scoped to
the **admin age key alone** — no unattended host decrypts an XTL production
credential. Use the `secrets` skill to add or rotate one.

```bash
x400 ccsec sql400 "SELECT ..."                    # proj-security, curlib DOUGSEC
x400 ccimg ./tools/q400 primary whoami            # proj-as400-codemap
XTL400_HOST=192.168.40.20 x400 ccsec sql400 "..."  # the target; default is primary
```

**Pick the profile that matches the work.** `CCSEC` is proj-security's;
`CCIMG` is the mapping project's. They are separate so that `QAUDJRN`
attributes a read to the project that made it — a shared profile destroys
that, and on this estate the audit trail is itself under review.

**Whoever you connect as, you are inside the finding.** `CCIMG` is `*USER`
with no special authorities but `LMTCPB(*NO)`, and this box's `*PUBLIC`
posture gives update or delete on 80,454 files — so a "read-only" session is
read-only by *discipline*, not by constraint. Never rely on the profile to
stop a write. (proj-security #20.)

Needs the profile enabled by Doug plus Zscaler — **access is interactive, not
unattended**. Never echo a credential; `x400` keeps it in the environment of
one child process.

**A profile with `PASSWORD(*NONE)` cannot be connected to at all** — `x400`
fails with `AS400SecurityException: Password is *NONE`. That is the correct
end state for a *batch* identity (it runs under the scheduler and is not an
interactive account), so expect to lose access to a collector profile the
moment it is finished. Build and debug while the credential exists; once it is
revoked, changes go through Doug or through the scheduled job's own source.

### Getting source on and off the box

`put400` is the working route and it is the one to use. It writes a stream
file to the IFS and `CPYFRMSTMF`s it into a source member — record-level
access (DDM, port 446) is blocked on this box, so the obvious path does not
exist.

```bash
x400 <profile> put400 --write local.sql LIB SRCFILE MEMBER SQL
```

Dry run by default; `--write` is required. Two things it does not save you
from:

- **`SRCDTA` is `CHAR(100)`.** Anything past column 100 is lost on upload, and
  past column 80 is lost again by `RUNSQLSTM` unless you pass `MARGINS(100)`.
- **Non-ASCII characters survive the trip and then misparse.** A `§` in a
  comment reached the member intact and still broke things. Keep source ASCII.

`CRTBNDCL` / `RUNSQLSTM` then run through `CALL QSYS2.QCMDEXC('...')` from
`sql400`, which has no command-line length limit — the 5250 command line does,
and a long `CHGUSRAUD` will not fit on it. `QCMDEXC` is also how to hand Doug
a command that is too long to paste.

**Reading a member back is plain SQL — a source member is a table.** Point an
alias at it and select:

```sql
CREATE OR REPLACE ALIAS MYLIB.VFYMBR FOR MYLIB.QCLSRC(SOMEPGM);
SELECT SRCSEQ, SRCDTA FROM MYLIB.VFYMBR ORDER BY SRCSEQ;
```

**The alias target needs a dot, not a slash** — `MYLIB/QCLSRC(X)` is rejected
as `SQL5016` and the message does not explain itself.

**`sql400` trims every value it prints**, which silently strips the leading
indentation from each line and makes an identical file look completely
different. Guard column 1:

```sql
SELECT '|' CONCAT RTRIM(SRCDTA) FROM MYLIB.VFYMBR ORDER BY SRCSEQ
```

…then strip the `|`. This matters for any indentation-sensitive comparison,
not just source.

**Verify deployed source against the repo after every deployment.** Nothing on
the box does it for you, and git and the box drift silently. Two checks, and
you want both:

- **Strong** — pull each member and `diff`. Worked example:
  `proj-security/secaudit/verify-deployed.sh`.
- **Weak but automatic** — `QSYS2.SYSPARTITIONSTAT` gives `NUMBER_ROWS` and
  `LAST_SOURCE_UPDATE_TIMESTAMP` per member without reading it, so a scheduled
  job can record a line count as a fingerprint. **An edit that preserves the
  line count is invisible to it** — six changed comment lines across four
  members went undetected this way on 2026-09-19.

Compare the member's source timestamp against the compiled object's
`OBJCREATED` (`QSYS2.OBJECT_STATISTICS`) to catch *"edited on the box and never
recompiled"*, which is a different failure from repo drift and is detectable
outright.

## Two partitions, and the roles swap

There is no "the box". There is a **primary** and a **target**, and which
machine holds which role changes. They have already swapped once (workload moved
end of May 2026) and the target is scheduled for replacement.

- **`xtl400.xtl.com` follows the role**, so it is always the primary.
- **Bind to roles, never hostnames.** A tool that names a machine is wrong at the
  next swap and wrong *silently* — it keeps returning plausible numbers from the
  wrong box.
- **Provenance records the serial**, not just the role: "the target, in October"
  and "the target, in January" are different machines.

### Which work goes where

| Work | Role | Why |
|---|---|---|
| Catalog, inventory, resolution | **primary** | it describes what runs |
| `QHST` / system history | **primary** | per-partition; not replicated |
| Security system values | **both** | per-partition — the *diff* is the finding |
| Journal receiver reads | **target** | where receivers land; offloads the primary |
| Bulk source reads, expensive scans | **target** | the primary runs the business |

**Usage statistics are per-partition and are NOT replicated.** A replicated
object arrives with its creation date and content and *no* usage history. This is
why counters can look "wiped" on one box while eight years of them sit on the
other. Never read a last-used date without knowing which partition produced it.

## The read-only boundary

Nothing here changes anything on the box, with named exceptions
(`proj-as400-codemap/docs/adr/0007`):

- **`QTEMP` scratch is permitted, standing.** It is job-scoped and destroyed at
  disconnect. This is what makes `DSPPGMREF`/`DSPDBR` reachable at all — they are
  commands with no SQL equivalent.
- **Persistent writes need per-case approval**, and are done by **programs on the
  box** (scheduled, logged, stoppable by XTL) rather than by a session reaching in.
- Use `./tools/cmd400`, which enforces a fixed allow-list of display commands and
  refuses anything else without contacting the box. Do not widen it casually.

## Release 7.3 traps

Both partitions are 7.3 (upgrade expected; re-probe after). 7.3 rejects
statements that are valid on newer releases, and the errors do not say "old
release":

| Trap | Use instead |
|---|---|
| `ORDER BY … NULLS LAST` rejected | `CASE WHEN col IS NULL THEN 1 ELSE 0 END, col` |
| `GROUP BY 1` (ordinals) rejected | repeat the expression, or a derived table |
| `SYSMEMBERSTAT` absent (7.5 TR4 / 7.4 TR10) | `SYSPARTITIONSTAT`, or `DSPFD TYPE(*MBRLIST)` to `QTEMP` |
| `SYSFILES` absent (7.4+) | `OBJECT_STATISTICS`, `DSPFD` |
| `SOURCE_STREAM_FILE_PATH` absent | n/a on this estate |

**The column names in current IBM documentation are frequently not the column
names on 7.3, and the error never says so.** `SQL0206 … not found` is what a
renamed or not-yet-existing column looks like. Six of them cost a query each in
one afternoon — `USER_INFO` has no `OUTPUT_QUEUE_LIBRARY`, `JOB_DESCRIPTION_INFO`
has `JOB_QUEUE` not `JOB_QUEUE_NAME` and `LIBRARY_LIST` not
`INITIAL_LIBRARY_LIST`, `EXIT_PROGRAM_INFO` has `EXIT_PROGRAM` not
`EXIT_PROGRAM_NAME`, `SPOOLED_FILE_INFO` has `SPOOLED_FILE_NUMBER` not
`FILE_NUMBER`, `AUTHORITY_COLLECTION` has `AUTHORIZATION_NAME`/`CHECK_TIMESTAMP`
not `USER_NAME`/`AUTHORIZATION_CHECK_TIMESTAMP`, and `SYSTABLESTAT` has no
`TABLE_TEXT`. **Do not memorise that list — ask first**, it is one query:

```sql
SELECT COLUMN_NAME FROM QSYS2.SYSCOLUMNS
 WHERE TABLE_SCHEMA = 'QSYS2' AND TABLE_NAME = '<the view>'
 ORDER BY ORDINAL_POSITION;
```

Same for table functions that simply are not there. **`QSYS2.ACTIVE_JOB_INFO`
does not exist on XTL's 7.3 at all** — verified 2026-09-19 against
`QSYS2.SYSROUTINES`, which returns no row for it. `SQL0204 … not found` is the
literal truth here, not a disguised parameter error; an earlier version of this
note read it as the latter and was wrong. Dropping `SUBSYSTEM_LIST_FILTER`, or
calling it with no arguments at all, fails identically.

**Use `QSYS2.JOB_INFO` instead**, which is present and takes its own filters:

```sql
SELECT JOB_NAME, JOB_STATUS, JOB_SUBSYSTEM
  FROM TABLE(QSYS2.JOB_INFO(JOB_STATUS_FILTER => '*ACTIVE',
                            JOB_USER_FILTER   => 'SOMEUSER'));
```

Note the inversion before assuming a release ordering: `JOB_INFO` is the
*newer* function and it works, while the older `ACTIVE_JOB_INFO` is missing.
PTF-group level, not release, decides what is on this box — so settle it with
one query rather than by reasoning about what 7.3 shipped:

```sql
SELECT ROUTINE_NAME FROM QSYS2.SYSROUTINES
 WHERE ROUTINE_NAME IN ('ACTIVE_JOB_INFO','JOB_INFO');
```

Also, independent of release:

- The column is **`SOURCE_FILE_MEMBER`**, not `SOURCE_MEMBER`.
- **Join on `SYSTEM_TABLE_SCHEMA`/`_NAME`/`_MEMBER`**, never the SQL-name
  columns — a library like `@20210312` gets a generated SQL name and silently
  fails to match.
- Compare **`LAST_SOURCE_UPDATE_TIMESTAMP`**, not `LAST_CHANGE_TIMESTAMP`, which
  moves on copy, reorganise, restore and replication apply.
- Sub-second fields are always zero; compile timestamps are second-grain.
  Truncate before comparing and expect ties.
- **Key everything library + file + member.** Member names repeat across source
  files in one library.

## Running SQL from a source member (`RUNSQLSTM`)

Three defaults conspire to make a working member fail with an error that points
at the wrong line. All three cost an afternoon on 2026-09-18.

- **`MARGINS` defaults to columns 1–80** and the rest of each record is dropped
  silently. Source files here are `SRCDTA CHAR(100)`, so an 84-character
  `INSERT INTO t (a, b, c)` loses `, c)` — and the parse error lands on the
  **next** record (`SQL0104 … token X was not valid`, naming a token that is
  fine). **Always pass `MARGINS(100)`**, or match the file's `SRCDTA` length.
- **`OUTPUT` defaults to `*NONE`.** Per-statement messages go **only to the
  listing**, never to the job log — the job log gets a bare `SQL9010 … command
  failed` and, via `QCMDEXC`, a useless `SQL0443`. **Always `OUTPUT(*PRINT)`.**
- **The listing spool is printed and deleted** by the writer (and is destroyed
  outright if the job ends abnormally). To read it, override first, in the same
  job: `OVRPRTF FILE(QSYSPRT) HOLD(*YES) OUTQ(QUSRSYS/QEZJOBLOG) OVRSCOPE(*JOB)`
  — **`OVRSCOPE(*JOB)` is required**, because each `QSYS2.QCMDEXC` call runs at
  its own call level and a default-scoped override is gone by the next one.
  The listing lands in `<profile>/QPRTJOB` named after the member, not the
  running job; find it with `QSYS2.SPOOLED_FILE_INFO` and read it with
  `SYSTOOLS.SPOOLED_FILE_DATA`. Errors are the last few records, under a
  `MSG ID  SEV  RECORD  TEXT` header.

**Do not "fix" this by raising `ERRLVL`.** `ERRLVL(30)` makes the command
succeed by tolerating genuine SQL errors, so statements are skipped and the run
looks complete. Keep `ERRLVL(20)` and read the listing.

`sql400` runs every `;`-separated statement on **one connection**, so a
`CALL QSYS2.QCMDEXC(...)` and a follow-up `QSYS2.JOBLOG_INFO('*')` or
`SPOOLED_FILE_INFO` in the same invocation see the same job. It keeps going
after a failed statement (printing `!! [SQLnnnn] …` to stderr) and exits 1.

## Authority collection (`STRAUTCOL`) on 7.3

The instrument behind any `*ALLOBJ` reduction. Four things that are not
obvious and each of which changes an answer:

- **`DETAIL` is the cost model, not a preference.** `*OBJJOB` puts the *job*
  in what counts as a unique instance, so the same person doing the same work
  in tomorrow's session is new rows — it grows with sessions and never
  plateaus. `*OBJINF` collects *"regardless of the job that accesses the
  object and regardless of the unique code paths within the job"*, so it
  converges on the user's working set and stops. **They only diverge after
  several sessions**, so a week of `*OBJJOB` data extrapolated to an estate
  is wrong in the expensive direction. Use `*OBJJOB` for a small sample where
  you need to know *which program* drove an access; `*OBJINF` for breadth.
- **Read `DETAILED_REQUIRED_AUTHORITY`, not `REQUIRED_AUTHORITY`.** The latter
  was blank on 302 of the first 349 rows measured — it only carries the coarse
  `*USE`/`*ALL` cases. The former is populated on every row.
- **`AUTHORITY_SOURCE` is useless while `*ALLOBJ` is in play** — it read
  `GROUP *ALLOBJ` on 343 of 349 rows. `*ALLOBJ` satisfies the check before
  object authority is consulted, which is also why you cannot test a proposed
  group by running it alongside an `*ALLOBJ` one.
- **`STRAUTCOL` has a `DLTCOL` parameter that deletes the repository.** Any
  program that re-runs `STRAUTCOL` must pass `DLTCOL(*NO)` explicitly.

**The repository is volatile and this is the part people miss.** IBM (7.3
Security Reference Ch.10): collection data *"is not immediately written out to
disk"* for performance, so damage *"can frequently occur in the case of an
abnormal IPL"* — and recovery is `DLTAUTCOL` and start over. A collection
spanning a month-end is a month of evidence in a store nothing saves. IBM's
own remedy, from *Delete authority collection repository*: *"write data to a
DB2 table using view support."* Copy it forward on a schedule. That also buys
the only disk lever the feature has — once rows are held elsewhere,
`DLTAUTCOL` frees the live repository per profile.

`PATH_NAME` is `DBCLOB(16M)`; cast it down before copying it anywhere.

## Anything permanent you create must be in MIMIX **and** in the backup

**Standing rule (Doug, 2026-09-19).** The moment a project creates something on
this estate that is meant to outlive the session — a library, a table, a
program, a source member, a scheduled job, an output queue — it has **two**
homes it must be entered into, and they protect against different losses:

| | Protects against | Loses what if missing |
|---|---|---|
| **MIMIX** | the partitions swapping roles, or the primary being lost | the object simply is not there after a swap, and nothing says so — the job stops running and the data stops arriving |
| **Backup** | deletion, corruption, and time | no way back to yesterday, and on this estate no way back at all |

**Neither is a substitute for the other, and assuming either one covers you is
the mistake.** Replication copies the current state, including a deletion; a
backup does not follow a role swap. A monitoring table that exists only on the
primary is gone the day the roles change, and one that is replicated but never
saved is gone the day someone drops it.

**Every project keeps a register of what it has created**, and each entry
carries the *verified* status of both — not the intended status. Worked
example: `proj-security/docs/permanent-objects.md`. The register is checked at
housekeeping (the `housekeeping` skill) and the two columns start as **"not
verified"**, because an object nobody has confirmed is covered is an object
that is not covered.

**Two things that are easy to forget are on the list:**

- **Scheduled jobs are objects too.** A Robot job definition lives in the
  scheduler's own library. If that library is not replicated, the programs
  survive a role swap and nothing runs them.
- **The user profile the work runs as.** A replicated program owned by a
  profile that did not come across authenticates as nobody.

**Verify, do not assume.** Ask what the replication actually carries
(`proj-as400-codemap` has measured parts of this) and what the backup control
groups actually include — on this estate a library holding a year of security
evidence was discovered to be in neither, and the audit journal receivers had
**never** been saved in the machine's entire history.

## Reading a journal, and the defect that has now bitten twice

**`DISPLAY_JOURNAL` reads only the ATTACHED receiver unless you tell it
otherwise.** Pass `STARTING_RECEIVER_NAME => '*CURCHAIN'` to walk the chain.

**Why it is so dangerous: the wrong answer is a clean, instant zero.** A
`STARTING_TIMESTAMP` older than the attached receiver returns no rows, no
warning and no error, in about a second. It does not look like a failed query —
it looks like a confident negative, and it will be believed. It produced a
"75 spooled-file events in a week" finding that was really ~46,000 a day, and a
"2-day journal window" that was really 50 days. **Two projects, the same bug,
the same day.**

**Sanity-check any journal result that comes back empty or surprisingly small**
by re-running it with `*CURCHAIN` and comparing. If the two differ, the chain
is the truth.

### Who manages, deletes and reads the audit journal

**MIMIX deletes `QSYS/QAUDJRN`'s receivers.** `MIMIXOWN`, job `JRNMGR`,
program `MIMIX/LVSRV03` — found in the audit journal's own `DO` entries. So
audit retention on this estate is a **MIMIX journal-manager setting** with an
administrator (Midrange), not a mystery program. Note the oddity: MIMIX manages
those receivers but does **not** replicate the journal, so it is deleting a
trail it does not copy anywhere.

**To find out whether anything CONSUMES an audit journal, look for `QASY*`
outfiles.** `CPYAUDJRNE` and `DSPJRN OUTFILE` write into model outfiles named
`QASYxxJ5`; their presence anywhere outside `QSYS` is the fingerprint of
somebody extracting audit data. An estate-wide scan of user libraries found
**zero** (2026-09-19), which alongside "no scheduled job reads it" and "no
remote journal" is strong evidence nothing does.

**What that evidence cannot cover**, and should be said whenever it is cited: a
program can read entries through the journal API (`RCVJRNE`,
`QjoRetrieveJournalEntries`) without ever creating an outfile. Ruling that out
needs the program reference graph, which `proj-as400-codemap` holds.

### What the reads actually cost

Measured on `QSYS/QAUDJRN`, whole chain, 2026-09-19:

| Query | Rows | Time |
|---|---|---|
| No entry-type filter, 1-hour window | 915,202 | 38 s |
| `JOURNAL_ENTRY_TYPES => 'SF'`, 1-hour window | 1,009 | 1 s |
| `JOURNAL_ENTRY_TYPES => 'SF'`, **2-day** window | 87,974 | **178 s** |

Two conclusions, and the second is the one that sizes a job:

- **The entry-type filter is pushed down and is nearly free** — same window,
  38× faster. Filter in the table function's parameter, **never** in a `WHERE`
  clause over an unfiltered read.
- **Cost is driven by the WINDOW, not by rows returned.** Same filter, 48× the
  window, 178× the time — superlinear, because each extra receiver is another
  walk. So a harvester should keep its window as short as it can get away with,
  which is an argument for running often rather than catching up in bulk.

### Harvesting a journal forward — the pattern, not a library

Both `proj-security` and `proj-as400-codemap` harvest journals into tables.
Different journals, different entry types, different authority — **same five
mechanics**, and copying them is correct here; there are two callers, which is
where you copy rather than abstract:

1. **Deduplicate on the journal sequence number**, not on content. That single
   choice makes everything below safe.
2. **Derive the lookback from the newest row already held**, minus a small
   overlap — never a fixed interval. A missed run then heals itself on the next
   run with nobody involved. Floor it at the receiver retention window; asking
   for more scans for nothing.
3. **One entry type (or object) per member/statement.** `RUNSQLSTM` stops at
   the first failure, so a mixed member means one broken type costs the rest —
   and journal evidence is destroyed on a clock, so it cannot be collected
   later.
4. **Record the gap before each run** — how far behind you were. Roughly one
   interval means the last run worked; more means the system healed something,
   which is the only way to see a recurring problem that keeps self-correcting.
5. **Never read silence as health.** *Reached it and found nothing* and *could
   not reach it* must be different outcomes in whatever you record.

Worked implementation: `proj-security/secaudit/src/qsqlsrc/EV*.sql` plus
`SECEVTS.clle`.

## Costs, measured

- Estate-wide `*PGM` scan: ~25 s (target), ~90 s (primary).
- Estate-wide all-object-type scan: **~11 minutes** — put it on the target.
- Estate-wide member scan (`SYSPARTITIONSTAT`): ~2 minutes. Drive it library at
  a time.
- `DSPPGMREF` over a 4,400-program library: **~1 second.** The whole reference
  graph is minutes, not hours.
- Reading source members one at a time: ~1.7 s each via a JVM-per-member helper.
  Do not loop it over thousands.
- **`HISTORY_LOG_INFO` over 4 days: ~12 minutes even filtered to six message IDs.**
  The log runs ~1.4M messages/day, and the filter is applied after retrieval.
  Always pass `START_TIME`/`END_TIME`, keep the window hours not days, and expect
  it to be slow anyway.
- `DISPLAY_JOURNAL` for one file over 6 hours: **under a second.** Cheap — but see
  the attribution trap below.

## Blind spots that make confident answers wrong

- **Anything you create may be owned by a group, not by you — and that quietly
  undoes the authority you just set.** If the creating profile has
  `OWNER(*GRPPRF)`, new objects are owned by its **primary group**, and an owner
  entry carries `*ALL` to every member of it. A library created
  `AUT(*EXCLUDE) CRTAUT(*EXCLUDE)` on purpose was found owned by an 86-member
  group, handing all of them full authority to its contents. Check after
  creating anything:

  ```sql
  SELECT OBJNAME, OBJTYPE, OBJOWNER
    FROM TABLE(QSYS2.OBJECT_STATISTICS('<lib>','*ALL'))
   WHERE OBJOWNER <> '<the profile you expected>';
  ```

  Fix with `CHGOBJOWN … CUROWNAUT(*REVOKE)` — without `*REVOKE` the group keeps
  the authority as a private entry and nothing visibly changes.

- **An `*ALLUSR` sweep silently omits every library the profile cannot reach,
  and reports it as absence.** `QSYS2.OBJECT_STATISTICS('*ALLUSR', ...)`
  returns zero rows for an object that plainly exists, with **no error and no
  warning** — the job log carries a `CPF2182 Not authorized to library X` that
  the SQL result never mentions. Measured 2026-09-18: a sweep for `IMPSEID`
  came back empty and was reported as "does not exist anywhere on the box";
  it exists in `SEIOBJ` and `ZPETERP`, both `CPF2182` to `CCIMG`.
  **"Not found" from a sweep means "not found *where I can see*".** Say which
  libraries were excluded, or do not make a negative claim at all.
  The libraries still appear in `QSYS2.SYSSCHEMAS` — the catalog lists them
  while object access is refused, so schema visibility is not evidence of
  object visibility (`proj-security` ADR 0003 is the same distinction).
  Known refused to `CCIMG` so far: `SEIOBJ`, `ZPETERP`, `QRDARS`, `XTLBC`.
  Check the job log for `CPF2182` after any sweep that returns less than
  expected.

- **`*QRYDFN` — thousands of them, with no source at all.** Query/400 definitions
  are invisible to every source-driven approach, and they are scheduled in
  production (`RUNQRY` appears in the job schedule). Count them before claiming
  coverage.
- **`DSPPGMREF` cannot see** call targets held in variables (`*EXPR`), files
  reached through `OVRDBF`, runtime-built program names, `QCMDEXC` command
  strings, or dynamic SQL.
- **~23% of raw `DSPPGMREF` edges are IBM language runtime** (`QLEAWI`, `QRNX*`,
  `QCLSRV`, blank object type). Filter them or they dominate the graph.
- **`PROGRAM_INFO` carries source for OPM only.** ILE records it on the *module* —
  union `BOUND_MODULE_INFO` or you will report most of the estate as sourceless.
- **Embedded-SQL programs** record the precompiler's `QTEMP/QSQLTEMP1` member,
  which evaporated. Indistinguishable from lost source unless filtered.
- **Renamed source files.** A program library does *not* draw from one matching
  source library — one sampled library used ten. And a renamed source file made
  441 members look lost that were not. **Resolve renames by following the
  failures**; a name-pattern sweep (`%OLD`, `%BAK`) finds almost nothing.
- **Journal attribution is lost in replication.** Reading a journal on the
  *target* returns MIMIX's apply program (`DMAPPLY`/`ICC_DBAPYA`/`MIMIXOWN`), not
  the program that made the change. **Read journals on the `primary` for
  attribution** — the opposite of where you send expensive scans.

  **~~And the primary keeps only ~2 days of receivers.~~ THAT WAS WRONG AND IT
  WAS WRONG HERE, IN THIS FILE, FOR WEEKS.** The 2-day figure was the
  attached-receiver defect below, recorded as a fact. Measured properly:
  application journals (`#MXJRN`) hold **~50 days**; `QSYS/QAUDJRN` holds
  **~6.8 days**. **Two separate projects reached the same false conclusion
  independently on 2026-09-18, and both had read this line.** A wrong number in
  a shared skill does not mislead one session — it mislead everyone who trusts
  it, and it is the most expensive kind of error this file can contain.
- **`OBJATTRIBUTE = 'DFU'` means there is no source and never was.** DFU generates
  a program from an interactive definition. Alongside vendor products, the second
  explainable-absence class — and it is exactly the set with no recorded source
  library. Check the attribute before calling anything's source lost.
- **`SYSPARTITIONSTAT` silently hides what you cannot read.** This is the worst
  one, because it looks like data rather than a permission error. Objects the
  profile lacks authority to are **omitted with no error and no flag** — so
  "member absent" quietly means "absent *or* invisible to me". It produced a
  report that 1,435 production programs had lost their source when the source was
  simply behind an authority wall.

  **`OBJECT_STATISTICS` is the instrument that distinguishes them:** it returns
  an unauthorised object **with blank `OBJOWNER`, `OBJSIZE` and `OBJTEXT`**,
  while readable siblings show real values. Genuine absence is the object not
  being returned at all.

  So resolve existence through `OBJECT_STATISTICS`, and classify **four** states,
  never three: readable · **present-but-unauthorised** · renamed · absent.

  **Refined 2026-09-19, because the sentence above over-promises.**
  `OBJECT_STATISTICS` distinguishes those four states **only for objects inside a
  library the profile can already enumerate.** If the whole *library* is out of
  reach, its objects do not come back blank — **they do not come back at all**,
  and the result is indistinguishable from absence.

  Worked case: `LVSRV03` writes a production file, and
  `OBJECT_STATISTICS('*ALLUSR','*ALL')` filtered to that name returned **zero
  rows on both boxes** — 226 s on one, 938 s on the other, ~19 minutes spent
  proving something false. It exists: it is `MIMIX/LVSRV03`, and the MIMIX
  libraries are invisible to that profile.

  **So `*ALLUSR` enumeration is itself authority-filtered**, and the rule
  generalises to every catalog view here — `SYSPARTITIONSTAT`, `USER_INFO`,
  `OBJECT_STATISTICS` and `BOUND_SRVPGM_INFO` are four for four.
  **Never report "does not exist" from a catalog view.** Report "not visible to
  this profile", name the profile, and prefer an instrument that reports
  *activity* over one that reports *existence* — the journal named `LVSRV03` in
  four seconds after the catalog failed for nineteen minutes.

## `DSPPGMREF` cannot see service programs — `BOUND_SRVPGM_INFO` can

**A reference graph built with `DSPPGMREF ... OBJTYPE(*PGM)` has no `*SRVPGM`
edges in it at all.** That is not a small tail on this estate: the single
heaviest observed writer of the busiest business file is `SQ_LIST`, a `*SRVPGM`,
and it is absent from a 282,816-edge graph entirely.

**`QSYS2.BOUND_SRVPGM_INFO`** carries the ILE binding edges — which programs and
service programs are bound to which service program. 125,148 rows on this
estate. Use it whenever the question is *what calls X* and X might be a service
program, or when a clean negative from `DSPPGMREF` is about to be reported.

```sql
SELECT PROGRAM_LIBRARY, PROGRAM_NAME, OBJECT_TYPE
  FROM QSYS2.BOUND_SRVPGM_INFO
 WHERE BOUND_SERVICE_PROGRAM = 'QJOURNAL'
```

**Three limits, and they must travel with any answer from it:**

- **Binding is not calling.** A service program bundles many procedures; binding
  to it proves only that *something* in it is used.
- **Procedure-level imports are not available.**
  `QSYS2.PROGRAM_EXPORT_IMPORT_INFO` returns `*PROCEXP` for these objects and
  **never `*PROCIMP`** — tested 2026-09-19. You can see what a service program
  *exports*, which often names its purpose well enough to be useful, but you
  cannot see which procedure a caller imports.
- **It is authority-filtered** like everything else here. See above.

## Products on the estate

Check the box for versions rather than assuming; all three are behind current.

- **Robot/SCHEDULE** (Fortra) — the real job scheduler; IBM's own is near-empty,
  so `WRKJOBSCDE` tells you almost nothing. Its files are externally described
  *with field text*, so `SYSCOLUMNS` on the live library is a working data
  dictionary — better than the vendor's manuals, which describe a much newer
  release. Version is in data area `ROBOTLIB/RBTIVER`; find the live library
  from the running monitor job, not from the library name. (The `robot` skill
  is a *different* product — dk400's Celery scheduler. It does not apply here.)

  **Read the schedule from its own tables rather than trusting a note:**

  | Table | Holds |
  |---|---|
  | `ROBOTLIB.RBTROB` | the job master — name, `OS_JOB_USER`, job queue, job description, `SCHED_RUN_TIME_n`, `RUN_FLAG_MON`…`SUN`, `JOB_HAS_MONITOR` |
  | `ROBOTLIB.RBTCMD` | the commands, `CMD_STRING` + `CMD_ERROR_HANDLING` (2 = cancel, 1 = ignore) |
  | `ROBOTLIB.RBTJM` | per-job monitors — overrun, underrun, late-start, and the action for each |

  **`CMD_SET_OID` on `RBTROB` is 0 for almost every job** (746 of 747 measured),
  so it is *not* the join to `RBTCMD`. Do not join on it and conclude a job has
  no command.

  **Three defaults that are each one step from wrong**, and all three are worth
  checking on any job you add: Robot **submits as its own high-authority
  profile unless told otherwise** — on this estate that account holds every
  special authority and is unaudited, so always set the job's user explicitly;
  the default batch queue may be `MAXACT(1)`, so a long job blocks everything
  behind it — check `QSYS2.JOB_QUEUE_INFO` before choosing one; and a job with
  no monitor fails silently.

  **Spooled files are aged by a Robot job, not by the system** — a command set
  of `AGEOUTQ OUTQ(x) LIBR(y) AGELMT(<days>)` lines, one per queue. A new output
  queue accumulates forever until it is added to that list. Find it with:

  ```sql
  SELECT CMD_SET_OID, CMD_LINE_NUMBER, CMD_STRING FROM ROBOTLIB.RBTCMD
   WHERE UPPER(CMD_STRING) LIKE '%AGEOUTQ%' ORDER BY 1, 2;
  ```
- **MIMIX** — replication, and **you can read its configuration directly rather
  than asking the MSP.** Version: `QSYS2.SOFTWARE_PRODUCT_INFO` where
  `PRODUCT_ID = '7VSI001'` (Precisely Assure MIMIX; it was Lakeview, then
  Vision, then Syncsort, so search accordingly). Replicates object content,
  **not** usage statistics.

  **Where the answer to "does X replicate?" lives:**

  | File | Holds | Trust |
  |---|---|---|
  | `MIMIX.OMOBJXEP` | **Live** expanded object entries — `DG`, `LIB1SND`, `OBJ1SND`, `TYPE` | The current state |
  | `MIMIX.MXLIBREPP` | A generated **library report** — per-library included/excluded/partial | **Check its `CHANGE_TIMESTAMP` first.** One found in the wild was two months stale |

  **Two traps, both of which cost a query:**

  - **The name columns are CCSID 65535**, so a client prints them as
    EBCDIC hex (`ROBOTLIB` arrives as `D9D6C2D6E3D3C9C24040`). Comparisons
    against a literal still work; only the display is wrong. Read them with
    `CAST(LIB1SND AS CHAR(10) CCSID 37)`.
  - **The two sources can disagree**, and one real case did: the report marked
    a library's content all-included while the live object entries listed only
    its data areas and data queues. Whether an object entry can cover a whole
    library implicitly is a MIMIX semantics question — **do not conclude
    "not replicated" from an object-entry absence alone**, and say which file
    you read.
  Role swaps are why counters restart.
- **BRMS** — backup, and a possible route to *old versions of source*, which the
  box itself does not keep.

## Before you report a number

1. Which partition produced it, and does that matter for this claim?
2. Does it cover ILE as well as OPM?
3. Is a blind spot above excluded from it, and is that stated?
4. Can it be re-derived from a saved query rather than cited?

`docs/research/index.md` keeps an explicit list of figures that are **not**
measured. Add to it rather than quietly promoting an estimate.
