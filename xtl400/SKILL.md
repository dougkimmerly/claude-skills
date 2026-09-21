---
name: xtl400
description: "Work against XTL's real IBM i / AS/400 estate — the two-partition pair behind xtl400.xtl.com. Use for ANY query, extraction or diagnosis on XTL's 400: which box to talk to and why the answer changes, the read-only boundary and what QTEMP buys you, the release-7.3 SQL traps that reject valid-looking statements, and the blind spots that make a confident answer wrong. NOT dk400 (that is the `homelab-dk400` skill). Fortra Robot/SCHEDULE has its own skill, `robot-schedule` -- note that the `robot` skill is a third thing entirely (dk400's Celery scheduler) and never applies here. Consulted by proj-as400-codemap, proj-security, proj-imaging and kb-xtl400."
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
| **The `x400` tools themselves** | **`kb-xtl400/tools/x400/`** — canonical since 2026-09-20; `~/.local/bin` entries are symlinks to it |
| IBM i / RPG / CL platform reference | `kb-ibm400` (MCP-exposed) |
| Security posture, findings, the access wall | `proj-security` — **counts and pointers only** |

## Connecting

### ⚠ Everything to XTL rides Zscaler ZPA — and a port test LIES (2026-09-19)

XTL private hosts are published by **hostname**, not private IP, and resolve to
**ephemeral synthetic IPs in `100.64.0.0/16`** (`xtl400.xtl.com` → `100.64.1.1`,
`xtlto9.xtl.com` → `panda.xtl.com` → `100.64.1.3`, which moved from `.4`
mid-session). Consequences, each of which cost time:

- **A raw private IP never works.** `192.168.10.16` has no route; only the six
  hosts in the app segment resolve. Always use the `.xtl.com` name.
- **`nc -z host port` SUCCEEDS EVEN WHEN NOTHING IS THERE.** The local Zscaler
  tunnel accepts the connection itself, then the broker fails. **The tell is
  timing plus behaviour:** a real backend answers in ~0.18 s and *holds the
  connection or replies*; an unbrokered one "connects" in ~0.02 s and closes
  immediately with no data — and does so on *every* port you try, including ones
  the host could not possibly serve. Probe properly:
  ```python
  s = socket.create_connection((host, port), timeout=8); s.settimeout(4)
  s.sendall(b"\x00"); s.recv(64)     # replied / timeout(held) / closed-immediately
  ```
  Control case: `xtl400.xtl.com:23` returns telnet negotiation bytes; the Domino
  servers closed instantly on all seven ports tested — which is "no ZPA policy",
  not "server down". The servers were running the whole time.
- **Split DNS bites.** Both Zscaler (`100.64.0.1`) and the house Pi-hole
  (`192.168.20.16`) are configured resolvers with **no domain-scoped rule for
  `xtl.com`**, so the Pi-hole answers NXDOMAIN and whichever resolver a given app
  asks decides whether it works. Shell tools may succeed while an app fails.
- **Tailscale collides with all of this.** Tailscale's own CGNAT range is
  `100.64.0.0/10` — the same space ZPA mints synthetic IPs in — so bringing
  Tailscale up kills XTL sessions (it is what drops the 5250 connection and
  leaves ACS beeping every 20 s).

**The tools are version-controlled in `kb-xtl400/tools/x400/`** as of
2026-09-20, and `~/.local/bin/{x400,sql400,cl400,put400,src400,pgm400,ifsput}`
are **symlinks** into it — so editing either path edits the repo and nothing can
drift. Run `tools/x400/install.sh` on a new machine, `build.sh` after changing a
`.java`. Before that date they lived only in `~/.local` under no version control
and `Src400.java` was lost outright.

**Credentials come from SOPS, never a plaintext file, and the profile is a
per-project choice.** `x400 <profile> <command>` decrypts one profile out of
`homelab-secrets` `secrets/home/xtl400.sops.yaml` and exports
`XTL400_USER`/`XTL400_PASSWORD` for that command only. That file is scoped to
the **admin age key alone** — no unattended host decrypts an XTL production
credential. Use the `secrets` skill to add or rotate one.

```bash
x400 ccsec sql400 "SELECT ..."                    # proj-security, curlib DOUGSEC
x400 ccmap ./tools/q400 primary whoami            # proj-as400-codemap
x400 ccimg <cmd>                                  # proj-imaging
XTL400_HOST=192.168.40.20 x400 ccsec sql400 "..."  # the target; default is primary
```

**Pick the profile that matches the work.** `CCSEC` is proj-security's,
**`CCMAP` is the mapping project's**, `CCIMG` is proj-imaging's. They are
separate so that `QAUDJRN` attributes a read to the project that made it — a
shared profile destroys that, and on this estate the audit trail is itself
under review.

