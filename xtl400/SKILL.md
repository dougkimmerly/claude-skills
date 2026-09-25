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

  **Always include a port the host CANNOT be serving** — an invented high port
  such as 65001. If it behaves the same as the port you are investigating, you
  have measured Zscaler, not the box. Done 2026-09-21: 992 and 9470–9476 all
  "closed immediately", and so did 65001.

  **⚠ THE UNREACHABLE SIGNATURE IS DIFFERENT ON EACH PATH, SO THE CONTROL PORT
  IS NOT OPTIONAL.** Measured 2026-09-21, same probe, same minute:

  | | unreachable port looks like | reachable port looks like |
  |---|---|---|
  | `xtl400.xtl.com` (primary, by name) | **closed immediately** (reset) | held open, or replies |
  | `192.168.40.20` (target, by IP) | **held open** | held open, or replies |

  On the target path **65001 held open just like 9471 and 9476**, so "held" —
  the signal that means *real backend* on the primary — means nothing there.
  A rule of thumb learned on one host is wrong on the other. **Probe an
  invented port on the SAME host, every time**, and if you need certainty use
  `openssl s_client` and look for a ServerHello: `read 0 bytes` is nothing
  home, on any path.

  **⚠ `openssl s_client` IS THE MOST MISLEADING PROBE OF ALL, because it
  produces a confident TLS-shaped diagnosis.** Against an unbrokered port it
  prints `no peer certificate available`, `SSL handshake has read 0 bytes`,
  `Verification: OK`, `Verify return code: 0 (ok)` and a TLS 1.3 banner — which
  reads as *"the service is there and has no certificate"*. It is not there.
  **`read 0 bytes` is the tell**: a real TLS endpoint sends a ServerHello.

  **THE INSTRUMENT THAT SETTLES IT IS THE BOX'S OWN LISTENER TABLE.** Ask what
  it is listening on rather than what you can reach:

  ```sql
  SELECT LOCAL_PORT, COUNT(*) AS BINDINGS FROM QSYS2.NETSTAT_INFO
   WHERE TCP_STATE = 'LISTEN' GROUP BY LOCAL_PORT ORDER BY LOCAL_PORT;
  ```

  **It is a VIEW on 7.3, not a table function** — `SYSROUTINES` lists
  `NETSTAT_INFO`, but `TABLE(QSYS2.NETSTAT_INFO())` fails `SQL0204`. Select
  from `QSYS2.NETSTAT_INFO` directly.

  **Measured 2026-09-21, and the two halves disagree — which is the point:**

  | | ports |
  |---|---|
  | Box is **LISTENING** (`NETSTAT_INFO`, 2 bindings each, IPv4+IPv6) | 23, 449, **992**, **8470–8476**, **9470–9476** |
  | **Reachable** through ZPA | **23, 449, 8471, 8473, 8475, 8476** |
  | Listening but **NOT reachable** | **992, 8470, 8472, 8474, 9470–9476** |

  So the SSL host servers and telnet-SSL **are running**; ZPA simply does not
  publish them. Any *"SSL is not set up on the 400"* conclusion drawn from
  outside the estate is unfounded, and enabling TLS to the box is a **ZPA
  application-segment change**, not a change on the 400.

  Note the published set is a deliberate allowlist, not "all host servers":
  signon (8476), svrmap (449), database (8471), file (8473), remote command
  (8475) and telnet (23) — exactly what JDBC/ODBC and 5250 need. Central
  (8470), data queue (8472) and network print (8474) are listening and
  blocked. **Do not infer a service is absent because your client cannot
  reach it, and do not infer one is unreachable because it is unusual.**
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

**⚠ `sql400` splits the text you give it on `;` — including semicolons inside
`--` comments and inside quoted strings** (observed 2026-09-23; handed to
kb-xtl400, ruling pending). The symptom is `SQL0104 Token <AN ENGLISH WORD>
was not valid`, naming a word out of your prose, which reads like a syntax
error in the SQL and is not. **Strip comments before sending a heavily
commented statement** (`sed 's/--.*$//'`) and keep `;` out of string literals.
`RUNSQLSTM` on the box handles both correctly, so the same text works deployed
and fails from the tool — do not "fix" the query.

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

**And that is not special to aliases — `sql400` runs in SQL naming, so EVERY
qualified name needs a dot.** `DOUGIMG/XTLPASSLOG` in an ordinary `SELECT`
fails the same way, with the same `SQL5016` and the same unhelpful text. The
green-screen and CL world writes `LIB/OBJ` and the documentation in this
estate is full of it, so the slash form is the one you will reach for first
and it is wrong through this tool. Two round trips on 2026-09-22 before the
message was read properly.

### ⚠ `SRCDTA` IS NOT CCSID 37 EVERYWHERE, AND 65535 COMES BACK AS HEX (2026-09-21)

**Ask before you read. Never assume the code page.** Measured as `CCMAP`
(authority-filtered — 1,295 source files visible):

| CCSID | files | libs | |
|---|---|---|---|
| **37** | 1,245 | 194 | US EBCDIC — 96% |
| **65535** | **39** | **22** | **binary, "do not convert"** — incl. `WMSXTLTS`, `XTLSRC`, `PNETXTL` |
| 500 / 280 / 297 / 5035 / 1208 | 5 / 3 / 1 / 1 / 1 | | International, **Italian** (`MMAIL`), **French** and **Japanese** (`HPT`), **UTF-8** (`ACSEDI`) |

```sql
SELECT CCSID, LENGTH FROM QSYS2.SYSCOLUMNS
 WHERE SYSTEM_TABLE_SCHEMA='<lib>' AND SYSTEM_TABLE_NAME='<srcfile>'
   AND SYSTEM_COLUMN_NAME='SRCDTA';
```

**A CCSID 65535 column returns HEX from JDBC** — two characters per byte, 200
for a 100-byte record. It is not garbled and it does not error: it is EBCDIC
spelled out, and **it presents as a WIDTH bug, not an encoding one**. The tell
is a length that is exactly double, and `4040…` (EBCDIC spaces) at the front.
Convert explicitly: `CAST(SRCDTA AS CHAR(<len>) CCSID 37)`.

**Choosing 37 for a 65535 file is a CHOICE — record it.** 65535 means the box
does not know the code page either.

**⚠ THE TWO SETS ARE DISJOINT — the non-English files are NOT the 65535 ones.**
Measured 2026-09-22, correcting the obvious inference: `MMAIL` (280), `HPT`
(297/5035) and `ACSEDI/SQLSRC2` (1208) **declare their CCSID**, so `getString`
converts them correctly and the 65535 branch never fires for them. Every one of
the 39 is RPG/DDS/S36 source in an XTL or IBM-shipped library. 37 is the right
default, and the box argues for it itself:

| Check | Result |
|---|---|
| `QLANGID` / `QCNTRYID` | `ENU` / `US` → 37 |
| Siblings of the 39, same libraries | 183 of 184 declare 37 |
| Reading a 65535 member as 37 vs 500 | identical in 6 of 8 files tested; 6 records of 1037 differ in the other two, at a marker byte in the sequence-number area no compiler reads |

**`QCCSID` IS 65535 SYSTEM-WIDE ON THIS BOX, and that is why the 39 exist.** A
source file created by a job that let the system value through, instead of
resolving it from `QLANGID`, inherits 65535. It is not a signal that the content
is unusual — it is a signal that nobody set a CCSID at creation.

**And a wrong EBCDIC page does not look wrong.** 37, 500, 280 and 297 differ
in exactly the characters RPG allows in names — `$`, `#`, `@`, `[`, `]` — so
the output is *plausible source*, not obvious damage. Any bulk pull must read
each source file's declared CCSID per file, not once for the estate, and should
**record which page it read each member under** — `kb-xtl400`'s `MANIFEST.tsv`
carries `srcdta_ccsid` (`65535->37`) for exactly this reason.

### Fixed-form RPG: the comment marker is COLUMN 7, and column 6 bites

Parsing source? A comment is `*` at **index 6**. Measured on a pilot library:
**3,073 comment records at index 6, 34 anywhere else.** Columns 1–5 are the
change-tag area (`A001`, `a002` — the line-level blame), and **column 6 is the
form type, which on this estate frequently holds a non-ASCII byte** (`U+0082`
on 220 records of one library; present in members captured in 2026-09, so it
is faithful, not corruption).

**A rule that allows only five characters before the `*` therefore skips every
TAGGED line — which is exactly the set of modification entries.** It reported
0 entries for a member carrying eight, and understated a library's
modification count **12.6×**.

**There are at least three header dialects, and free-form is the newest:**
fixed-form `*` with labelled fields (`Program Title:`); fixed-form `*` with a
banner title and a `Program Modifications` table; and **free-form `//` with
dotted leaders (`Program......:`, `Change Log:`), which is the Tecsys/WMS
generation — i.e. Tier 1.** A parser that knows only `*` reads the estate's
best-documented code as its worst.

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
| `VARCHAR(<timestamp>)` → `SQL0171 argument not valid` | `CHAR(<timestamp>)`, then `SUBSTR` if you want it short |
| **A subquery in a `JOIN … ON` clause** → `SQL0104 Token EXISTS was not valid`, offering `<IDENTIFIER> <INTEGER> <CHARSTRING>` as valid tokens — it wants a value, not a predicate (tested 2026-09-23) | Move the test into `WHERE`. With an inner join the two are equivalent; with an OUTER join they are not, so check which you have before moving it |
| **A `WITH` inside a nested table expression** → `SQL0199 keyword AS not expected`, listing join keywords as the valid tokens. So `MERGE … USING (WITH … SELECT …)` and `SELECT * FROM (WITH …) q` both fail, and the message points at the CTE's `AS` rather than at the nesting (tested 2026-09-23) | A CTE **is** accepted in `DECLARE GLOBAL TEMPORARY TABLE SESSION.x AS (WITH … ) WITH DATA WITH REPLACE NOT LOGGED` and in `CREATE TABLE QTEMP.x AS (…) WITH DATA`. Stage into one of those, then `MERGE … USING SESSION.x`. Beats splitting the logic across several permanent views |