**This file said `CCIMG` was the mapping project's until 2026-09-19. It was
wrong**, and a session read production under the imaging project's identity
for three days because of it. Attribution is the whole point of separate
profiles; getting the mapping wrong in the shared skill defeated it silently.

**The tools used to hand you the wrong profile — fixed 2026-09-19, and the
lesson outlives the fix.** `sql400` with no credentials printed *"…e.g. `x400
ccsec sql400 ...`"* — `ccsec` regardless of which project you were in. A
proj-imaging session copied that example on 2026-09-19 and put **six**
production reads under proj-security's identity, the mirror of the mistake
above, on the same day and for a different reason. The message now names no
profile and points here instead (`X400Creds.java`; `x400 nosuch <cmd>` lists
the profiles that exist). **The example in an error message is an example, not
a recommendation** — and neither `x400` nor this skill should be the only copy
of the mapping. Decide the profile from the repo you are in, then type it.

**Whoever you connect as, you are inside the finding.** These profiles hold no
special authorities, but this box's `*PUBLIC` posture gives update or delete on
80,454 files — so a "read-only" session is read-only by *discipline*, not by
constraint. Never rely on the profile to stop a write. (proj-security #20.)

**And `LMTCPB(*YES)` is not the constraint its name implies.** Limited
capability governs an interactive **command line**; it does **not** stop
`CALL QSYS2.QCMDEXC('…')` over an SQL connection. Verified on this box
2026-09-19: `DSPPGMREF … OUTFILE(QTEMP/…)` runs fine as a profile with
`LMTCPB(*YES)`. **So for any ODBC/JDBC/SQL identity — which is what an
integration or an outside developer gets — limited capability is not a
containment boundary at all**, and it must not be cited as a mitigating
control for one.

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

**Backups run from the HA box, not the primary** (Doug, 2026-09-20). Saves are
taken off the MIMIX replica so production is never quiesced for them — which is
why a search for backup jobs in the primary's Robot schedule finds none, and why
an overnight job scheduled on the primary has no save window to work around.
(Beware `SAV*` job names there: they are **Savoie**, a division, not saves.)



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

**Finding which programs call a service program: use `BOUND_SRVPGM_INFO`, not
`PROGRAM_EXPORT_IMPORT_INFO`.** Asking the latter which programs import a
symbol returns **zero rows for `*PGM` objects on this box** — verified
2026-09-20 against a program known to call the symbol. It looks exactly like
"nothing calls this API", which on an estate where an uninstall depends on
that answer is a dangerous way to be wrong.

```sql
-- who depends on a vendor service program (the real question before an uninstall)
SELECT PROGRAM_LIBRARY, PROGRAM_NAME, OBJECT_TYPE, BOUND_SERVICE_PROGRAM
  FROM QSYS2.BOUND_SRVPGM_INFO
 WHERE BOUND_SERVICE_PROGRAM_LIBRARY = 'QVI';
```

Filter with `=` on the library, not `<>`: the negated form scans every program
object on the box and runs for minutes.

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

### ⚠ `SQL0443` from `DISPLAY_JOURNAL` means TWO OPPOSITE THINGS (2026-09-20)

The same code covers both, and only `MESSAGE_TEXT` separates them:

| Message text | What it is | Recovery |
|---|---|---|
| *"Not authorized to object X in LIB"* | an authority problem | a grant |
| *"STARTING_SEQUENCE OR ENDING_SEQUENCE NOT FOUND"* | your start position **aged out of the chain** | none — that evidence is gone at any price |

**Never read `-443` as an authority failure without reading the text.** Measured:
a collector reported `UNREACHABLE` on journal `DSN` **on the very day a `DSN`
authority grant had been revoked** — the predicted failure, in the predicted
shape, with an unrelated cause. The watermark was 155868 and the chain's oldest
surviving sequence had rolled to 155874; five entries aged out unread.

Two consequences for anything that reads journals incrementally:

- **Treat the aged-out case as its own outcome**, not as "unreachable". It
  means data loss and should be counted, because a rising count says the reader
  runs too seldom for that journal's retention.
- **Reseed to the oldest surviving sequence and carry on.** A reader that
  stalls on this loses the whole journal from then on, not just the gap.

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

  **⚠ CORRECTION, 2026-09-20: authority is only ONE of the reasons, and
  checking `CPF2182` will not catch the other.** An `*ALLUSR` sweep also omits
  libraries the profile CAN read, with no message anywhere. Measured on the
  primary as `CCMAP`: the sweep returned **20,084 objects across 54
  libraries**; the box holds **518** libraries and **221,349** objects. Queried
  directly, same profile, same minute, `I93CSTMNEW` returned 6,206 objects and
  `DOUGMAP` returned 2 — neither appeared in the sweep, and both are readable.
  The sweep reported a clean row count and no error.

  **So never use `*ALLUSR` for anything that must be complete. Enumerate
  libraries and loop, one query each:**

  ```sql
  SELECT OBJNAME FROM TABLE(QSYS2.OBJECT_STATISTICS('QSYS','*LIB','*ALL')) X
  ```
  (the third argument is required — omit it and you get one row, not 518)

  Then per library, and **record a coverage row per library as you go** —
  a capture that silently covers 10% of the estate is worse than none, because
  it gets quoted. Worked instance:
  `kb-xtl400/tools/capture_usage_counters.sh`.

  **⚠ And the coverage row needs THREE states, not two — 2026-09-20.** That
  worked instance recorded `ok` / `FAILED`, and put **a library that succeeded
  and returned zero rows** into `ok`. On this box zero rows means *empty* **or**
  *unauthorised*, and the capture cannot tell which from where it stands.
  **137 of 519 libraries on the primary** were carrying `0  ok`.

  It shipped a wrong claim: six libraries readable as `CCMAP` on the target and
  refused on the primary were quoted as *"1,495 programs the primary does not
  have… not part of what runs"*. The defensible figure was **87**. The guard
  rail built to stop a partial capture being quoted was itself reading silence
  as health.

  So: `ok` / `EMPTY-OR-BLOCKED` / `FAILED`, and resolve the middle state
  deliberately — an **unauthorised** library comes back from
  `OBJECT_STATISTICS('*ALLUSRAVL','*LIB')` with **blank `OBJOWNER`, `OBJTEXT`
  and `OBJSIZE`** while readable siblings show real values; a genuinely empty
  one shows real values. This is the same blank-attribute signature documented
  below for *objects* — **it applies to the library object itself too.**

  **A profile's reach differs BETWEEN the two partitions.** Those six libraries
  are readable as `CCMAP` on the target and refused on the primary, so the
  partition that *describes what runs* showed **less** of the estate than the
  replica did. Authority is per-partition, like the system values, and the diff
  is the finding. **Never carry a coverage claim from one partition to the
  other**, and when a capture is taken on the target for offload, say so — it
  may see more, not less.

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

  **You do not have to live with the filtered answer.** `proj-security` runs a
  `SECAUDIT` profile holding `*ALLOBJ` and has offered (2026-09-19) to re-run
  any authority-sensitive query on request — it costs them one query. Measured
  gap on a single `BOUND_SRVPGM_INFO` call for `QSYS/QJOURNAL`: **58 objects as
  `SECAUDIT` against 30 as `CCIMG`**, and the missing 28 were MIMIX and its
  vendor library `LAKEVIEW` — nearly half, all of it the machinery that
  mattered. **Ask rather than record a filtered result**, and when a coverage
  claim rests on what one profile could enumerate, say which profile.

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

## Db2 for i 7.3 SQL traps that cost a session each

All hit while installing real code on 2026-09-19. None is exotic; each looks
like valid SQL and fails only at CREATE time.

| Trap | Error | What to do instead |
|---|---|---|
| **`EXISTS` inside a `CASE WHEN`** | `SQL0104` | `LEFT JOIN` and test the joined column for `NULL`, or `SELECT COUNT(*) FROM (… FETCH FIRST 1 ROW ONLY)` |
| **A `GROUP BY` expression must match its `SELECT` expression textually** | `SQL0122` | Compute the expression in a CTE layer and group on the resulting column |
| **`ORDER BY` in a `CREATE VIEW`** | `SQL0199` | Leave it out; order in the query that reads the view |
| **`DROP … IF EXISTS`** | `SQL0199` | Not available. Run the drops tolerantly and ignore `SQL0204` |
| **`LABEL ON COLUMN` caps at 60 characters**, `LABEL ON TABLE` at 50 | `SQL0107` | `COMMENT ON` allows 2000, and is what column documentation *is* |
| **`STARTING_SEQUENCE => 0` or `1`** on `DISPLAY_JOURNAL` | `SQL0443` | Seed from `JOURNAL_RECEIVER_INFO`'s `MIN(FIRST_SEQUENCE_NUMBER)`; the chain's first sequence is not 1 |
| **A routine calling `DISPLAY_JOURNAL` without `MODIFIES SQL DATA`** | `SQL0577` | `DISPLAY_JOURNAL` is itself `MODIFIES SQL DATA`; the default `READS SQL DATA` may not call it. The message says *"Modifying SQL data not permitted"*, which reads like an authority or read-only violation and is neither |
| **Statements separated by `;` in a file fed to `install400`** | `SQL0104` | It splits on a line containing `@@` and does not strip trailing semicolons — routine bodies have their own |

**And the one that is not a dialect trap but bit hardest:** widening a column
does **not** widen the expression that fills it. A `CAST(… AS CHAR(10))` left
in a procedure kept truncating after the column became `VARCHAR(40)`, and the
data looked plausible — `030673/MIM` — rather than wrong.

## Killing a JDBC client does NOT stop the work on the box

Proven twice on 2026-09-19. A long `DISPLAY_JOURNAL` kept reading server-side
after the client process was killed — no client, no connection, still burning
CPU. The first time it was only discovered because an unrelated `ALTER TABLE`
came back `SQL0913` *"object in use"*.

**Finding the survivor is harder than it should be, and the obvious check
lies.** JDBC server jobs are `QZDASOINIT` running under **`QUSER`**; only the
*current* user swaps to your profile. So:

- `WRKUSRJOB USER(<yourprofile>) STATUS(*ACTIVE)` shows **nothing** — a clean,
  confident, wrong answer.
- `QSYS2.JOB_INFO(JOB_STATUS_FILTER => '*ACTIVE')` returned **zero rows total**
  for an ordinary profile — it could not see the job asking the question.
- What actually works: **`WRKOBJLCK OBJ(<lib>/<file>) OBJTYPE(*FILE)`** naming a
  file the job touches (check member locks too), or `WRKACTJOB JOB(QZDASOINIT)`
  and look for one burning CPU. Both need a profile that can see other jobs.

**Before starting anything long, know how you will stop it.** Ending it needs
`ENDJOB` from someone with the authority — not the profile that started it.

## Sizing a journal read BEFORE you run it

`JOURNAL_RECEIVER_INFO` answers "how much is there" for free, without touching
a single entry. Do this first; it is the difference between a 15-minute runaway
and a decision:

```sql
SELECT JOURNAL_NAME, COUNT(*) AS RCVS,
       MIN(FIRST_SEQUENCE_NUMBER) AS CHAIN_START,
       MAX(LAST_SEQUENCE_NUMBER)  AS NEWEST,
       MAX(CASE WHEN ATTACH_TIMESTAMP <= CURRENT TIMESTAMP - 24 HOURS
                THEN FIRST_SEQUENCE_NUMBER END) AS SEED_24H
  FROM QSYS2.JOURNAL_RECEIVER_INFO
 WHERE JOURNAL_LIBRARY = '#MXJRN' AND STATUS IN ('ONLINE','ATTACHED')
 GROUP BY JOURNAL_NAME