**The column names in current IBM documentation are frequently not the column
names on 7.3, and the error never says so.** `SQL0206 … not found` is what a
renamed or not-yet-existing column looks like. Six of them cost a query each in
one afternoon — `USER_INFO` has no `OUTPUT_QUEUE_LIBRARY`, `JOB_DESCRIPTION_INFO`
has `JOB_QUEUE` not `JOB_QUEUE_NAME` and `LIBRARY_LIST` not
`INITIAL_LIBRARY_LIST`, `EXIT_PROGRAM_INFO` has `EXIT_PROGRAM` not
`EXIT_PROGRAM_NAME`, `SPOOLED_FILE_INFO` has `SPOOLED_FILE_NUMBER` not
`FILE_NUMBER`, `AUTHORITY_COLLECTION` has `AUTHORIZATION_NAME`/`CHECK_TIMESTAMP`
not `USER_NAME`/`AUTHORIZATION_CHECK_TIMESTAMP`, and `SYSTABLESTAT` has no
`TABLE_TEXT`. Two more, 2026-09-21: **`JOB_INFO` has `JOB_USER`, not
`AUTHORIZATION_NAME`** (that one is `NETSTAT_JOB_INFO`'s), and
**`NETSTAT_JOB_INFO` has no `TCP_STATE`** — connection state lives in
`NETSTAT_INFO`, and the two views are easy to reach for interchangeably
because both key on `LOCAL_PORT`. **Do not memorise that list — ask first**,
it is one query:

```sql
SELECT COLUMN_NAME FROM QSYS2.SYSCOLUMNS
 WHERE TABLE_SCHEMA = 'QSYS2' AND TABLE_NAME = '<the view>'
 ORDER BY ORDINAL_POSITION;
```

**⚠ That query answers for VIEWS only. For a TABLE FUNCTION it returns zero rows
and tells you nothing** — and zero rows reads as "no such column", which sends you
looking for the wrong thing. Found 2026-09-25: `SYSCOLUMNS` knows nothing about
`IFS_OBJECT_STATISTICS`, `OBJECT_STATISTICS` or `IFS_READ`, and four guessed names
were rejected in a row (`IFS_OBJECT_STATISTICS` has **`PATH_NAME`**, not
`OBJECT_NAME`; `SYSTEM_VALUE_INFO` has **`CURRENT_NUMERIC_VALUE`** /
**`CURRENT_CHARACTER_VALUE`**, not `CURRENT_VALUE`; `PROGRAM_INFO` has
**`CREATE_TIMESTAMP`**, not `PROGRAM_CREATED`; `OBJECT_STATISTICS` has
**`CHANGE_TIMESTAMP`**, not `OBJECT_CHANGED`, and no `LAST_RESTORED_TIMESTAMP` —
it is `RESTORE_TIMESTAMP`).

**For a table function, `SELECT *` on one row and read the header.** `sql400`
prints the column labels as its first stdout line, so this costs one call and
cannot be wrong:

```bash
x400 <profile> sql400 "SELECT * FROM TABLE(QSYS2.OBJECT_STATISTICS('LIB','PGM','NAME')) X"
```

With ~90 columns that is a wall of tab-separated text, so pair the header with the
row rather than reading it positionally:

```bash
paste -d'=' <(… | head -1 | tr '\t' '\n') <(… | sed -n 2p | tr '\t' '\n') | grep -i chang
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

### ⚠ `JOB_INFO.JOB_STATUS` cannot see MSGW — so from here, you cannot

**A job sitting at an unanswered inquiry message reports `JOB_STATUS =
'ACTIVE'`.** `MSGW` is the *active job status*, which lives in
`ACTIVE_JOB_INFO` — the function this box does not have. So the substitute
above is not a substitute for this question, and there is no SQL route to it
from a PC client.

Found the hard way 2026-09-22: a `cl400` call hung, every `QZRCSRVS` job came
back `ACTIVE`, and the session told Doug *"none in MSGW."* He was looking at
the green screen — three of them were, one of them that call's own job,
holding a function check with `(C S D F)` on the bottom line.

**The failure mode is the dangerous one**: the query succeeds, returns rows,
and the rows are wrong for the question. Nothing announces it.

So:

- **Never conclude "not in MSGW" from SQL.** Report *"I cannot see MSGW from
  here"* and ask for a `WRKACTJOB` / `DSPJOBLOG` look.
- A `cl400`/`sql400` call that hangs with no output is **MSGW until proven
  otherwise** — the client shows nothing because the box is waiting for a
  reply that will never come from this side.
- Reading the job log is what settles it: the inquiry and its valid replies
  are the last lines. `DSPJOBLOG JOB(nnnnnn/QUSER/QZRCSRVS) OUTPUT(*PRINT)`
  captures it before the prestart job is recycled.
- A stranded job holds a `QZRCSRVS` prestart job until someone answers it.
  They accumulate silently.
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
  fine). **Always pass `MARGINS(<the file's `SRCDTA` length>)`** — 100 for a
  default `RCDLEN(112)` file, **228** for the `RCDLEN(240)` files a project
  creates for SQL source (`DOUGMAP/QSQLSRC`). Read it rather than assuming:
  `SELECT LENGTH FROM QSYS2.SYSCOLUMNS WHERE SYSTEM_TABLE_NAME = '<file>' AND
  COLUMN_NAME = 'SRCDTA'`. Bit again 2026-09-25 on an 85-character line, in a
  file wide enough to hold it — **the member is never the problem; the reader
  is.**
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

**⚠ DOUG HAS NOW GIVEN THIS INSTRUCTION TWICE** — 2026-09-19, and again
2026-09-23: *"Each project needs to be keeping a list of the objects it creates
permanently so that at the end of dev they can be added to the replication and
the backup."* **A rule restated is a rule that was not being followed**, so check
that the register exists rather than assuming it does. As of 2026-09-23
`proj-security` and `proj-as400-codemap` had one; `proj-imaging` did not, despite
creating libraries (its ADR 0013). The rule also lives **only in this skill**,
which is part of why it was missed — a repo auditing itself against
`proj-01-standards` never meets it.

**Two things that are easy to forget are on the list:**

- **Scheduled jobs are objects too.** A Robot job definition lives in the
  scheduler's own library. If that library is not replicated, the programs
  survive a role swap and nothing runs them. **`ROBOTLIB` IS replicated on this
  estate** (Doug, 2026-09-23) — so the scheduler does come across, and the
  exposure is the job's *targets*, not the job. **Do not re-derive this from
  `MIMIX.MXLIBREPP` or `MIMIX.OMOBJXEP`** — both mislead, and this is the direct
  answer from the person who knows.
- **The monitoring objects are NOT yet replicated** (Doug, 2026-09-23), and that
  is deliberate: they go in when the development that creates them finishes.
  Until then **assume monitoring does not survive a swap.** A known state with a
  known closing condition is not an unknown — and it is not being covered either.
- **The user profile the work runs as.** A replicated program owned by a
  profile that did not come across authenticates as nobody.

### ⚠ A PROGRAM THAT RIDES ANOTHER JOB CREATES OBJECTS OWNED BY THAT JOB (2026-09-24)

**And it can do it inside YOUR library, with nobody granting anything.**

`proj-imaging` runs two programs as command lines inside XTL's own scheduled
`IMPDOCS` job. After a library migration moved their tables, one of them found
its watermark data area missing, and its perfectly correct *"create it if it is
not there"* branch **created a fresh one under the identity of the job it was
riding** — `QPGMR`-owned, `*PUBLIC *CHANGE`, sitting in a library that is
otherwise entirely the project's and is `*PUBLIC *EXCLUDE`.

Nobody made a mistake and nobody widened anything. **The library simply stopped
being uniformly yours.** Consequences:

- **You cannot delete it.** `*CHANGE` through `*PUBLIC` lets you *write* the
  object; deleting needs `*OBJEXIST`, which you do not have on an object you do
  not own. It becomes a human act.
- **The "my library is a sandbox because I own everything in it" precondition
  is not established once — it is re-checked.** Cheap:
  ```sql
  SELECT OBJNAME, OBJTYPE, OBJOWNER FROM TABLE(QSYS2.OBJECT_STATISTICS('<lib>','*ALL'))
   WHERE OBJOWNER <> '<your profile>';
  ```
- Same family as the `OWNER(*GRPPRF)` trap above, but the cause is different:
  there the *creating profile's* group owns it; here the *job you are inside*
  does.

### ⚠ INSIDE SOMEBODY ELSE'S JOB, QUALIFIED IS THE SAFE FORM

The inverse of the usual advice, and it bit the same project the same day.

A program that runs as a step inside another application's job is on **that
job's library list**, which you do not control and must not reorder — the rest
of the job runs after you. `proj-imaging` adds its libraries `*LAST` precisely
so production's names still resolve to production for the importer that
follows.

**So an unqualified name there resolves to PRODUCTION.** Its test tables carry
production's own names (`EKD0312`, `EKD0310`, …), so unqualifying them would
have made a test program read — and write — the live files, from inside the
live job. **The rule "never name the library, let the list decide" is a rule
about jobs you own.** At the edge of one you do not, name the library, and say
in the source why.

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

### ⚠ AN SQL NAME OVER TEN CHARACTERS IS NOT THE NAME THE BOX REPORTS

**Auditing a list of objects against the box produces false positives, and it
did on 2026-09-23.** `CREATE INDEX XTLPGMMAP.MAPHDR_NAME` exists on the box as
**`MAPHD00001`**: over ten characters, so the system generated a short name, and
`OBJECT_STATISTICS` answers with the generated one while your DDL and your docs
carry the SQL one.

```sql
SELECT INDEX_NAME, SYSTEM_INDEX_NAME FROM QSYS2.SYSINDEXES WHERE INDEX_SCHEMA = '<lib>';
SELECT TABLE_NAME, SYSTEM_TABLE_NAME FROM QSYS2.SYSTABLES  WHERE TABLE_SCHEMA = '<lib>';
```

Resolve before chasing a discrepancy. Same family as the
`TABLE_SCHEMA`-versus-`SYSTEM_TABLE_SCHEMA` trap above — **anything that
round-trips a name between SQL and the object model needs the pairing, not the
name you wrote.**

### ⚠ ASK FOR THE CONTAINERS, NOT THE CONTENTS — A SWEEP CANNOT SEE A CLOSED LIBRARY

**The single cheapest correction on this estate, measured 2026-09-23.**

`OBJECT_STATISTICS('*ALLUSR','*PGM')` returns nothing at all for a library whose
`*LIB` object your profile cannot read. Not an error, not an empty library —
**the library is absent from the answer**, so every count, percentage and
register built on that sweep silently describes a smaller estate than exists.

```sql
-- what you asked (324 s) — and it cannot see the door that is shut
SELECT OBJLIB, COUNT(*) FROM TABLE(QSYS2.OBJECT_STATISTICS('*ALLUSR','*PGM')) GROUP BY OBJLIB;

-- what to ask FIRST (0.5 s) — 522 rows, and the closed ones are in it
SELECT OBJNAME, CASE WHEN OBJOWNER = '' OR OBJOWNER IS NULL THEN 'CLOSED' ELSE 'OPEN' END
  FROM TABLE(QSYS2.OBJECT_STATISTICS('QSYS','*LIB','*ALL'));
```

⚠ **The third argument is required** — `('QSYS','*LIB')` returns one row.

**What it found:** `SEIOBJ`, 161 programs all `*PUBLIC *CHANGE`, missing from a
code map for a week because the *library* was closed while every object in it
was open. One `GRTOBJAUT` on the `*LIB` recovered **4,360 declared edges, 1.3%
of the graph** — against a "blind spot" that had been carefully measured at
0.3% by comparing two profiles *inside the filter*. **93 of 522 libraries are
closed to that profile**, including six libraries of a production application.

**The rule: a measurement taken through a filter cannot measure the filter.**
Before quoting any estate-wide count, ask what the enumeration itself could not
see, and ask for the containers to find out.

**⚠ AND WHEN THE TEXT SAYS *NOT FOUND*, THAT IS NOT PROOF EITHER — RUN IT AS A
SECOND IDENTITY.** 2026-09-23: `DSPPGMREF` over eight libraries failed `-443`,
and by hand the box said `CPF3033 Object *ALL in library I93FILE of type PGM
not found` while `OBJECT_STATISTICS` reported five programs there minutes
earlier. It was **authority**, and all eight scanned cleanly under a more
authorised profile. One view filters silently, the other calls the filtered
result absence, and **neither can tell you which** — so two instruments
disagreeing about the same object is a signal to change *who is asking*, not to
find a third instrument.

The same comparison quantified the blind spot, and this is the part to carry:
**the gap is object-level, not library-level.** The eight libraries were 166 of
a 980-edge difference; ~814 edges were hidden *inside* libraries the lesser
profile scans successfully, worst in `ROBOTLIBV9`, `RBTRCLLIB` and `ROBOTLIB`.
**Spot-checking one library under two profiles and finding agreement proves
nothing estate-wide** — that exact check had passed the day before.

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

### `JOURNAL_ENTRY_TYPES` TAKES A COMMA-SEPARATED LIST, and it pushes down (2026-09-22)

Not documented anywhere obvious and it changes how you census a journal.
Measured on `QSYS/QAUDJRN`, same hour, same box:

| Read | Rows | Time |
|---|---|---|
| no type filter | ~915,000 | **80 s** |
| `JOURNAL_ENTRY_TYPES => 'JS,PS,GS,IP,OM,LD,ZR,PO,SG,SO,PG,NR,PR'` | 302,000 | **21 s** |
| `=> 'ZC'` alone | 570,000 | 32 s |

So **one filtered read covering thirteen types beats one unfiltered read**, and
you do not have to choose between "one read per type" and "read everything".

**Census the journal before believing any list of entry types.** XTL's audit
journal produced **26 distinct types in a single hour** on 2026-09-22 — a
`proj-security` finding written four days earlier said 25 and had been quoted
into eight research pages. The list is cheap to re-derive and goes stale:

```sql
SELECT J.JOURNAL_ENTRY_TYPE, COUNT(*)
  FROM TABLE(QSYS2.DISPLAY_JOURNAL(
         JOURNAL_LIBRARY => 'QSYS', JOURNAL_NAME => 'QAUDJRN',
         STARTING_RECEIVER_NAME => '*CURCHAIN',
         STARTING_TIMESTAMP => CURRENT TIMESTAMP - 1 HOUR)) J
 GROUP BY J.JOURNAL_ENTRY_TYPE ORDER BY 2 DESC;
```

**⚠ AN HOUR IS OFTEN TOO SHORT A WINDOW TO SEE A TYPE'S SHAPE.** `PG` measured
2 entries and 1 pattern in the census hour; a two-day backfill gave 58 patterns
and 1,980 events. Volumes burst. **If a measurement is going to decide a design,
take it over a window long enough to contain a business cycle**, or re-take it
after the design runs — see the `LD` case below.

**Only a profile with authority on the journal can read it.** `CCSEC` gets
`SQL0443 Not authorized to object QAUDJRN in QSYS` — an authority failure, and
note this is the *other* meaning of `SQL0443` documented above, so read
`MESSAGE_TEXT` before concluding the data aged out.

### Aggregating a journal on the way in: pick the key, then MEASURE IT AGAIN

When a journal type is too voluminous to store per event, the move is to insert
one row per (type, day, pattern) rather than per entry. **The grouping key is
per entry type and choosing it wrongly destroys the finding without failing** —
there is no error, just a smaller, plausible table.

Worked on XTL's `LD` (link/unlink/search directory), all four measured:

| Key | Result |
|---|---|
| user+program+**object type** | 42 patterns/hour — an IFS traversal is invisible |
| user+program+**full path** | 3,419/hour — a copy wearing a summary's name |
| user+program+**directory** | **14,824 pattern-days from a 2-day backfill** |
| user+program+**first two path components** | **588.** Chosen |

**The third row is the lesson.** It was chosen from the hourly census, deployed,
and only then measured against real output — at ~7,400 rows a day for one entry
type it was not a summary at all. **Measure the key after it runs, not only
before.** The columns to consider are wider than they look: `DISPLAY_JOURNAL`
carries `REMOTE_ADDRESS`, `PATH_NAME` and `CURRENT_USER` as well as the obvious
object columns, and on `PW` the finding lives *only* in the remote address.

**Keep a dimension that adds no cardinality today if it is the payload.** Equal
counts mean every (user, program) currently maps to one swapped-to profile from
one address — which is exactly the state whose *change* is the event worth
seeing. Fold it away and the change lands silently inside an existing row.

**⚠ A SECOND WRITER TO A SHARED TABLE BREAKS WATERMARKS NOBODY THOUGHT WERE
SHARED.** Two roll-up jobs read `MAX(LAST_HARVEST_TS)` across the whole pattern
table — correct while one member was the only writer. The moment a second kind
of member wrote a newer timestamp, the folding job would skip raw rows it had
never folded and the prune job would **delete them as consumed**. Measured on
the box after deploying: the global form saw **0** unconsumed rows, the
per-entry-type form **143,052**. *A watermark is only sound while you know who
writes it* — adding a writer is the moment to re-read every reader.

**And if you dedupe on `SEQUENCE_NUMBER >` a high-water, guard the reset.** XTL's
audit journal burns ~32.6M sequence numbers a day against a ~10-billion ceiling
— a reset is months, not years, away — and on reset a sequence high-water
matches nothing and returns a clean, fast, confident zero. Check what you hold
against `MAX(LAST_SEQUENCE_NUMBER)` from `JOURNAL_RECEIVER_INFO` and fail loudly.

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

### ⚠ THE `SYSTOOLS.AUDIT_JOURNAL_*` WRAPPERS LEAK JOB TEMPORARY STORAGE (2026-09-25)

**~1.25 GB per hour of journal read, never released inside the job.** A
long-lived job that reads the journal repeatedly degrades and then dies with
`SQL0901` internal error type 3871 (`QSQGTSPC` / `CREATEMEMORYOBJ`, *"could not
create memory object"*). A fresh job resets, which is why the failure looks
intermittent and data-dependent. **It is neither.**

Measured under control — one job, the same six 1-hour slices, same entry type,
identical row counts, only the table function varying:

| | job temp storage | elapsed |
|---|---|---|
| `SYSTOOLS.AUDIT_JOURNAL_GR` | **2,425 MB → 9,983 MB** | 145 s |
| `QSYS2.DISPLAY_JOURNAL` | 9,949 MB → 9,965 MB | **8 s** |

**Volume is not the driver, and assuming it is will cost you a day.** On the
same estate `ZC` moves 4.5M events in 171 s through `DISPLAY_JOURNAL` while
`GR` took 919 s for 237k through the wrapper — a 50–100× difference per row.
Three separate hypotheses (volume, profile authority, window size) were tested
and killed before the API was suspected.

**The instrument is `QSYS2.SYSTMPSTG`** — a bucket per job, and a job can read
its own:

```sql
SELECT BUCKET_CURRENT_SIZE, BUCKET_PEAK_SIZE FROM QSYS2.SYSTMPSTG
 WHERE JOB_NUMBER = SUBSTR(QSYS2.JOB_NAME, 1, 6);
```

**`SQL0901` will not tell you any of this.** It is documented only as *"an SQL
system error … see the previous messages"*, and internal error type 3871 and
the `QSQGTSPC` module appear nowhere in IBM's published material. This was
settled by measurement, not by reading.

### `ENDING_TIMESTAMP` really does bound the walk — so slicing is FASTER, not a trade

Both `QSYS2.DISPLAY_JOURNAL` and the `SYSTOOLS.AUDIT_JOURNAL_*` functions accept
`ENDING_TIMESTAMP` and `ENDING_SEQUENCE`, and the end bound **stops the receiver
walk early rather than filtering after it**. Measured: one bounded 1-hour slice
**52 s**, the same read unbounded over 22 hours **>78 minutes and then dead**.

That matters because it makes a harvest **resumable at no cost**. A single
unbounded statement that dies saves nothing, the high-water never moves, and the
next run faces a larger window — read cost rises with the window, so each
failure makes the next likelier. That is a ratchet, and the self-healing derived
lookback is what powers it. Slice it, commit each slice, and a failure costs one
slice. Re-verify the bound after any upgrade; if it ever becomes a post-filter,
slicing inverts from a win to an N× loss.

### `CPYAUDJRNE` — the third route, and usually the right one

Copies audit entries into IBM's own **fully decoded `QASYxxJ5` outfile**, so you
write **no byte offsets at all** — which is the risk that makes hand-decoding
`DISPLAY_JOURNAL`'s raw `ENTRY_DATA` dangerous.

- **No leak.** Four full copies in one job: 26.4 → 30.6 → 30.74 → 30.74 MB.
- **Fast.** 17,391 `CA` entries in 3 s; 59,977 in 14 s.
- **`*AUDIT` only — NOT `*ALLOBJ`** (unlike `DSPAUDJRNE`, which needs both). So
  a least-privilege collector profile can run it.

**Five traps, each of which cost a round:**

- **`OUTFILE` is a PREFIX.** `OUTFILE(LIB/CB)` creates `CBCA` — prefix + entry
  type. The file is created **`*PUBLIC *EXCLUDE`**, so an ordinary profile then
  gets `SQL0551` reading it.
- **Omitting `JRNRCV` reads ONLY the attached receiver** and returns
  `CPF7062 No entries converted` in two seconds — a clean, confident zero for a
  window holding tens of thousands. Same family as the `DISPLAY_JOURNAL`
  `*CURCHAIN` trap above. Use `JRNRCV(*CURCHAIN)`; **max 256 receivers**.
- **`JRNRCV(*CURCHAIN)` with no time bound reads the whole chain** — 2.9M rows
  and still climbing before it was stopped. Always pass `FROMTIME`/`TOTIME`.
- **`FROMTIME`/`TOTIME` are INCLUSIVE AT BOTH ENDS**, so an entry on a slice
  boundary is copied by two adjacent slices. A sequence high-water only catches
  that if sequence rises strictly with timestamp, and it does not reliably —
  this produced `SQL0803` against a primary key on two consecutive runs. Test
  `NOT EXISTS` against the key instead; it does not care about ordering.
- **They take the JOB's date format**, `MDY` with `/` on this estate. Build with
  `SUBSTR(CHAR(DATE(ts),USA),1,6) CONCAT SUBSTR(CHAR(DATE(ts),USA),9,2)` and
  `CHAR(TIME(ts),JIS)`.

**⚠ AND VERIFY THE COLUMN MAPPING AGAINST THE WRAPPER BEFORE TRUSTING IT.**
The outfile column names look obvious and three of the first eight chosen for
`CA` were wrong — **none of which errored**. The serious one: the wrapper's
`USER_NAME` is **`CAUSPF`** (the effective profile), not `CAUSER` (the job
user); they differ on **22% of rows**, and a real row reads `QSECOFR` /
`MIMIXOWN` / `QSECOFR`. Taking the obvious column silently attributes
`QSECOFR`'s authority changes to `MIMIXOWN`. Also: the outfile writes `'*N'`
and blanks where the wrapper returns NULL, `JOB_NUMBER` needs `DIGITS()`,
`REMOTE_PORT` writes `0` for NULL, and **`CAPNM` is unreadable without an
explicit CCSID** (`SQL0332`) — `CAPCCI` carries the real one. Worked method and
the full verified mapping:
`proj-security/secaudit/analysis/ca-outfile-mapping.md`.

### ⚠ `*ALLOBJ` DOES NOT CONFER SPOOL ACCESS (2026-09-24)

A profile holding `*ALLOBJ *SECADM *AUDIT` still gets **`CPF3492 Not authorized
to spooled file`** copying another user's job log. Spooled files are not
authorised as objects — the **output queue's** parameters decide.

On this estate `QUSRSYS/QEZJOBLOG` and `QEZDEBUG` are `DSPDTA(*NO)`,
`OPRCTL(*YES)`, `AUTCHK(*OWNER)`. Under `DSPDTA(*NO)` the 7.3 Security
Reference (ch. 6, *Display Data (DSPDTA) parameter of output queue*) lists
**`*JOBCTL` with `OPRCTL(*YES)` as sufficient** to display, copy or send another
user's spooled file — so `*JOBCTL` is the narrow grant and `*SPLCTL` (every
spooled file on the box, including delete) is not needed.

**Read the queue's actual values first — the answer inverts.** Had they been
`DSPDTA(*OWNER)`, the same manual says `*JOBCTL` on an `OPRCTL(*YES)` queue
**cannot** display, copy, move or send, and `*SPLCTL` would have been the only
route.

```sql
SELECT OUTPUT_QUEUE_NAME, DISPLAY_ANY_FILE, OPERATOR_CONTROLLED, AUTHORITY_TO_CHECK
  FROM QSYS2.OUTPUT_QUEUE_INFO WHERE OUTPUT_QUEUE_NAME IN ('QEZJOBLOG','QEZDEBUG');
```

**Consequence for any scheduled collector:** its job log is where the real
cause of an `SQL0901` lives, and without one of these routes it is unreadable —
which is how a diagnosis stalls for a day. Give the job an output queue you own
with `DSPDTA(*YES)`, or arrange the `*JOBCTL` grant deliberately.

### ⚠ TO ASK "WHAT DOES THIS PROFILE HOLD", USE `DSPUSRPRF TYPE(*OBJAUT)` — NOT `OBJECT_PRIVILEGES` (2026-09-25)

`QSYS2.OBJECT_PRIVILEGES` filtered by `AUTHORIZATION_NAME` scans every object
on the box: one `COUNT(*)` took **29 minutes** on the primary. The profile's
own authorities come out of an outfile in seconds:

```
CL: DSPUSRPRF USRPRF(CCSEC) TYPE(*OBJAUT) OUTPUT(*OUTFILE) OUTFILE(YOURLIB/PRFOBJ);
```

Columns are `OA*`, and the write bits are the ones to test — `OAUPD` `OAADD`
`OADLT` `OAEXS` `OAOMGT`, each `X` or blank (not `YES`/`NO`):

```sql
SELECT OALIB, OAOBJ, OATYPE, OAOWN, OAOPR, OAREAD, OAADD, OAUPD, OADLT, OAEXS, OAOMGT
  FROM YOURLIB.PRFOBJ ORDER BY OALIB, OAOBJ;
```

**Use `OBJECT_PRIVILEGES` for the other direction** — *who can write this
object* — and for the estate-wide `*PUBLIC` surface, which is a real question
with a real cost (**200,824 objects writable by `*PUBLIC` on XTLTOR**,
2026-09-25, 29 min; background it).

**Two things this outfile is uniquely good at, both found the day it was
written.** It lists authorities on `*USRPRF` objects, where a profile owned by
a group hands every member `*ALL` — and `*USE` on a profile is what
`SBMJOB USER(...)` needs, so *ownership of a profile object is a
run-as-that-identity grant*. And it shows a profile's grants on **its own**
project's objects, which is where a deploy script's accumulated
`GRTOBJAUT`s show up as a list somebody can actually read.

## Costs, measured

- Estate-wide `*PGM` scan: ~25 s (target), ~90 s (primary).
- **`OBJECT_PRIVILEGES` `COUNT(*)` for `*PUBLIC` write, all object types: 29
  minutes** (primary, 2026-09-25). Background it or scope it to a library.
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

- **⚠ THIS BOX HAS SIX TIMESTAMPS THAT ALL SOUND LIKE "WHEN IT CHANGED", AND FIVE
  ARE WRONG FOR DATING A BUILD (2026-09-25).** `IMPSEID` again, and this time the
  wrong columns produced a *published paradox*: an object apparently **predating
  its own source member by sixteen hours**, read as evidence that the running
  program was built from something else. It was not. Measured:

  | fact | the column that says it | value |
  |---|---|---|
  | source last **edited** | `SYSPARTITIONSTAT.LAST_SOURCE_UPDATE_TIMESTAMP` | **2026-02-17 10:18:36** |
  | program **compiled** | `OBJECT_STATISTICS.OBJCREATED` | **2026-02-17 10:21:28** |
  | object saved to a savefile | `SAVE_TIMESTAMP` | 2026-06-01 16:23:21 |
  | object restored | `RESTORE_TIMESTAMP` | 2026-06-01 16:24:04 |
  | object "changed" — misread as created | `CHANGE_TIMESTAMP` | 2026-06-01 16:25:52 |
  | member "last changed" — misread as edited | `LAST_CHANGE_TIMESTAMP` | 2026-06-02 08:07:03 |

  **Source edited, compiled three minutes later.** The June pair is one
  `SAVOBJ`-into-`QTEMP/OMSAVF`-then-restore — an object *move* — and **this box
  was swapping MIMIX roles in exactly that window**, so May–June 2026 is the most
  date-contaminated stretch on the system. `LAST_CHANGE_TIMESTAMP` also moves on
  `CPYF`, `RGZPFM`, a restore and a MIMIX apply.

  So, before trusting any date on this box:
  - **Member edited → `LAST_SOURCE_UPDATE_TIMESTAMP`. Object built →
    `OBJCREATED`.** Never `LAST_CHANGE_TIMESTAMP`, never `CHANGE_TIMESTAMP`.
  - **Read `SAVE_TIMESTAMP` and `RESTORE_TIMESTAMP` first.** If either sits beside
    the date you are about to rely on, that date describes a move, not work. Here
    they sat two minutes either side of it.
  - **A compile is MINUTES after its source edit.** A gap of months means you are
    holding the wrong pair of columns, or the wrong source.
  - **Blank `SOURCE_FILE_LIBRARY`/`FILE`/`MEMBER` in `PROGRAM_INFO` is common here
    and is not itself suspicious** — it means the trail is name-plus-timing, so the
    timing has to come from the right columns. Worked instance and the full
    reasoning: `kb-xtl400` `knowledge/impseid-provenance.md`.

- **An authority wall is reported as an empty result, and `CHKOBJ` is the
  instrument that separates the two.** Found 2026-09-23 the expensive way: a
  scan of every library for a source member named `IMPSEI*`
  (`QSYS2.SYSPARTITIONSTAT`) returned **zero rows**, and that was published as
  *"the program has no source anywhere on the system"*, which changed a design
  decision. The member exists — `SEISRC/QRPGLESRC(IMPSEID)`, 505 lines.
  **`SEISRC` is `*PUBLIC *EXCLUDE`**, and `CPF9820 Not authorized to use
  library` stays in the job log where an SQL result never sees it.

  **Ask the question that has three distinguishable answers:**

  ```
  cl400 "CHKOBJ OBJ(<LIB>/<SRCFILE>) OBJTYPE(*FILE) MBR(<MBR>)"
  ```

  | Result | Means |
  |---|---|
  | `OK` | it is there and you can reach it |
  | `CPF9815` | member genuinely not found |
  | `CPF9820` | **not authorized to the library** — you cannot tell either way |

  Run it against a member you *know* exists and one you *know* does not, in a
  library you can read, before trusting the third answer.

- **`DSPOBJAUT` and `QSYS2.OBJECT_PRIVILEGES` return YOUR line, not the
  object's authority list**, when you lack authority to manage the object. Same
  day, same root cause, two more wrong published claims: `SEIOBJ` was reported
  as having **no `*PUBLIC` row** (it has `*PUBLIC *EXCLUDE`, plus `QPGMR *ALL`
  and two more), and its programs as *"160 of 161 `*PUBLIC *CHANGE`, one is the
  exception"* — all 161 are, and only the row granted to the querying profile's
  group was visible. **An authority row *count* is never evidence about an
  object you cannot manage.** A profile with `*ALLOBJ` sees four rows where an
  ordinary one sees one.

  **And the control has to vary the thing you are worried about.** A presence
  control *was* run for the first of these — against two libraries the profile
  could already see into, which proved only that the view returns `*PUBLIC` rows
  *in general*. It could not test the case in doubt, which was authority.


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

## ⚠ A DB2 BUILT-IN silently beats a column that is not there

`SELECT JOB_NAME FROM <table>` returns **your own job name on every row** when
the table has no column of that name — no error, no warning. A `WHERE` on it
then returns zero rows and reads as an empty table.

**The tell is a column identical on every row, or a filter on it matching
nothing.** Confirm column names against `QSYS2.SYSCOLUMNS` before believing a
result from an unfamiliar file.

**The Robot instance of this — `RBTROB`, whose real column is
`ROBOT_JOB_NAME` — is documented with its measurement in the `robot-schedule`
skill. Load that skill before querying any `ROBOTLIB` file.**

## `DSPPGMREF` cannot see triggers either — `SYSTRIGGERS` can

**A trigger is an edge no static read of a program will ever produce.** The
program declares the file and stops there; the trigger fires underneath the
write, runs other code and touches other files. So *"what writes this file"*
answered from `DSPPGMREF` alone is incomplete on this estate in a way that looks
complete.

**470 triggers, 168 tables, 57 programs, 28 schemas** — measured 2026-09-23,
readable by a plain read profile in 0.1 s.

```sql
SELECT TRIGGER_PROGRAM_LIBRARY, TRIGGER_PROGRAM_NAME,
       ACTION_TIMING, EVENT_MANIPULATION, ENABLED
  FROM QSYS2.SYSTRIGGERS
 WHERE SYSTEM_EVENT_OBJECT_TABLE = 'WOJOBS'
```

⚠ **Join on `SYSTEM_EVENT_OBJECT_TABLE` / `SYSTEM_EVENT_OBJECT_SCHEMA`, never on
`EVENT_OBJECT_TABLE`.** The SQL name and the system name are different strings
for most of this estate's files, and joining on the SQL one finds nothing and
raises nothing — the same family as the generated-index-name trap above.

**Where they are:** `MIMIX` 203 over 58 tables (replication, 2 programs),
`QSYS` 51, `QSYS2` 39, `ROBOTLIB` 33, and then XTL's own — `I93FILE` 19 over 11
tables with 13 distinct programs, `XDIFILE` the same.

**And the trigger programs are often unreadable.** In XTL's data libraries the
only programs present are the triggers (`CMBEFINS`, `JOBEFINS`, `JOBEFUPD`,
`TMBEFINS`, `TMBEFUPD`, one set per library) and they are closed to a read
profile. Do not read that as a reason to seek a grant: `SYSTRIGGERS` already
states what fires on what, and the object only holds the body.

## Compiling from a shell session: five traps, all of them found on 2026-09-22

A session lost roughly two hours building one test harness. None of it was
exotic; all of it is invisible until it bites.

**1. `EVFEVENT` has ONE MEMBER PER PROGRAM, and SQL reads the wrong one.**
`SELECT * FROM lib.EVFEVENT` reads the *default* member, which is whatever was
compiled first — a session read a stale, unrelated compile three times and
"diagnosed" it twice. Address the member:

```sql
CREATE OR REPLACE ALIAS lib.A_EV FOR lib.EVFEVENT(MYPGM);
SELECT EVFEVENT FROM lib.A_EV;
```

**2. `EVFEVENT` comes back as EBCDIC hex** through `sql400`. Decode `cp037`:

```python
binascii.unhexlify(line).decode('cp037')
```

Filter on severity, not on the word ERROR: informational rows are
`... I 00 ...` and the one that stopped the compile is `E 20` or `S 30`. A
filter for "ERROR" returns forty harmless `RNF7031 name not referenced` lines
and hides the one that matters.

**3. `DFTACTGRP` / `ACTGRP` / `USRPRF` are rejected at MODULE scope** —
`RNF1324 E 20`. Valid in an `H`-spec for `OBJTYPE(*PGM)`, fatal for
`OBJTYPE(*MODULE)`. Set the activation group on `CRTPGM` instead.

**4. `BNDSRVPGM((*LIBL/NAME))` still has to resolve AT BIND TIME** — `CPF5D03`
if the bind job's library list cannot see it. `*LIBL` defers *run-time*
resolution; it does not defer the bind. Either put the library on the list for
the compile, or bind qualified and accept that the library is recorded.

**5. A host variable in `FETCH FIRST :n ROWS ONLY` is not valid in static
SQL.** Bound the loop in RPG instead — which is better anyway, because "the
first N" then means the same N on every run.

**And the one that is not a compile trap — FIXED 2026-09-25, no workaround
needed.** `sql400` used to split statements on **every** semicolon, including
those inside string literals and `--` / `/* */` comments, so a comment reading
`...; monitored by MONMSG` became two broken statements and `SQL0104` named an
English word as an invalid token. `split()` is context-aware now: literals,
delimited identifiers and both comment forms are stepped over, while a genuine
multi-statement `sql400 "A; B"` still runs as two. **Stop stripping comments
before sending, and if `~/.local/lib` might be stale, re-run
`kb-xtl400/tools/x400/build.sh`.**

**Two more in that family, same date, same repo:**
- **`cl400` used to HANG forever on a refused sign-on** — no output, no error,
  killed at 90s — because jt400's `AS400` object defaults to GUI-available and
  tries to raise a sign-on dialog. It now exits 1 in under a second, as do
  `ifsput`, `ifs400`, `src400`, `put400` and `pgm400`: the fix is in
  `X400Creds.connect()`. **This matters more than a hang normally would:**
  `QMAXSIGN` is 4 and `QMAXSGNACN` is 3, so the fourth invalid sign-on
  **disables the profile**, and a silent hang invites the retry that spends the
  budget. It cost `SECAUDIT` on 2026-09-23 and needed `*SECADM` to recover.
  **Never retry a credential blindly on this box.**

  **⚠ But a refused credential is only ONE cause of a `cl400` hang, and the fix
  bounds only that one.** The second, measured 2026-09-25, is a **server-side
  function check in the `QZRCSRVS` job**: the called program takes an unhandled
  escape and the job stops answering, with the identical client symptom — no
  output, no error, never returns. **Tell them apart by whether `cl400` printed
  its `job:` line**: if it did, the sign-on already succeeded, `setLoginTimeout`
  does not apply (it bounds connect, not an in-flight `CommandCall.run()`), and
  **retrying the credential is the wrong move** — read that job's log instead.
  **How you get there:** the called program takes an **unhandled escape** and
  function-checks inside the server job. A common route is a `MONMSG` that looks
  global but is not — **written after an executable command it is
  command-scoped**, so the message it was meant to catch goes unhandled (same
  family as the `ADDLIBLE`/`MONMSG` trap below). Client-side the block is in
  `AS400ThreadedServer.run` → `DataStream.readFromStream` → `SocketInputStream.read`.
  Measured by `proj-security`, whose tier is tighter than this skill's audience —
  the mechanism is here, the instance stays with them.
- **`ifsput` used to tag every file it wrote CCSID 1200 (UTF-16)**, so correct
  ASCII bytes read back through `QSYS2.IFS_READ` as **one empty line** —
  indistinguishable from a file that was never written. It now defaults to 1208,
  takes `ifsput LOCAL /path [CCSID|binary]`, and prints the tag. Note for any
  other tool that writes the IFS: **the job CCSID is not a usable default here —
  `QCCSID` is 65535.**

## Testing whether an IFS file exists when you have no attribute authority

`QSYS2.IFS_OBJECT_STATISTICS` returns **NULL** rather than failing for a file
you have data authority to but not attribute authority — so *missing* and
*unreadable* are indistinguishable through it, which is the exact failure mode
to avoid.

`IFS_READ_BINARY` with `IGNORE_ERRORS => 'YES'` returns **no rows** for a file
that is not there, and rows for one that is. That is a clean existence test:

```sql
SELECT D.NAME,
       (SELECT COUNT(*) FROM TABLE(QSYS2.IFS_READ_BINARY(
          '/path/' CONCAT TRIM(D.NAME), 1000000, 'NONE', 'YES'))) AS FOUND
  FROM sometable D
```

Signature on 7.3 is `(PATH_NAME, MAXIMUM_LINE_LENGTH, END_OF_LINE,
IGNORE_ERRORS)` — **not** the `FILE_OFFSET`/`FILE_LENGTH` form. Set the line
length large so a file returns one row rather than thousands of 4-byte rows.

**Measured throughput, XTLTOR 2026-09-22:** ~125 documents/second from SQL,
and **~628/second** from RPG calling C `open()`/`close()` in a loop. Ten
million files is about five hours by the RPG route. Existence-checking a whole
archive is a day's job, not a project.

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

## A `*DISABLED` profile stops YOU, not the jobs running as it (2026-09-22)

`User ID is disabled.:CCIMG` from JDBC means the profile is `STATUS(*DISABLED)`
— and the obvious next thought, that everything running under that profile has
stopped too, **is wrong and will cost you an incident report.**

`*DISABLED` blocks **sign-on**: interactive sessions and host-server
connections, which is every one of these tools. It does **not** stop a batch
job already submitted under that user, and it does not stop a scheduler
submitting new ones — `SBMJOB`/`STRPJ` with `USER(x)` keep running and keep
starting.

Measured on 2026-09-22: `CCIMG` was disabled at 18:55 the previous evening and
stayed disabled overnight, while its Robot job logged **95 scheduled passes
that day and 35 more by 08:31 the next**, with no gap. A session was one
sentence away from publishing "the harvest has been dead all night."

**So when a profile is found disabled, say what is blocked — your access — and
measure the job separately before saying anything about it.** The job's own log
is the instrument; your connection failing is not evidence about it.

Re-enabling needs somebody with the authority: `CHGUSRPRF USRPRF(x)
STATUS(*ENABLED)`. Note `XTL-Transport-Inc/enable-as400-profiles` exists to do
exactly this on a sweep, but its target list is a `DSPUSRPRF` snapshot last
refreshed 2026-05-31 — a profile created since then is not in it.

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

**A third time, 2026-09-22, and the skill already said all of the above.** A
~30-minute scan was killed to free a session; `MAPHDR` stayed locked with three
`*SHRRD` for **over an hour**, and every `ALTER TABLE` against it failed
`SQL0913`. Reading this section first would have cost thirty seconds.

**The cheapest way to find the survivor, and it works from a least-privileged
profile** — `WRKOBJLCK` and `WRKACTJOB` both need authority to see other jobs,
`OBJECT_LOCK_INFO` does not:

```sql
SELECT JOB_NAME, LOCK_STATE, LOCK_STATUS, COUNT(*) AS N
  FROM QSYS2.OBJECT_LOCK_INFO
 WHERE SYSTEM_OBJECT_SCHEMA = '<lib>' AND SYSTEM_OBJECT_NAME = '<file>'
 GROUP BY JOB_NAME, LOCK_STATE, LOCK_STATUS
```

⚠ **`SYSTEM_OBJECT_NAME`, not `OBJECT_NAME`,** and there is **no
`JOB_USER_NAME`** column — that one is `SQL0206`.

**⚠ `QSYS2.CANCEL_SQL` is not the escape hatch.** It needs the
`QIBM_DB_SQLADM` function usage and returns `SQL0552 Not authorized to
PROCEDURE` without it. A least-privileged batch profile does not have it and
**should not be given it to work around this** — the authority exists to stop
one job cancelling another's work.

**Before starting anything long, know how you will stop it.** Ending it needs
`ENDJOB` from someone with the authority — not the profile that started it. If
there is no such route, **let the query finish** rather than killing the client:
a killed client leaves the same work running with nobody watching it.

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

  **MIMIX SETS `OBJAUD(*CHANGE)` ON EVERYTHING IT REPLICATES, and a large
  share of `QAUDJRN`'s volume is MIMIX's by design (2026-09-21).** Objects
  that are not journaled to a user journal (user spaces, data areas without
  advanced journaling, programs …) are replicated by reading the system audit
  journal, so MIMIX needs the `ZC`/`CO`/`DO`/`OW` entries and sets the
  auditing itself — measured: `MIMIXOWN`/`OMSRV01` writing `AD` (auditing
  changed) entries on new `WMSXTLT` user spaces every hour. Consequences:
  - **`CHGOBJAUD … OBJAUD(*NONE)` on a replicated object is reverted by
    MIMIX and shows up in its `#OBJATR` audit.** It is not a change you can
    make on the box; it is a data group object entry setting (Midrange).
  - **"Nothing on the box consumes the audit journal" is false as a blanket
    claim** — MIMIX does, through the API, exactly the blind spot noted above.
    What is true: nothing reads it for *security*.
  - **Before touching auditing on any object, check `MIMIX.MXLIBREPP`** for
    its library (`CAST(CONTAINER_NAME AS CHAR(10) CCSID 37)`,
    `CONTENT_INCLUDED`); the report refreshes nightly (~03:00). It also
    answers "is my library replicated?" without the MSP — `SECAUDIT` is not.
  - Journaled database files still carry `OBJAUD(*CHANGE)` and emit a `ZC`
    on every open for update — 133k an hour from two config files rewritten
    continuously. Their *data* goes by the user journal; whether the object
    entry can carry `OBJAUD(*NONE)` for such files is a Midrange question.
- **BRMS** — backup, and a possible route to *old versions of source*, which the
  box itself does not keep.

## Four more, measured 2026-09-21 (proj-security, reading the menu system)

- **Some source files are CCSID 65535 and come back as EBCDIC hex.** `XTLSRC`
  is one: `SELECT SRCDTA` prints `4F4040…` and every `LIKE` filter silently
  matches nothing. Cast on the way out —
  `CAST(SRCDTA AS CHAR(100) CCSID 37)` — and filter on the cast. `I93SRC` and
  `I93CSTMSRC` read fine without it, so check the first line before trusting
  a grep.
- **`DSPCMD … OUTPUT(*PRINT)` fails with `CPF9871` inside a `QZDASOINIT` job**
  (panel-group processing needs a display session). `QSYS2.COMMAND_INFO` does
  not exist on this 7.3 either. To learn a command's processing program from
  SQL you are stuck; read the CPP from the command source member or ask
  someone at a green screen. `DSPPGMREF` on the *program* you suspect is the
  CPP still works.
- **`SQL7011 … not table, view, or physical file` means you hit a display
  file.** A `*FILE` referenced by a program with usage 7 and no
  `SYSTABLESTAT` row is a `DSPF`; the data you want is in the *other* files
  the program reads. On this estate a menu's options were in a join logical
  file, not in the display file that shares its name.
- **`OBJECT_PRIVILEGES` on a `*LIB` shows a limited profile only its own
  group's row.** As `CCSEC`, four libraries returned one `CCGRP *USE` row
  each and no `*PUBLIC` row at all, while other libraries showed `*PUBLIC`
  normally. Absence of a `*PUBLIC` row is not `*EXCLUDE`; it is *not visible
  to this profile*. Read library authorities as `SECAUDIT`.
- **The session's own permission layer can refuse a network probe of a
  production host** (an `openssl s_client` to `xtl400.xtl.com` was denied as
  a production read while every SQL statement was allowed). Do not route
  around it; hand the probe to Doug's terminal (`! openssl …`) and record
  that it was not run.

## `RUNSQL` rejects `SELECT` and `VALUES`, and a job can fill every table and still fail (2026-09-21)

- **`RUNSQL SQL('VALUES (…)')` and `RUNSQL SQL('SELECT …')` fail with
  `SQL0084` *"SQL statement not allowed"*, every time.** Only statements
  that do not return a result set are accepted. A conditional failure from
  CL therefore cannot be a `VALUES (CASE … RAISE_ERROR …)`; the idiom that
  works is a **one-row `UPDATE` whose `WHERE` is a `CASE` around
  `RAISE_ERROR`** — `CASE` evaluates `THEN` only when the condition holds,
  so a clean state updates zero rows and a dirty one raises `SQL0438` with
  your text. Test both branches by hand over JDBC before compiling.
- **A scheduled job can land every metric and still end abnormally.** The
  weekly security collector did exactly that on every run: the failing
  statement was the last one, after all the inserts. The tables looked
  complete, `SECMETRIC` said 84 metrics, and Robot said *"Job ended
  abnormally"* — and nobody read Robot. **Verify a job by its completion
  message in the job log or `ROBOTLIB.RBTMSG` (`CMMSEV = 'T'` is
  terminated), never by the data alone.**
- **`QSYS2.JOBLOG_INFO` on a completed job returns `SQL0443` *"job log not
  displayed because job completed execution"*.** Read the held `QPJOBLOG`
  spooled file instead: `SPOOLED_FILE_INFO(USER_NAME => …)` joined
  `LATERAL` to `SYSTOOLS.SPOOLED_FILE_DATA` — the lateral join works on
  7.3 and lets one statement grep every listing a user produced.
- **`ifsput` writes the stream file with CCSID 1200 (UTF-16).** Anything
  that reads the file by its CCSID attribute — `CRTBNDCL SRCSTMF`, `CPYFRMSTMF`
  without `STMFCCSID` — gets one unreadable record and a `CPD0018 … not
  valid` on line 1 followed by "no ENDPGM". `CHGATR OBJ('/path')
  ATR(*CCSID) VALUE(1208)` before compiling. `put400` does not have this
  problem because it passes `STMFCCSID(1208)` itself.
- **Syntax-check CL without touching a library: compile it into `QTEMP`.**
  `ifsput` the source, `CHGATR` it to 1208, `DECLARE GLOBAL TEMPORARY TABLE
  SESSION.<file>` for any `DCLF` it needs (a plain `CREATE TABLE QTEMP.x`
  fails `SQL7008` over JDBC), `OVRPRTF FILE(QSYSPRT) HOLD(*YES)
  OVRSCOPE(*JOB)`, then `CRTBNDCL PGM(QTEMP/x) SRCSTMF('/path')` and read
  the `x` spooled file. All of it vanishes at disconnect.
- **`DCLF … OPNID(Q)` prefixes every field as `&Q_…`, and CL variable names
  are 10 characters plus `&`.** A column named `REVERTED_TS` becomes an
  undeclared `&Q_REVERTED_TS` (`CPD0727`). Keep driver-table column names
  to eight characters.
- **`QSYS2.PROGRAM_INFO` includes `*SRVPGM` rows**, and `PROGRAM_LIBRARY
  <> 'QSYS'` is not the same filter as `PROGRAM_OWNER <> 'QSYS'`: 965 IBM
  programs owned by `QSYS` live in `QGPL`, `QUSRSYS` and friends. Say which
  exclusion a count used.

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

**⚠ THERE IS A SWITCH FOR THIS, AND NOT KNOWING IT COST A DAY (2026-09-21).**
It is a property of the **output queue**, not of the file:

```sql
SELECT OUTPUT_QUEUE_LIBRARY_NAME, OUTPUT_QUEUE_NAME, DISPLAY_ANY_FILE,
       OPERATOR_CONTROLLED, AUTHORITY_TO_CHECK
  FROM QSYS2.OUTPUT_QUEUE_INFO WHERE OUTPUT_QUEUE_NAME = '<outq>';
```

`DISPLAY_ANY_FILE` (`DSPDTA`) defaults to **`*NO`**, and then only the owner
reads the data. `CHGOUTQ OUTQ(lib/q) DSPDTA(*YES)` lets **anyone with `*USE`
on the queue** read any file on it. `QUSRSYS/QEZJOBLOG` — where job logs land
— is `*NO` on this estate, which is why a failed job's log is unreadable to
everyone but its owner.

**MOVING A SPOOLED FILE TO A QUEUE YOU CONTROL DOES NOT HELP.** Tested: the
file kept its owner and still returned zero rows. Only `DSPDTA(*YES)` on the
queue, or owning the file, works.

**So give any application you schedule its own output queue with
`DSPDTA(*YES)`**, and have the job run under a profile you can connect as.
Otherwise the first-hand account of every failure is behind a wall — a
`MAPCOLL` failure took a day to diagnose purely because its job log could not
be read, and was solved in seconds once it could.

### Diagnosing a CL command that fails through QCMDEXC

`CPF0006 Errors occurred in command` **names no parameter and reads exactly
like a syntax error.** It is a summary; the real message is in the job log.
Do not start rewriting the command string — it cost an hour on 2026-09-21,
where the truth was `CPD0032 Not authorized to command CRTJOBD`.

**Reproduce into `QTEMP` and read the job log on the same connection.**
`QTEMP` is job-scoped (ADR 0007 permits it), so this creates nothing:

```sql
CALL QSYS2.QCMDEXC('CRTJOBD JOBD(QTEMP/TESTJOBD) ...');
SELECT MESSAGE_ID, SEVERITY, CAST(MESSAGE_TEXT AS VARCHAR(150))
  FROM TABLE(QSYS2.JOBLOG_INFO('*'))
 WHERE MESSAGE_ID IS NOT NULL
 ORDER BY ORDINAL_POSITION DESC FETCH FIRST 8 ROWS ONLY;
```

`sql400` runs both on one connection, so `JOBLOG_INFO('*')` sees the job that
just failed. The `CPD`/`CPF` pair above the `CPF0006` is the answer.

**And commands are objects with authority of their own.** Measured on this
box: `QSYS/CRTOUTQ` is `*PUBLIC *USE` but **`QSYS/CRTJOBD` is `*PUBLIC
*EXCLUDE`** — while `QSYS/CHGJOBD` is `*USE`. You may not create a job
description here, but you may change any existing one. Check before assuming a
command is available:

```sql
SELECT SYSTEM_OBJECT_NAME, AUTHORIZATION_NAME, OBJECT_AUTHORITY
  FROM QSYS2.OBJECT_PRIVILEGES
 WHERE SYSTEM_OBJECT_SCHEMA = 'QSYS' AND OBJECT_TYPE = '*CMD'
   AND SYSTEM_OBJECT_NAME IN ('CRTJOBD','CRTOUTQ','CHGJOBD');
```

**`+` is CL SOURCE continuation and must never appear inside a `QCMDEXC`
string** — the analyser parses it when reading a source line; `QCMDEXC` gets a
finished string, so `+` and the newline land inside the command. One unbroken
literal, always. (In ACS *Run SQL Scripts* a CL command needs the `CL:`
prefix and a trailing `;` — without it you get `SQL0104 Token CRTJOBD was not
valid`.)

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

## ⚠ `GET DIAGNOSTICS` NEVER RETURNS WHY A `QCMDEXC` COMMAND FAILED (2026-09-24)

**Any CL command run through `QSYS2.QCMDEXC` fails as `SQL0443`, message text
*"Trigger program or external routine detected an error."*** That is SQL's
wrapper. It names no object, no library, no authority, and it is **identical for
every possible cause** — not authorised, does not exist, wrong type, out of
space.

So `GET DIAGNOSTICS CONDITION 1 ... = MESSAGE_TEXT` inside a handler gives you
nothing to classify on, and **any `CASE` that tests that text for a `CPF` id can
never match.** This is not theoretical: `proj-as400-codemap` shipped two
procedures with exactly that classifier. One (`MAPSRCP`) found the trap and
carries a twelve-line warning about it; the other (`MAPREFH`) was written later,
tested `V_ETXT LIKE '%CPF3033%'`, and was dead from the day it was written — all
50 of its blocked libraries recorded that one sentence and none was
distinguishable from any other.

**The cause is the message UNDER the wrapper in the job log:**

```sql
SELECT SUBSTR(RTRIM(MESSAGE_ID) CONCAT ' ' CONCAT COALESCE(MESSAGE_TEXT,''),1,200)
  FROM TABLE(QSYS2.JOBLOG_INFO('*'))
 WHERE MESSAGE_ID IS NOT NULL
   AND MESSAGE_ID NOT LIKE 'SQL%'     -- SQL0443, the outer wrapper
   AND MESSAGE_ID <> 'CPF0001'        -- "Error found on X command" — a SECOND
                                      -- wrapper that also names nothing
 ORDER BY ORDINAL_POSITION DESC
 FETCH FIRST 1 ROW ONLY;
```

- **Skip every wrapper, not just the outer one.** `CPF0001` (command failed) and
  `CPFA097` (object not copied) are each a second layer that says only *something
  went wrong*. Skip the SQL layer alone and you classify every failure as
  "command failed".
- **Wrap the job-log read in its own `CONTINUE HANDLER`** — you are already
  inside a failure path and a second exception there loses the first.
- **Keep the wrapper text when the job log yields nothing.** An unexplained
  failure must still read as a failure; blanking it makes *could not tell* look
  like *nothing there*.
- **Run the command by hand when a classifier looks wrong.** Interactively the
  box says `CPF3033 Object *ALL in library I93FILE of type PGM not found` — the
  real answer was always one manual run away.

**The generalisation, which is the expensive part:** this trap was found, written
up and defeated in one file of an application, and a sibling file twenty
directories away shipped it anyway. **A trap beaten in one program is not beaten
in the codebase.** When you fix one of these, grep the whole tree for
`GET DIAGNOSTICS` and for `MESSAGE_TEXT`.

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

## Function usage: the entitlement registry most people never look at (2026-09-21)

Not on IBM's authority flowchart at all — a **separate registry**, which is
why it is the one control type measured able to survive universal `*ALLOBJ`.

```sql
SELECT FUNCTION_ID, ALLOBJ_INDICATOR, DEFAULT_USAGE, FUNCTION_TYPE
  FROM QSYS2.FUNCTION_INFO WHERE FUNCTION_ID LIKE 'QIBM_DB%';
```

- **The view is `QSYS2.FUNCTION_INFO`** (plus `QSYS2.FUNCTION_USAGE` for the
  per-user grants). It is **not** `FUNCTION_USAGE_INFO`, which does not exist
  on 7.3 and is what current IBM documentation will lead you to.
- The column is **`ALLOBJ_INDICATOR`** (`USED` / `NOT USED`), not
  `ALL_OBJECT_AUTHORITY`.
- `ALLOBJ_INDICATOR = USED` means *"a user with `*ALLOBJ` is always allowed to
  use the function"* — i.e. the gate is off for exactly the people you care
  about. `NOT USED` means they are checked like anyone else. It is settable:
  `CHGFCNUSG FCNID(x) ALLOBJAUT(*NOTUSED)`.
- On XTL 2026-09-21: `QIBM_DB_ZDA` (ODBC/JDBC, and port 8478) and
  `QIBM_DB_DDMDRDA` ship `USED`/`ALLOWED` — open. `QIBM_DB_SECADM`,
  `QIBM_DB_SQLADM`, `QIBM_DB_SYSMON` ship `NOT USED`/`DENIED`.
- **Restricting needs three changes together** — `DEFAULT_USAGE(*DENIED)`,
  `ALLOBJAUT(*NOTUSED)`, and an allow-list. Any one alone is a no-op; the
  first two without the third cut off every client at once.
- **Authority Collection cannot see function usage** (7.3 Security Reference
  ch.10 exclusions). So the usual measure-then-change approach does not work
  here; you need the connection census from `NETSTAT_JOB_INFO` instead.

## Reading the service surface: four views and one lie (2026-09-21)

- `QSYS2.NETSTAT_INFO` — what listens (`TCP_STATE='LISTEN'`).
- `QSYS2.NETSTAT_JOB_INFO` — who is connected **right now**, and which job and
  profile. Note it has **no `TCP_STATE` column**; that is `NETSTAT_INFO`.
- `QSYS2.HTTP_SERVER_INFO` — per-instance **cumulative** counters.
- `QSYS2.SOFTWARE_PRODUCT_INFO` — installed products, `RELEASE_LEVEL`,
  `SUPPORTED`.

**The lie: a connection snapshot cannot tell "unused" from "idle right
now".** On XTL, ports 80 and 2001 showed zero open connections and read as
dormant; `HTTP_SERVER_INFO` showed 71,853 and 1,439 connections since IPL,
both at **zero SSL**. **Where a service keeps its own counters, read those.**

**And `SUPPORTED = NO` is not a signal on an out-of-support release** — all
173 installed options on XTL's 7.3 report it. The discriminating measure is
`RELEASE_LEVEL` below the OS: 21 products, including `5722VI1` Content
Manager at `V5R3M0`.

**Identifying an unnamed port:** join `NETSTAT_JOB_INFO` on `LOCAL_PORT` and
read `JOB_NAME` — the daemon names it. That resolved four unknowns in one
query, and showed that 8477/8478/8479 are not separate daemons at all
(`QPWFSERVSD`, `QZDASRVSD`, `QNPSERVD` — the file, database and print
servers under extra port numbers).

## Is this authority IBM's or did someone here set it? (2026-09-21)

Recurring question the moment you find an object with surprising authority —
a `*PUBLIC *EXCLUDE` command, a closed library, a restricted source file. The
answer changes the finding completely: shipped state is not evidence that
anyone at XTL made a decision.

**The only reliable answer is the manual, not the box.** IBM ships a defined
set: *Appendix C, Commands shipped with public authority `*EXCLUDE`* in the
Security Reference for the matching release. Ask the RAG for it —
`mcp__kb-ibm400-docs__ask_about_as400`, naming the specific objects. It is a
long table and the chunks come back partial, so ask about **the objects you
care about by name** rather than trying to retrieve the whole list.

**Two things on the box that look like they would answer it and do not:**

- **Object change timestamps.** `CHANGE_TIMESTAMP` from
  `QSYS2.OBJECT_STATISTICS` does not record authority changes distinguishably,
  and on XTL every `QSYS` command carries the same value — 2024-12-05, three
  seconds wide, a PTF apply. Uniform timestamps mean the OS was serviced, not
  that authority is untouched.
- **A private-authority query under a restricted profile.** IBM ships private
  grants to `QPGMR`/`QSYSOPR`/`QSRV`/`QSRVBAS` alongside the `*EXCLUDE`, so
  their presence would be the tell — but `OBJECT_PRIVILEGES` returns **zero
  rows** for them under `CCSEC`. That is authority filtering, not absence. Run
  it under `SECAUDIT` or do not run it.

**The tell that you are being filtered rather than reading truth:**
`OBJECT_STATISTICS` returns **blank rows** — object name present, owner and
timestamps empty — for objects the profile lacks `*OBJOPR` on. If the objects
you are asking about come back blank while their neighbours come back full,
you are measuring your own authority, not theirs.

**Worked case:** `CRTJOBD` is `*PUBLIC *EXCLUDE` while `CHGJOBD` and
`DLTJOBD` are `*USE`, which reads like someone hardened one and forgot the
others. Nobody did — all of `CRTAUTHLR`, `CRTCLS`, `CRTJOBD`, `CRTPFRDTA`,
`CRTSBSD` are in Appendix C and none of the `CHG*`/`DLT*` ones are. That is
every IBM i in the world. `proj-security` `#40`.

## Getting source OUT of members in bulk: `CPYTOSTMF`, not row reads (2026-09-21)

**If you are reading more than a handful of members, stop reading rows.**
Measured on the primary, same members three ways:

| Mechanism | Per member |
|---|---|
| A JVM-per-member helper (`src400`) from a laptop | ~1,700 ms |
| `CPYTOSTMF` through `QCMDEXC` over JDBC | ~82 ms |
| **`CPYTOSTMF` inside an SQL procedure on the box** | **21.7 ms** |

A sustained batch run held ~38 members/second across mixed libraries. That is
the difference between "the estate is a twelve-hour job" and "the estate is
forty minutes", and it is why any bulk source work belongs in a procedure on
the box rather than in a loop on your machine.

```
CPYTOSTMF FROMMBR('/QSYS.LIB/<LIB>.LIB/<FILE>.FILE/<MBR>.MBR')
          TOSTMF('/path/<MBR>.rpgle')
          STMFOPT(*REPLACE) STMFCCSID(1208) DBFCCSID(<page>) ENDLINFMT(*LF)
```

It also **renders the text form for you**: UTF-8, one line per record, LF
endings, **trailing blanks stripped**. Verified byte for byte against
record-faithful captures — six members, 3,244 lines, zero differences. So you do
not need code in the middle, and the conversion is the machine's, not yours.

**⚠ `DBFCCSID(*FILE)` FAILS OUTRIGHT on a CCSID 65535 source file** —
`CPFA097 Object not copied`. That is the *good* failure and the opposite of the
JDBC path, where 65535 silently returns EBCDIC as hex and looks like a width
bug. **Read each source file's declared CCSID and pass it explicitly**; for
65535 you are choosing 37, and that is a choice to record, not a default.

**A source file is not identified by its name.** Test `SOURCE_TYPE IS NOT NULL`
in `SYSPARTITIONSTAT`. On XTL, `TRUBASE2` (7,777 members), `COMPILES` (6,411),
`KARLADDS`, `SAVESRC`, `PROTOTYPES`, `LASTSRC` and `QRPGLEBCK` all hold source —
a `Q%SRC` filter misses over 20,000 members.

**Member names repeat inside a library.** 9,654 names appear in two or more
source files of the same library on XTL. Key anything you build on
library + file + member, and never flatten a tree to library/member.

## Git runs on the box — but it cannot use threads (2026-09-21)

`/QOpenSys/pkgs/bin/git` is **2.26.2** and `init` / `add` / `commit` /
`rev-parse` all work from a `QSH` called inside an SQL server job, writing to
the IFS, as an ordinary profile with no special authorities. No install, no PTF.

Two things it needs:

- **`HOME` must be set** in the QSH environment. A profile with no home
  directory (a batch identity typically has none) otherwise fails.
- **⚠ THE PORCELAIN DOES NOT SCALE HERE AT ALL. USE PLUMBING.** At 1,434 files
  `git add` failed with `unable to create threaded lstat`, and
  `-c core.preloadIndex=false -c index.threads=1` got past that one. **At 88,912
  files it fails again on a different threading path** and no configuration
  reaches it:

  ```
  fatal: unable to create lazy_dir thread: Resource temporarily unavailable
  ```

  `git add -A`, `git add -- <one path>` and `git status` all fail this way once
  the index is large. **What works, against the same 88,912-entry index:**

  ```
  git update-index --add --remove -- <paths>     # batch the paths
  git write-tree                                 # -> tree sha
  echo "msg" | git -c user.name=X -c user.email=Y commit-tree $T -p HEAD
  git update-ref HEAD $C
  ```

  The whole chain runs in **2.5 seconds** where `add -A` took twenty minutes,
  so this is the right answer even where the porcelain works: you almost always
  know which paths changed, and making git rediscover it costs work
  proportional to the repository rather than to the change.

  **Ruled out as causes, each by measurement** — record these so nobody
  re-tests them: the job type (a batch job under its own JOBD fails
  identically), `SBMJOB ALWMLTTHD(*YES)`, the class's `MAXTHD` (`*NOMAX` on the
  one measured), `PASE_THREAD_ATTR_STACKSIZE` at three values,
  `GIT_TEST_INDEX_THREADS=1`. A throwaway 2,500-file repository in the same job
  stages fine, so it is **scale-dependent and unexplained**.

- **`commit-tree` needs an identity or it fails outright** — "empty ident name".
  Pass `-c user.name` / `-c user.email` rather than configuring a dotfile on the
  box that nothing versions.

Note `git init` is idempotent, and git 2.26 predates the `safe.directory`
ownership check, so a repository written by one profile and read by another
needs no exception.

## `SBMJOB` inherits YOUR library list, not the job description's (2026-09-21)

`INLLIBL` defaults to **`*CURRENT`**. Hand-submitting an application job from a
5250 session therefore drags your interactive library list into it, and on this
estate that fails as:

```
User <batch profile> not authorized to library XTLBC
```

— naming a library that has nothing to do with the job, which is the second time
XTL's library lists have produced a message pointing away from the cause.

```
SBMJOB CMD(...) JOB(X) JOBD(<lib>/<jobd>) USER(*JOBD) INLLIBL(*JOBD)
```

**`USER(*JOBD)` matters just as much**: `USER` defaults to `*CURRENT`, so
without it the job runs as *you* and fails on anything the batch profile owns.
**Robot is unaffected** — it submits using the job description — so this is a
fact about hand-submitting, not about the scheduled entry. Prove a scheduled job
by submitting it with its own JOBD, never by calling the procedure over JDBC:
a JDBC call exercises none of the library list, output queue or identity that
actually break.

## SQL PL on 7.3: a zero-row `UPDATE` raises `NOT FOUND` (2026-09-21)

The trap that makes a cursor loop run **exactly once** and report success.

`DECLARE CONTINUE HANDLER FOR NOT FOUND SET V_DONE = 1` is the standard
fetch-loop idiom. But `NOT FOUND` (SQLSTATE `02000`) is *also* raised by an
`UPDATE` or `DELETE` inside the loop body that matches no rows — and an
upsert's `UPDATE` matches nothing for every row being inserted for the first
time, i.e. every row of a first run.

Measured: 10 members screened, **1 copied**, outcome `READ`, no error anywhere.

```sql
mbrloop: LOOP
  FETCH C INTO ...;
  IF V_DONE = 1 THEN LEAVE mbrloop; END IF;
  ...body, which may raise NOT FOUND...
  SET V_DONE = 0;        -- ⚠ AT THE END OF THE BODY
END LOOP mbrloop;
```

**Resetting immediately after the `FETCH` check does not work** — the body then
sets the flag again before the next `FETCH` — and that is the obvious first fix.
The tell was a run log recording *members screened* and *members copied*
separately and the two disagreeing, which is an argument for always recording
both.

### ⚠ AND THE SAME DEFECT SITS BEFORE THE LOOP, WHERE IT IS EASIER TO MISS (2026-09-22)

A zero-row `DELETE` or `UPDATE` **between the handler declaration and the
`OPEN`** raises `NOT FOUND` too, sets the done-flag, and the loop then leaves on
its **first** `FETCH` check having read nothing:

```sql
DELETE FROM ... WHERE <matches nothing>;   -- raises NOT FOUND, sets V_DONE
GET DIAGNOSTICS V_STALE = ROW_COUNT;
SET V_DONE = 0;                            -- ⚠ REQUIRED, and easy to omit
OPEN C;
```

Measured: a harvest reported *"0 harvested"* in **0.8 seconds** with 1,434
members waiting. The in-loop version at least runs once; this one produces a
clean, fast, confident nothing — and the pre-loop housekeeping statement that
matches nothing is the **normal** case on an incremental job, so it fails every
night rather than occasionally.

**Rule: reset the flag immediately before `OPEN`, not only at the end of the
body.**

### `sql400` cannot bind `OUT` parameter markers

`CALL LIB.PROC('A','B', ?, ?)` fails `SQL0313`, so **a procedure with `OUT`
parameters is not callable by hand at all** — and `RUNSQL` will not take
parameter markers either. Write a two-line wrapper procedure that declares the
locals and calls the real one, use it, then **drop it**: a test harness that
outlives its test is a permanent object somebody has to protect.

### ⚠ CAST ONCE, THEN WORK IN THE CAST TYPE — `SQL0802` type 7 (2026-09-22)

Touching a table function's **raw** column alongside a **cast** copy of it in
the same query raises `SQL0802` *"Data conversion or data mapping error … type 7
— DBCS or UTF-8 data that is not valid"* on rows that read perfectly well on
their own.

```sql
-- WRONG: L.LINE used raw for one test and cast for another
SELECT CAST(L.LINE AS VARCHAR(400) CCSID 1208), 
       CASE WHEN SUBSTR(L.LINE, 7, 1) = '*' THEN 1 ELSE 0 END
  FROM TABLE(QSYS2.IFS_READ_UTF8(...)) L
```

It presents as **"29% of these files are corrupt"** — a serious claim about the
data — and it is the query. Cast once in the innermost CTE and reference only
the cast column afterwards, including in `LIKE`, `SUBSTR` and `REGEXP_*`.

**And keep the whole pipeline in one CCSID.** Forcing the job to 37 with
`CHGJOB CCSID(37)` fails on any source that is not plain English — this estate
has French, Italian and Japanese source files and a non-ASCII byte in the
form-type column of hundreds of members. Declare the columns `CCSID 1208` and
cast literals into it (`CAST('^[A-Za-z]+' AS VARCHAR(20) CCSID 1208)`).

### ⚠ WHEN THE SHELL FIGHTS, THE ANSWER IS SQL (2026-09-22)

Five attempts to inventory a keyword across 9,470 mirrored members failed in the
PASE shell before the right instrument was used. Record these so nobody spends
the afternoon again:

| Attempt | Why it failed |
|---|---|
| `grep -rl --include=*.pf` | **`--include` is GNU-only**; AIX grep ignores it and `-r` is unreliable |
| `grep -o "REF([A-Z]*"` | **AIX grep has no `-o`.** Returns nothing, silently |
| `find … \| xargs grep -h \| awk -F"REF\\("` | Three layers of quoting — SQL → `QCMDEXC` → `QSH` → `awk` — mangle the separator |
| A shell script written to the IFS and run with `/QOpenSys/usr/bin/sh` | Ran, produced no output, left no error |
| `REGEXP_SUBSTR(txt, 'REF\\(([^)]*)\\)', 1, 1, '', 1)` | **`SQL0901` system error** (`CPF4204`) — the capture-group form is not safe here |

**What worked, in 2 m 21 s over the same 9,470 members:** `IFS_READ_UTF8` in a
`LATERAL` join with plain `LOCATE` and `SUBSTR`.

```sql
SELECT UPPER(SUBSTR(TXT, LOCATE('REF(', TXT) + 4,
             LOCATE(')', TXT, LOCATE('REF(', TXT)) - LOCATE('REF(', TXT) - 4))
  FROM lines WHERE TXT LIKE '%REF(%' AND TXT NOT LIKE '%REFFLD(%'
```

**`grep -c` on a single known file is the control worth running first** — it
proves the string is there and the shell can see it, which separates "my pattern
is wrong" from "this grep lacks that flag".

### Reading many members at once: `IFS_READ_UTF8` in a `LATERAL` join

```sql
SELECT M.MBRNAME, L.LINE_NUMBER, L.LINE
  FROM <member list> M,
       LATERAL (SELECT LINE_NUMBER, LINE
                  FROM TABLE(QSYS2.IFS_READ_UTF8(PATH_NAME => M.IFSPATH,
                                                 IGNORE_ERRORS => 'YES'))
                 WHERE LINE_NUMBER <= 40) L
```

- **`IGNORE_ERRORS => 'YES'` is accepted** and keeps one unreadable file from
  killing the statement.
- **The line-number filter is applied AFTER the read**, so cost is the whole
  file: **~30 ms** for small CL members, **~200 ms** for large RPG. 90,000
  members is hours — a submitted job, not a session.
- **A set-based INSERT over a whole source file is the wrong grain.** These
  routines run `COMMIT(*NONE)`, so one poison member kills the statement *and
  leaves the rows already inserted committed* — a partial result that looks
  complete. Loop per member with a `CONTINUE` handler, and **record the
  unreadable ones as rows** rather than as absence.

## Two more facts about this estate (2026-09-21)

- **The IFS root `/` is `*PUBLIC *RWX`** on the primary. Any profile can create
  a top-level directory; no grant needed. Consistent with the estate's broader
  `*PUBLIC` posture and reported to `proj-security`.
- **Ports 22 (SSH) and 445 (NetServer) are LISTENING**, alongside the host
  servers documented above. Whether ZPA publishes either is **untested** — and
  remember the reachability probe lies on this path, so settle it with the
  listener table plus a ZPA question, not with `nc` or `openssl`.

## A batch job runs at CCSID 65535 on this estate — and that is invisible interactively

`QCCSID` is **65535**, and profiles taking `*SYSVAL` inherit it. So every SQL
variable in a **submitted** job defaults to 65535, and assigning UTF-8 to one
fails:

```
SQL0332 Character conversion between CCSID 1208 and CCSID 65535 not valid
```

**A JDBC job negotiates a real CCSID with the client, so this cannot be
reproduced from `sql400` and every interactive test passes.** It cost a
55-minute batch run that did all its work correctly and then reported itself
FAILED while reading its own output back.

Two fixes, and using both is reasonable because they protect different things:

```sql
CALL QSYS2.QCMDEXC('CHGJOB CCSID(37)');            -- the whole job
... CAST(LINE AS VARCHAR(300) CCSID 37) ...        -- the one statement
```

**To reproduce a batch-CCSID bug from an interactive session**, set it first:
`CALL QSYS2.QCMDEXC('CHGJOB CCSID(65535)')`. That is how this one was confirmed
rather than guessed at, and it is the cheapest way to test anything that will
run under the scheduler.

## Prove a scheduled job by SUBMITTING it, never by calling it

Calling a procedure over JDBC exercises the SQL and **nothing that actually
breaks**: not the library list, not the identity, not the output queue, not the
job's CCSID. All four have caused failures on this estate that looked like code
problems.

```
SBMJOB CMD(RUNSQL SQL('CALL LIB.PROC()') COMMIT(*NONE)) JOB(X)
       JOBD(<lib>/<jobd>) USER(*JOBD) INLLIBL(*JOBD)
```

And when reading the scheduler's own tables back afterwards — **do it**. A
one-character typo in a Robot command (`XTLPGMAP` for `XTLPGMMAP`) fails with
`SQL0204` *before* the procedure runs, so **no run-log row is written at all**
and every health check built around that table sees a quiet night. Read
`ROBOTLIB.RBTCMD` back after any change:

```sql
SELECT CMD_SET_OID, CMD_LINE_NUMBER, CAST(CMD_STRING AS VARCHAR(120))
  FROM ROBOTLIB.RBTCMD
 WHERE UPPER(CAST(CMD_STRING AS VARCHAR(250))) LIKE '%<YOURPROC>%';
```

**And Robot's job name is `ROBOT_JOB_NAME`, not `JOB_NAME`.** `RBTROB.JOB_NAME`
holds something else entirely — a session read it and reported a scheduled job
was named `455562/QUSER/QZDASOINIT`, then recommended renaming it. Its real
name was fine.

## ⚠ QTEMP DIES WITH THE CONNECTION, AND EVERY `sql400` CALL IS A NEW CONNECTION

**An object created by one `sql400` invocation is gone before the next one
runs.** This is the documented behaviour of QTEMP — job-scoped — but the trap is
that a shell loop *looks* like one session:

```bash
sql400 "CREATE ALIAS QTEMP.A FOR LIB.SRCF(MBR)"   # job 1 ... and job 1 ends here
sql400 "SELECT * FROM QTEMP.A"                    # job 2: SQL0204, A not found
```

**It fails as `SQL0204 … type *FILE not found`, which reads like a missing
object, not a missing session.** `kb-xtl400`'s `source_sync.py history` was built
this way and **never produced a single output in its entire existence** — the
failure was blamed on an unrelated stdout defect, fixed, and the command still
returned nothing. Found 2026-09-22 only by running it.

**Put every statement that shares QTEMP into ONE `sql400` call**, separated by
`;` — the tool splits on `;` and runs the parts on one `Statement`, so the
connection and therefore QTEMP are shared:

```bash
sql400 "CREATE ALIAS QTEMP.A FOR LIB.SRCF(MBR); SELECT SRCSEQ, SRCDAT FROM QTEMP.A"
```

Nothing needs dropping afterwards — QTEMP dies with the connection, so a stale
alias from a crashed run is impossible. Parsing the output means skipping the
`rows: N` lines the DDL statements emit before the SELECT's header.

This applies to **anything** job-scoped, not just aliases: `QTEMP` outfiles from
`DSPFD`/`DSPOBJD`/`DSPPGMREF`, `OVRDBF`, `ADDLIBLE`. `cl400` is different — it
runs several commands in **one** `CommandCall` job by design, which is why
`ADDLIBLE`/`OVRDBF` work there and not here.

## `sql400` splits on `;` blindly — inside comments AND inside string literals

A `.sql` file with a semicolon in a `--` comment is cut in half at that point,
and the halves fail with errors pointing at the following token. Four analysis
queries in `proj-as400-codemap` had this and produced confident-looking partial
output. Keep semicolons out of comments in anything meant to be piped in whole.

**It breaks quoted strings too, and that half is not obvious.** A literal like
`'Rising is healthy; a fall is a reset'` is cut mid-string and reports
`SQL0010 String constant not delimited` — an error that points at the string
rather than at the tool. `RUNSQLSTM` parses properly and is unaffected, so this
breaks **only the by-hand test**, which is the test you need before scheduling
anything. Keep `;` out of comments *and* literals in any member you will also
run through `sql400`.

**`RAISE_ERROR` inside a `SELECT` does work through `sql400`** (unlike through
the `RUNSQL` CL command, which rejects `SELECT`/`VALUES` outright) — useful for
testing both branches of a guard before compiling it into a job:
`SELECT CASE WHEN <cond> THEN RAISE_ERROR('85002','msg') ELSE 'OK' END FROM SYSIBM.SYSDUMMY1`.
Test the failing branch, not just the passing one.

## ⚠ ILE STAMPS THE LIBRARY IT RESOLVED A SERVICE PROGRAM TO — AND NO LIBRARY LIST OVERRIDES IT LATER (2026-09-24)

**The trap that ends a migration halfway.** You move an application to a new
library, rebuild it there, set the run-time library list correctly, prove the
list is right — and the program still runs the OLD code.

Measured on `proj-imaging`, 2026-09-24:

```sql
SELECT PROGRAM_NAME, BOUND_SERVICE_PROGRAM, BOUND_SERVICE_PROGRAM_LIBRARY
  FROM QSYS2.BOUND_SRVPGM_INFO WHERE PROGRAM_LIBRARY = 'DOUGIMGP';
-- XTLFILERJ | XTLFILER | DOUGIMG     <-- rebuilt in DOUGIMGP, bound to DOUGIMG
```

`DOUGIMGP/XTLFILERJ` was created **after** `DOUGIMGP/XTLFILER` existed, with
`DOUGIMGP` first on the build's library list, and still bound to `DOUGIMG`. At
run time it activated the old build — which was SQL-bound to the old library —
and every pass died with `SQL0204 <table> in <old library> not found`.

**`BOUND_SERVICE_PROGRAM_LIBRARY` is the fact. Read it after every build into a
new library**, the same way you read `OBJCREATED` instead of the completion
message:

- `*LIBL` — resolved at **activation**, the library list decides. Fine.
- a **library name** — nailed at bind time. **Nothing downstream changes it.**

Both occur in one application: on the same estate `GETDOCPTH` was `*LIBL` while
third-party `AOS_V1.0` service programs were qualified. **So "ILE binds service
programs at compile time" is conditional, not absolute** — it records the
library *as specified*, and `*LIBL` is a legal specification.

**Where it comes from is the binding directory, not the library list.**
`ADDBNDDIRE` records a qualified library per entry, so a `BndDir` carried over
from the old library points at the old library forever. Check it before blaming
anything else:

```
CL: DSPBNDDIR BNDDIR(<lib>/<bnddir>) OUTPUT(*OUTFILE) OUTFILE(<lib>/ZZBND);
```
then read the outfile — **get the column names from `SYSCOLUMNS` first**;
`BNOTYP` is not one of them.

**The order to check, cheapest first:** the binding directory's entries → then
`BOUND_SRVPGM_INFO` on the built object → and only then the library list. A
session spent two builds on the library list because the list was the visible
thing and the binding directory was not.

### ⚠ AND THE CURRENT LIBRARY BEATS `ADDLIBLE POSITION(*FIRST)` — ALWAYS

**This is why the binding directory kept being the old library's even after
the list was fixed.** The current library is searched **before** the user
portion, so no `ADDLIBLE ... POSITION(*FIRST)` can get in front of it.
`CCIMG`'s `CURRENT_LIBRARY_NAME` is `DOUGIMG`, so an unqualified
`BndDir('XTLIMGBND')` in an H spec resolved to `DOUGIMG`'s copy — whose
entries are qualified `DOUGIMG` — on every build, and stamped the old library
into **fifteen** programs.

Proved 2026-09-24 by elimination, and the control is what makes it a
measurement: with `DOUGIMG/XTLIMGBND` **renamed away** and nothing else
changed, the identical `CRTBNDRPG` bound `DOUGIMGP`.

```sql
SELECT AUTHORIZATION_NAME, CURRENT_LIBRARY_NAME FROM QSYS2.USER_INFO
 WHERE AUTHORIZATION_NAME = '<the build profile>';
SELECT TYPE, ORDINAL_POSITION, SYSTEM_SCHEMA_NAME   -- inside the job itself
  FROM QSYS2.LIBRARY_LIST_INFO ORDER BY TYPE, ORDINAL_POSITION;
```

- **Any script that reorders the list must also set the current library** —
  `CHGCURLIB CURLIB(<target>)`, or `CURLIB(*CRTDFT)` for none, which is the
  honest choice when the list is meant to be the only switch.
- **A job description has no `CURLIB` parameter.** `INLLIBL` on the JOBD says
  nothing about the current library; it comes from the **user profile**, so a
  scheduled job inherits it however carefully the JOBD was built.
- **⚠ A library-list trace filtered to `TYPE = 'USER'` cannot see this, and
  that is how it survived.** XTL's filer logged
  `libl: DOUGIMGP DOUGIMGF ROBOTLIB` on every pass and it was read as proof
  the list was right — while `DOUGIMG` sat in front of all three. **Log
  `CURRENT` and `USER`, or the trace is evidence for a claim it cannot
  support.**

## ⚠ `ADDLIBLE` ON A LIBRARY ALREADY IN THE LIST FAILS, AND YOUR `MONMSG` HIDES IT (2026-09-24)

`ADDLIBLE LIB(X) POSITION(*FIRST)` where `X` is already on the list raises
`CPF2103` and **leaves it exactly where it was**. The idiomatic
`MONMSG MSGID(CPF2103)` then swallows it, so the code reads as "X is now first"
and X is still 32nd.

That cost two identical failed builds: `AOS_V1.0` was added `*FIRST` to beat
eleven other copies of a `/copy` prototype, stayed at position 32, and the build
failed the same way twice.

**IBM says this outright** — *Security Reference*, "Recommendations for the user
portion of the library list": *"If the library is already on the library list,
but you are not sure if it is at the beginning of the list, **you must remove
the library and add it**."*

```
RMVLIBLE   LIB(X)
MONMSG     MSGID(CPF2104)
ADDLIBLE   LIB(X) POSITION(*FIRST)
MONMSG     MSGID(CPF2103)
```

**And the reason position matters at all:** twelve libraries on this estate hold
a `QPROTOSRC(SO_SORTPR)` — `AOS_V1.0`, `DMI`, `DSNLOGSRC`, `ED`, `EI400`,
`LOGSRC`, `MVMSGS`, `MVSEI`, `TMMI`, `TS`, `VHOS40`, `VHSEI` — **and they are
not the same prototype.** An unqualified `/copy` takes whichever the list
reaches first, so a build that works from a short library list fails from a
normal one with `RNF5406 ... fewer parameters than the prototype`. A build whose
correctness depends on the caller's library list is **reproducible by accident**.

## Identifying a client by IP — the file server names the host, the others do not

**`CPIAD12` in a `QPWFSERVSO` job log carries the client HOSTNAME. Every other
host server logs `CPIAD02`, which gives only the IP.** Measured 2026-09-25:

```sql
SELECT ORDINAL_POSITION, MESSAGE_ID, CAST(MESSAGE_TEXT AS VARCHAR(100))
  FROM TABLE(QSYS2.JOBLOG_INFO('<job>/QUSER/QPWFSERVSO'))
 ORDER BY ORDINAL_POSITION;
```

```
CPIAD02  User QSECOFR from client 192.168.40.89 connected to server.      <- as-rmtcmd, IP only
CPIAD12  Servicing user profile QSECOFR from client xtlformprt.xtlgroup.local.  <- as-file, NAMED
```

That is what turned *"an unidentified address holds four `QSECOFR` sessions"*
into *"it is the forms print host"* in one query (`proj-security` `#64`).

**So when an address needs identifying, find its file-server connection first:**

```sql
SELECT LOCAL_PORT, REMOTE_ADDRESS, JOB_NAME, AUTHORIZATION_NAME
  FROM QSYS2.NETSTAT_JOB_INFO WHERE REMOTE_ADDRESS = '<addr>' ORDER BY LOCAL_PORT;
```

A Toolbox/IBM i Access client typically opens 8471–8475 together, so if the
address is on 8475 at all it is probably on 8473 too — and that is the one that
answers the question. **The job logs of the other legs are still worth reading**
for *what* it does: repeated `CPF5C61 Client request - run program QSYS/QUSROBJD`
is object enumeration, which is an inventory or monitoring tool rather than an
application doing business work.

**`QSYS2.JOBLOG_INFO` reads an ACTIVE job's log**, which is how this works at all
— no spooled file exists yet, so `SYSTOOLS.SPOOLED_FILE_DATA` would return
nothing. It needs `*JOBCTL` or ownership; `CCSEC` does not have it and gets no
error, just no rows.

## Reading RPG/DDS source: the spec type is COLUMN 6, not the first non-blank

**This cost two failed attempts to run a program on 2026-09-25 and it will cost
the next session the same if it is not read here first.**

RPG and DDS source members carry a **5-character change-tag area** in columns
1–5. The spec type (`F`, `D`, `C`, `A`) is in **column 6**. So the same file
specification appears two ways in one member:

```
     FBRSumwrkd cf   e             workstn      <- no change tag
a067 FRacomd    if   e           k disk         <- tagged 'a067'
```

**A regex like `^ *F[A-Z]` matches the first and misses the second.** On
`LOGSRC/QCSTMSRC(BRSUMWRK)` that reported **7 files when there are 27** — and the
missing ones included `RACOMD`, `MSTCONTL` and `MSTCONT2`, which is why a library
list derived from the short list could not work.

**Extract on the column, never on leading whitespace:**

```bash
awk 'substr($0,6,1)=="F" || substr($0,6,1)=="f"'   # file specs
awk 'substr($0,6,1)=="A"'                          # DDS
```

The change tags are also *useful* — they are the maintenance history
(`a067`, `A084`, `aos03`), and on an old member they tell you which lines are
original and which were bolted on later.

### And two companions to it

- **A `*PGM` may carry NO source attribution.** `LOGOBJ/BRSUMWRK` has blank
  `SOURCE_FILE`/`SOURCE_LIBRARY`/`SOURCE_MEMBER`, while its display file and
  module carry theirs. **When it is blank you do not know what built the object**
  — say so rather than treating the same-named member as authoritative.
- **Take source from the object, never by name.** `BRSUMWRKD` exists in six
  places (`LOGSRC/QCSTMSRC` live at 611 lines, `DEBBIE/QDDSSRC` at 491,
  `DSNLOGSRC/QCHGSRC` as `D2`–`D7`). `OBJECT_STATISTICS`'s `SOURCE_*` columns say
  which one built the object; a name search picks whichever you happen to hit.