```

Measured 2026-09-19 on `#MXJRN`, and the numbers are why this matters:
**`APP` holds ~216 million entries in its chain and `ICC` ~348 million.** A
read from the chain start is not a query, it is a bulk job. Bounding to the
newest receiver attached before a cutoff gives roughly a 22–50× reduction and
costs one catalog query.

Sequence numbers are a magnitude, not an exact count (gaps exist), which is
plenty for deciding whether to run something.

## Adopted authority: how to reach an object your profile may not touch

**Verified on the box 2026-09-19**, not taken from a manual. When a profile
needs authority it should not hold standing — the canonical case being
`*OBJEXIST` on a journal, which also permits `DLTJRN` — the route is a routine
owned by a profile that *does* hold it, created `USRPRF(*OWNER)`:

```sql
CREATE OR REPLACE FUNCTION MYLIB.READIT () RETURNS VARCHAR(80)
  LANGUAGE SQL MODIFIES SQL DATA
  SET OPTION USRPRF = *OWNER, DYNUSRPRF = *OWNER
BEGIN … END
```

**`SESSION_USER` vs `CURRENT_USER` is the on-box tell for whether adoption
engaged**, and it is the thing most likely to be misread. Outside a routine
both are the connected profile. Inside an adopting one, **`SESSION_USER` stays
the caller and `CURRENT_USER` becomes the owner** — so `CURRENT_USER` showing
someone else is success, not a wrong connection. Return both when testing.

- **It works for a REMOTE caller.** A JDBC session calling an on-box routine
  adopts correctly, because it is the *routine's program object* that must be in
  the call stack, not the caller. Only a remote session issuing the privileged
  statement **directly** adopts nothing.
- **`DYNUSRPRF(*OWNER)` is NOT required for a table-function reference.**
  Measured: `USRPRF` alone read an otherwise-refused journal. A host variable
  for the journal name does **not** make the statement dynamic — `DYNUSRPRF`
  matters only for `PREPARE`/`EXECUTE IMMEDIATE`. Set it anyway so a later
  maintainer adding a dynamic statement does not silently lose adoption.
- **Prove it with an object whose two outcomes cannot be confused.** The test
  above used an *empty* journal on purpose: **0 rows is the authorised answer
  and `SQL0443` the unauthorised one.** A populated one confounds *authorised*
  with *found something*. Establish the direct refusal immediately before, as
  the control — authority on this box changes under you.

**Why prefer adoption to a standing grant here, given `*PUBLIC` already gives
update or delete on 80,454 files?** Not because it is safer today — it isn't.
Because it is **measurable**: Authority Collection records
`ADOPT_AUTHORITY_USED`, `ADOPTING_PROGRAM_NAME` and `ADOPTING_PROGRAM_OWNER`, so
an adopting program is visible evidence, while a standing grant on a profile
looks like every other grant on a box where everything is granted. And a profile
that must be **submittable** carries its authority into any job run under it;
an owner profile that is never a job identity does not. (proj-security's ruling,
2026-09-19.)

### Maintaining an adopting object: the part that surprises people

- **`CREATE OR REPLACE` resets the owner to whoever runs it**, and the object
  then silently stops adopting — every call comes back `SQL0443`, which reads
  as an authority problem rather than a deployment one. **After any redeploy,
  check the owner**, don't assume it.
- **⚠ You cannot delegate the hand-back by adoption. It is not policy, it is
  the machine:** *"You must be signed on as a user with `*ALLOBJ` and
  `*SECADM` special authorities to transfer ownership of an object that adopts
  authority"* — SC41-5302 7.3 Security Reference, printed p.153; `CHGOBJOWN`'s
  own Appendix D footnote agrees. So a "promote my program" tool that others
  call **cannot exist as an adopting program**. A promotion service has to be
  *request and execute*: the requester stages, a privileged identity performs.
- **There is a window in every redeploy where the object adopts the
  PROMOTER.** Between the compile and the hand-back it is owned by whoever ran
  it — typically an `*ALLOBJ` holder. If the runtime profile can call it in
  that window, that is arbitrary code at `*ALLOBJ`, **and nothing looks wrong**.
  Revoke *before* transferring, grant *after*, and fail closed on every error
  path. Worked instance: `proj-as400-codemap` `mapcoll/src/qclsrc/MAPPROM.clle`
  + ADR 0014.
- **Owning the library confers nothing over the objects in it** (7.3 Security
  Reference, printed p.137) — which is what lets a control program live in a
  library owned by a less-privileged profile while staying out of its reach.

## Reading the system history log: group on the bare job name

`QSYS2.HISTORY_LOG_INFO`'s `FROM_JOB` is **fully qualified** —
`030673/MIMIXOWN/WMS_OBJRTV` — and the leading number is unique per job
instance. Grouping on it does not aggregate: measured 2026-09-19, **77 message
identifiers became 77,560 distinct "jobs" and 178,761 rows.** Grouping on the
bare name gave **3,595**, a 50× reduction.

```sql
SUBSTR(H.FROM_JOB, LOCATE_IN_STRING(H.FROM_JOB, '/', -1) + 1)
```

Cost, measured: **26 hours of history ≈ 145 s.** It is the expensive read on
this estate and has no sequence number to position on, so read a short window
often rather than a wide one rarely.

## Robot's tables are not shaped the way their names suggest

**→ Fortra Robot/SCHEDULE now has its own skill: `robot-schedule`.** Load it for
anything about the schedule itself. What stays here is only what bites a general
SQL session against this box.

- **`RBTMSG` is a MESSAGE table, not a run table.** Up to **26 rows** share one
  `(CMRNAM, CMRJOB, CMSDAT, CMSTIM)`. Treating a row as a run violates any
  primary key built on that tuple — `SQL0803`. Aggregate to the run.
- **`CMRJOB` is blank for some jobs**, so that tuple does not always identify a
  run. Run counts for those jobs are unreliable and this is unresolved.
- **Dates are `CYYMMDD` as a 7-digit number** (`1260914` = 2026-09-14, leading
  digit is the century) and times are `HHMMSS` with no leading zero (`60500` =
  06:05:00). **`DATE(CMSDAT)` does not parse this** and does not fail usefully.
- **`CMMSEV` is `A(1)`** and holds letters (`C`, `W`, `T`), not a number.
  **`CMRJOB` is `A(12)`**, zero-padded, not an integer.
- **`QSYS2.ACTIVE_JOB_INFO` does not exist on this 7.3** (`SQL0204`). Use
  `QSYS2.JOB_INFO`.
- **`RBTROB.HIST_RETENTION` is per job.** Verified against stored data: for
  retentions 3, 7, 12, 14 and 30 the stored runs match exactly; for 6 and 40 —
  the two big populations — they do not, and why is unresolved.

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

  **`OS_JOB_USER` is `*RBTDFT` on 667 of 747 jobs, and `*RBTDFT` IS NOT A
  PROFILE — do not look it up, resolve it.** Measured 2026-09-20. The
  `RBTDFT` file in `ROBOTLIB` is empty, so the default is not readable there.
  **Resolve it empirically through the submitter chain**, which is the only
  route that worked:

  ```sql
  SELECT SUBSTR(SUBMITTER_JOB_NAME, LOCATE_IN_STRING(SUBMITTER_JOB_NAME,'/',-1)+1) AS SUBMITTER,
         JOB_USER AS RUNS_AS, COUNT(*) AS JOBS
    FROM TABLE(QSYS2.JOB_INFO(JOB_STATUS_FILTER=>'*ALL', JOB_USER_FILTER=>'*ALL'))
   WHERE SUBMITTER_JOB_NAME LIKE '%RBTUSER%' OR SUBMITTER_JOB_NAME LIKE '%SCHEDULE%'
   GROUP BY 1, 2 ORDER BY 3 DESC
  ```

  **Do NOT match Robot job names against active job names** — job names collide
  with ordinary interactive jobs and the answer looks plausible and is wrong.
  That was tried first and produced a completely different set of users.

  **CORRECTION 2026-09-20 — this skill said Robot "submits as its own
  high-authority profile… that account holds every special authority".
  Measured on XTL, that is wrong in both halves.** `RBTUSER` runs the Robot
  *monitors* (`RBCMANAGER`, `RBCREPLY`, …) and holds `*JOBCTL *SAVSYS
  *IOSYSCFG` — **not** all eight, and not `*ALLOBJ`. The *scheduled work*
  resolves to **`QPGMR`** (2,337 jobs) and **`SCHEDULE`** (~1,550), and it is
  `SCHEDULE` that holds all eight. So there are **two** Robot identities doing
  different things, and naming the wrong one gets the authority story
  backwards. Check before asserting — and note `SCHEDULE` is `*DISABLED` and
  running jobs right now, which is its own finding.

  **Two remaining defaults worth checking on any job you add:** the default
  batch queue may be `MAXACT(1)`, so a long job blocks everything behind it —
  check `QSYS2.JOB_QUEUE_INFO` before choosing one; and a job with no monitor
  fails silently.

  **Six `ROBOT*` libraries exist and only one is live.** `ROBOTLIB` (747 jobs,
  updated continuously) is current; `ROBOTLIBV8`, `ROBOTLIBV9`, `ROBOTMRGV8`,
  `ROBOTMRGV9` and `ROBOTMSTV3` all froze on **2024-12-10** and are migration
  snapshots. Settle it with row counts and timestamps rather than the name:

  ```sql
  SELECT TABLE_SCHEMA, TABLE_NAME, NUMBER_ROWS, LAST_CHANGE_TIMESTAMP
    FROM QSYS2.SYSTABLESTAT
   WHERE TABLE_NAME IN ('RBTROB','RBTCMD') AND TABLE_SCHEMA LIKE 'ROBOT%'
  ```

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

  **The vendor documentation is public — read it, don't ask.** Precisely serves
  the full Assure MIMIX 10.0 set at `help.precisely.com` with no login:
  Operations Guide, Administrator Reference, Monitor Reference, Installation
  Wizard, Release Notes. `kb-xtl400/knowledge/mimix-v10-doc-index.md` maps every
  guide, its chapters and the URL pattern, and is in the `kb-xtl400-docs` RAG —
  query it, then fetch the page. **Do not copy the pages into any corpus**;
  Precisely's terms allow indices, not caches (`kb-xtl400` ADR-0001). Two traps
  if you go looking yourself: their `sitemap.xml` and catalogue API advertise
  **only the Release Notes**, which is how the estate wrongly concluded the
  Administrator Reference was behind a customer login; and the site returns HTTP
  200 with an identical shell for every path, so `curl` cannot test whether a
  page exists.

  **Where the answer to "does X replicate?" lives:**

  | File | Holds | Trust |
  |---|---|---|
  | `MIMIX.OMOBJXEP` | **Object TRACKING state — not the configuration.** Its `TYPE` can only ever be `*DTAARA` or `*DTAQ` | **Do NOT read replication scope from this.** See the correction below |
  | `MIMIX.MXLIBREPP` | A generated **library report** — per-library included/excluded/partial | Check its `CHANGE_TIMESTAMP`; one found in the wild was two months stale |
  | `WRKDGOBJE … OUTPUT(*OUTFILE) EXPAND(*NO)` | **The actual rules.** `EXPAND(*YES)` gives a point-in-time list of matching objects instead | The only authoritative source — **but see the authority note** |

  **A correction, recorded because getting this wrong is easy and I did.**
  `OMOBJXEP` is the *expanded entry state* file and **contains only data areas
  and data queues by definition** — those are the object types routed through
  the user journal under advanced journaling. Reading it and concluding "only
  data areas replicate for this library" is wrong twice over: everything else
  in the library is still replicated **via the system journal**, and
  system-journal objects never get tracking entries at all. Equally, a library
  having **zero** rows there means nothing about whether it replicates.

  **A single object entry can cover a whole library** — `LIB1(X) OBJ1(*ALL)` is
  the documented normal case — so objects replicate **without appearing
  individually anywhere**. And precedence is *most-specific-match, not
  accumulation*, so one narrow `PRCTYPE(*EXCLD)` entry can silently carve
  objects out of a broad include. *(MIMIX Reference v6.0, "Identifying
  library-based objects for replication" and "How MIMIX uses object entries to
  evaluate journal entries for replication".)*

  **`*ALLOBJ` does not get you MIMIX commands.** MIMIX enforces its own
  product-level authority: `WRKDGOBJE` fails with
  `LVE100C — Product-level security error 1 … in product H1` even for a profile
  holding `*ALLOBJ *SECADM *AUDIT`. So the authoritative answer to "does X
  replicate?" has to come from someone enrolled in MIMIX security — on this
  estate, the MSP. Ask for `WRKDGOBJE EXPAND(*NO)` output **and every
  `PRCTYPE(*EXCLD)` row**, not for a yes/no.

  **For database files, an object entry is necessary but not sufficient** —
  matching *file* entries must exist too, and the product's own `#DGFE` audit
  (`WRKAUD RULE(#DGFE)`) is what proves it. A disaster-recovery assurance claim
  should rest on that audit, not on reading either file above.

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

## More 7.3 column and view traps, measured 2026-09-20

Adding to the list above rather than replacing it — each cost a query.

| Thing | Reality on XTL 7.3 |
|---|---|
| `QSYS2.AUTHORITY_COLLECTION_INFO` | **Does not exist.** Check what is collecting by joining `AUTHORITY_COLLECTION_ACTIVE` on `QSYS2.USER_INFO` instead |
| `JOB_INFO`'s user column | **`JOB_USER`**, not `AUTHORIZATION_NAME` (`SQL0206`) |
| `JOB_DESCRIPTION_INFO`'s `USER` parameter | exposed as **`AUTHORIZATION_NAME`** — the JOBD's run-as identity, and a second identity route behind any scheduler |
| `USER_INFO.PASSWORD_EXPIRATION_INTERVAL` | **`0` means inherit `QPWDEXPITV`** (45 on this box), **`-1` means never expires.** `0` reads like "never" and is the opposite. The `-1` reading is inferred, not manual-verified |
| `QSYS2.SYSPARMS` for a table function's result columns | returns nothing useful — get the column list with `SELECT * FROM TABLE(...) FETCH FIRST 1 ROW ONLY` and read the header |

**`PROGRAM_INFO` estate-wide is a job, not a query — and the two partitions
disagree.** `WHERE USER_PROFILE = '*OWNER'` over the whole estate took **>9
minutes on the primary** and **~1 minute on the target**. Tempting to just use
the target; **do not, for anything you will quote about production.** Measured
the same day: `MIMIXOWN` 472 on the primary against 897 on the target,
`LAKEVIEW` 77 vs 132, `QBRMS` 677 vs 477 — a ~35% difference in the total. Some
is MIMIX apply-side machinery that only exists on the target; the rest is
unexplained. **The adoption surface does not transfer between partitions.**

**A multi-row `INSERT` here is not atomic in practice.** A four-row insert that
hit a duplicate key on the third row left the first one committed. Check what
landed before retrying, or you will chase a phantom.

## Compiling on the box, and reading your own errors (2026-09-20)

**You can only read your OWN spooled files, and the failure is silent.**
`SYSTOOLS.SPOOLED_FILE_DATA` against another user's compile listing returns
**zero rows** — not an error, not a refusal. So "the compile failed, send me
the errors" cannot be answered by reading their listing.

**The fix is not more authority — compile a test copy as yourself:**

```sql
CALL QSYS2.QCMDEXC('CRTCLPGM PGM(<yourlib>/<name>T) SRCFILE(<lib>/QCLSRC)
                    SRCMBR(<name>) AUT(*EXCLUDE) TEXT(''TEST COMPILE'')')
```

then find and read your listing:

```sql
SELECT SPOOLED_FILE_NAME, JOB_NAME, FILE_NUMBER, CREATE_TIMESTAMP
  FROM QSYS2.OUTPUT_QUEUE_ENTRIES_BASIC
 WHERE USER_NAME = '<you>' ORDER BY CREATE_TIMESTAMP DESC FETCH FIRST 5 ROWS ONLY;

SELECT ORDINAL_POSITION, CAST(SPOOLED_DATA AS VARCHAR(110))
  FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(JOB_NAME => '<job>',
             SPOOLED_FILE_NAME => '<name>', SPOOLED_FILE_NUMBER => <n>))
 WHERE SPOOLED_DATA LIKE '%CPD%' OR SPOOLED_DATA LIKE '%Message Summary%';
```

Iterate until clean, then hand the real command to whoever owns the target
library. **The session proves the source; the person performs the privileged
act** — and a privileged compile is then never the thing being debugged.

### CL traps this cost a compile each

- **`SNDPGMMSG … MSGTYPE(*ESCAPE)` with free text does not compile** —
  `CPD2489 "MSGID parameter is needed"`. Immediate messages cannot be escape
  messages. Use `MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA(&MSG)`, and **keep `&MSG`
  at 132** — `CPF9898`'s data is cut silently past that. `*COMP`, `*DIAG` and
  `*INFO` take free text fine.
- **`GRTOBJAUT` will not mix a system-defined authority with specific ones.**
  `AUT(*CHANGE *OBJMGT)` fails; it takes two commands.
- **`ADDPFM` needs `*OBJMGT` on the source file** — `*CHANGE` is not enough,
  and the failure is a bare `CPF7306 "not added … because of errors"`.

### Getting source onto the box without SEU

- **`QSYS2.IFS_WRITE` exists on 7.3** — `(PATH_NAME, LINE, FILE_CCSID,
  OVERWRITE => 'REPLACE'|'APPEND'|'NONE', END_OF_LINE => 'LF')`. Needs `*WX` on
  the parent directory and `*W` on the file. One call per line is slow but
  fails on a line number you can look at.
- **`CRTBNDCL` accepts `SRCSTMF`**, so CL can be compiled straight from the
  IFS with no source physical file at all.
- **A source member is SQL-addressable** through an alias:
  `CREATE ALIAS lib.X FOR lib.QCLSRC(MBR)`, then `INSERT`. Watch the source
  width (`RCDLEN 112` → 100 chars of data) and treat an over-long line as an
  error, never a truncation.
- **UTF-8 narrows to EBCDIC on the way in.** Byte counts will differ; compare
  **character** counts per line instead. Check for non-ASCII inside string
  literals before staging — in comments it is harmless, in a literal it is not.
- **Strip your own statement separators.** `@@` is a convention for feeding
  several statements over JDBC; `RUNSQLSTM` separates on semicolons and reads a
  bare `@@` as a syntax error.

## Reading a user's containment: it is FOUR attributes, never one

Measured 2026-09-20 on XTL. **`LMTCPB` alone tells you almost nothing** —
whether a signed-on user can reach a command line is decided by four
`QSYS2.USER_INFO` columns together:

| Column | What it decides |
|---|---|
| `INITIAL_PROGRAM_NAME` / `..._LIBRARY_NAME` | What runs at sign-on — **and the library matters**, see below |
| `INITIAL_MENU_NAME` | What happens when that program **ends**. `*SIGNOFF` ends the session and is genuine containment; `MAIN` drops them on IBM's main menu |
| `LIMIT_CAPABILITIES` | Whether a command line, once reached, accepts anything beyond `ALWLMTUSR(*YES)` commands |
| `ATTENTION_KEY_HANDLING_PROGRAM_NAME` | **The escape route everyone forgets.** `*SYSVAL` inherits `QATNPGM` |

**The trap that caught XTL: `ATNPGM(*SYSVAL)` with `QATNPGM = QEZMAIN QSYS`.**
`QEZMAIN` is IBM's Operational Assistant menu, and an IBM menu renders a
command line for any user who is not `LMTCPB(*YES)`. So 139 profiles sitting
behind a tight vendor menu driver, exiting to `*SIGNOFF`, were **one keypress
from an unrestricted command line** — and nobody chose that, because
`*SYSVAL` is the default and the default points at a menu with a command line.
**Always resolve `*SYSVAL` before calling a population contained.**

**And check whether the initial program is QUALIFIED.** On XTL ~97 enabled
profiles name their initial program with `*LIBL`, against 18 that name a
library — so what runs at sign-on is decided by the library list, and copies
of two production menu programs were found in a personal library. Group by
`INITIAL_PROGRAM_LIBRARY_NAME`, not just the name.

**To read what a menu actually exposes**, `DSPPGMREF` to `QTEMP` works and is
cheap — but remember it cannot see programs called by variable, which is
exactly what a *menu driver* does. If the counts look implausibly small, the
menu is probably data-driven and you need the table it reads, not the program.

## Audit entries: `DETAIL_2` carries the before/after value

Do not infer the direction of a change from context. For `CP` (profile-change)
entries the harvested `DETAIL_2` holds the resulting value outright —
`*DISABLED` or `*ENABLED`. That is how a lockout-and-release pair was proven
on XTL rather than guessed: `QSYS/PCTELNET` → `*DISABLED`, then
`RBTADMIN/<job>` → `*ENABLED` on the same profile five minutes later.

**Pairs separated by a constant interval are a control, not a coincidence.**
Group by target object and look at the gap before concluding anything about
who is changing what.

## Before you report a number

1. Which partition produced it, and does that matter for this claim?
2. Does it cover ILE as well as OPM?
3. Is a blind spot above excluded from it, and is that stated?
4. Can it be re-derived from a saved query rather than cited?

`docs/research/index.md` keeps an explicit list of figures that are **not**
measured. Add to it rather than quietly promoting an estimate.
