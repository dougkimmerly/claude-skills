# DK/400 Development Skill

AS/400-inspired job queue system with green screen web TUI running on PostgreSQL.

## Repository Structure

DK/400 is split into two repositories:

### Public Repository: `dk400`
- **URL:** https://github.com/dougkimmerly/dk400
- **Purpose:** Portable AS/400 simulation anyone can use
- **Contains:** 5250 terminal, all AS/400 commands, generic qsys schema
- **Local Path:** `/Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/dk400/`

### Private Repository: `dk400-homelab`
- **URL:** https://github.com/dougkimmerly/dk400-homelab
- **Purpose:** Homelab-specific deployment on .19
- **Contains:** dk400 as git submodule + private Celery tasks + docker-compose
- **Local Path:** `/Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/`
- **Structure:**
  ```
  dk400-homelab/
  ├── dk400/              # Public repo (git submodule)
  ├── tasks/              # Private Celery tasks
  │   ├── viarail.py      # Via Rail calendar/fare checks
  │   ├── infrastructure.py
  │   ├── backup.py
  │   ├── health.py
  │   └── maintenance.py
  ├── celery_app.py       # Extends dk400 with homelab schedule
  └── docker-compose.yml  # Deployment for .19
  ```

### Updating Repositories

```bash
# Update public dk400 (when discovered changes needed):
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/dk400
# Make changes to dk400 code
git commit -am "Description"
git push origin main        # Push to public repo

# Update private dk400-homelab:
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab
git add dk400               # Update submodule reference (if dk400 changed)
git commit -m "Update dk400 submodule / your changes"
git push
```

## Quick Reference

### Deployment

```bash
# Standard deploy (on Ubuntu server .19 - uses dk400-homelab)
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull --recurse-submodules && docker compose up -d --build"

# FORCE REBUILD (use when cached layers cause issues)
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull --recurse-submodules && docker compose build --no-cache && docker compose up -d"

# Check logs
ssh doug@192.168.20.19 "docker logs dk400-web --tail 50"

# Test in container
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c 'from src.dk400.web.database import get_library_objects; print(get_library_objects(\"QSYS\", \"*FILE\"))'"
```

### URLs

- **Web UI:** http://192.168.20.19:8400
- **Flower (job monitoring):** http://192.168.20.19:5555
- **SSH TUI:** `ssh -p 2222 dk400@192.168.20.19` (empty password)

### Default Users

| User | Password | Class | Notes |
|------|----------|-------|-------|
| QSECOFR | QSECOFR | *SECOFR | Security Officer |
| QSYSOPR | QSYSOPR | *SYSOPR | System Operator |
| QUSER | QUSER | *USER | Default User |
| DOUG | TEST | *SECOFR | Test user (password reset) |

---

## Project Structure

### Private Deployment (dk400-homelab)
```
/Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/
├── dk400/                   # Public repo (git submodule)
│   └── src/dk400/...        # All AS/400 simulation code
├── tasks/                   # Private Celery tasks (homelab-specific)
│   ├── __init__.py
│   ├── viarail.py           # Via Rail calendar/fare checks
│   ├── infrastructure.py    # Docker sync, NetAlertX, dashboards
│   ├── backup.py            # All backup jobs
│   ├── health.py            # Health reports, monitors
│   └── maintenance.py       # Log monitor, VPN, cleanup
├── celery_app.py            # Extends dk400 with homelab beat schedule
├── docker-compose.yml       # Production deployment for .19
├── Dockerfile               # Builds image with submodule + tasks
├── .env.example             # Environment variable template
└── README.md
```

### Public Simulation (dk400 submodule)
```
/Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/dk400/
├── compose.yaml              # Docker services (for standalone use)
├── Dockerfile               # Celery workers
├── Dockerfile.tui           # SSH terminal
├── Dockerfile.web           # Web UI (FastAPI + WebSocket)
├── src/dk400/
│   ├── celery_app.py        # Base Celery configuration
│   ├── tasks/               # Generic Celery task definitions
│   ├── tui/                 # Textual TUI (SSH interface)
│   └── web/
│       ├── main.py          # FastAPI app, WebSocket handler
│       ├── screens.py       # ALL screen definitions (~9000+ lines)
│       ├── database.py      # ALL database functions (~4500+ lines)
│       └── users.py         # User management, authentication
└── data/                    # Persistent data (postgres, redis, celery)
```

---

## Database Architecture

### Consolidated Database (Target State)

DK/400 uses a single PostgreSQL instance with multiple schemas, following the AS/400 library model:

```
postgres-dk400 (single instance on .19)
└── DATABASE: dk400
    ├── SCHEMA: qsys       -- System library (journaling, users, jobs)
    ├── SCHEMA: qgpl       -- General purpose library
    ├── SCHEMA: brain      -- Brain operational data (events, issues, health)
    ├── SCHEMA: netbox     -- Infrastructure DCIM/IPAM
    ├── SCHEMA: bitwarden  -- Password vault
    └── SCHEMA: musiclib   -- Music library (33k tracks)
```

**Benefits of consolidation:**
- **Single backup** - one pg_dump gets everything
- **Point-in-time recovery** - APYJRNCHG replays journal to any timestamp
- **Audit trail** - DSPJRN shows who changed what, when
- **WRKLIB** - shows all libraries in 5250 terminal
- **Cross-schema queries** - can join brain.events with netbox.dcim_device

**Migration Plan:** See `~/.claude/plans/dk400-database-consolidation.md`

### Schema: `qsys`

All system tables live in the `qsys` PostgreSQL schema (AS/400 QSYS library equivalent).

**CRITICAL:** Always use `qsys.tablename` in SQL queries, never just `tablename`.

```sql
-- System tables in qsys schema (AS/400-style names)
qsys.users              -- User profiles
qsys.system_values      -- System values (WRKSYSVAL)
qsys.qhst               -- Audit/history log (was: audit_log)

-- Internal object storage tables (underscore prefix = physical files)
qsys._lib               -- Library definitions (was: libraries)
qsys._objaut            -- Object authorities (was: object_authorities)
qsys._splf              -- Spool file metadata (was: spooled_files)
qsys._cmd               -- Command definitions (was: command_info)
qsys._cmdparm           -- Command parameters (was: command_parm_info)
qsys._prmval            -- F4 prompt values (was: parm_valid_values)
qsys._jobhst            -- Job execution history (was: job_history)
qsys._dtaara            -- Data areas
qsys._msgq              -- Message queues
qsys._msg               -- Messages
qsys._qrydfn            -- Query definitions
qsys._jobd              -- Job descriptions
qsys._jobscde           -- Job schedules
qsys._outq              -- Output queues
qsys._autl              -- Authorization lists
qsys._autle             -- Auth list entries
qsys._sbsd              -- Subsystem descriptions

-- Journaling tables
qsys._jrn               -- Journal definitions
qsys._jrnrcv            -- Journal receivers
qsys._jrne              -- Journal entries (before/after images)
qsys._jrnpf             -- Journaled files registry
```

### Library = PostgreSQL Schema

- `QSYS` = `qsys` schema (system library)
- `QGPL` = `qgpl` schema (general purpose)
- `QUSRSYS` = `qusrsys` schema (user system)
- `BRAIN` = `brain` schema (homelab-brain data)
- `NETBOX` = `netbox` schema (infrastructure DCIM/IPAM)
- `BITWARDEN` = `bitwarden` schema (credentials vault)
- `MUSICLIB` = `musiclib` schema (music library)
- User libraries = user-created schemas

### Role-Based Schema Access

Each application has a PostgreSQL role with search_path configured:

```sql
-- Brain role example
CREATE ROLE brain LOGIN PASSWORD '...';
ALTER ROLE brain SET search_path TO brain, public;
GRANT ALL ON SCHEMA brain TO brain;
GRANT USAGE ON SCHEMA qsys TO brain;  -- For journaling
```

Applications connect with their role and automatically use the correct schema.

### Library List (*LIBL)

Each user has a library list stored in `qsys.users`:
- `current_library` - Where new objects are created when using *LIBL
- `library_list` - JSONB array of libraries to search (default: `["QGPL", "QSYS"]`)

**Functions:**
```python
get_user_library_list(username) -> list[str]  # Get user's searchable libraries
get_user_current_library(username) -> str     # Get where *LIBL creates objects
resolve_library(library, username) -> list[str]  # Expand *LIBL to library list
resolve_library_for_create(library, username) -> str  # Resolve for object creation
```

**Usage in screens:**
- Library fields default to `*LIBL`
- When saving with *LIBL, objects go to `current_library` (default: QGPL)
- When listing/searching with *LIBL, all libraries in `library_list` are searched
- Session class has `library_list` and `current_library` loaded at signon

### Object Types

| AS/400 Type | PostgreSQL Implementation | Storage |
|-------------|---------------------------|---------|
| *FILE | Table | `information_schema.tables` |
| *DTAARA | Row in _dtaara | `{schema}._dtaara` |
| *MSGQ | Row in _msgq | `{schema}._msgq` |
| *QRYDFN | Row in _qrydfn | `{schema}._qrydfn` |
| *JOBD | Row in _jobd | `{schema}._jobd` |
| *OUTQ | Row in _outq | `{schema}._outq` |
| *AUTL | Row in _autl | `{schema}._autl` |
| *SBSD | Row in _sbsd | `{schema}._sbsd` |

---

## Adding New Features

### Adding a New Command

1. **Register in COMMANDS dict** (`screens.py` ~line 150):
```python
COMMANDS = {
    # ...existing...
    'NEWCMD': 'newscreen',  # Command -> screen mapping
}
```

2. **Add description** (`screens.py` COMMAND_DESCS):
```python
COMMAND_DESCS = {
    # ...existing...
    'NEWCMD': 'Description of new command',
}
```

3. **Create screen method** (`screens.py`):
```python
def _screen_newscreen(self, session: Session) -> dict:
    """New screen implementation."""
    hostname, date_str, time_str = get_system_info()

    content = [
        pad_line(f" {hostname:<20}   Screen Title                    {session.user:>10}"),
        pad_line(f"                                                          {date_str}  {time_str}"),
        pad_line(""),
        # ... screen content ...
    ]

    return {
        "type": "screen",
        "screen": "newscreen",
        "cols": 80,
        "content": content,
        "fields": [
            {"id": "field1", "row": 5, "col": 30, "len": 10, "value": ""},
        ],
        "activeField": 0,
    }
```

4. **Create submit handler** (if needed):
```python
def _submit_newscreen(self, session: Session, fields: dict) -> dict:
    """Handle Enter key on new screen."""
    # Process input
    return self.get_screen(session, 'next_screen')
```

5. **Add F12 cancel handler** (`screens.py` in handle_function_key F12 section ~line 540):
```python
elif screen == 'newscreen':
    return self.get_screen(session, 'parent_screen')
```

### Adding a New Database Table

1. **Add to SCHEMA_SQL** (`database.py` ~line 30):
```python
SCHEMA_SQL = """
-- ... existing tables ...

CREATE TABLE IF NOT EXISTS qsys.new_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(10) NOT NULL,
    -- ... columns ...
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""
```

2. **Create CRUD functions** (`database.py`):
```python
def create_new_thing(name: str, ...) -> tuple[bool, str]:
    """Create a new thing."""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                INSERT INTO qsys.new_table (name, ...)
                VALUES (%s, ...)
            """, (name, ...))
        return True, f"Thing {name} created"
    except Exception as e:
        return False, str(e)

def get_new_thing(name: str) -> dict | None:
    """Get a thing by name."""
    with get_cursor() as cursor:
        cursor.execute(
            "SELECT * FROM qsys.new_table WHERE name = %s",
            (name,)
        )
        row = cursor.fetchone()
        return dict(row) if row else None
```

3. **Export in database.py imports** (at top of screens.py):
```python
from src.dk400.web.database import (
    # ...existing...
    create_new_thing, get_new_thing,
)
```

### Adding a New Object Type to WRKOBJ

1. **Add query in get_library_objects** (`database.py` ~line 740):
```python
# New Object Type
if obj_type in ('*ALL', '*NEWTYPE'):
    try:
        cursor.execute(sql.SQL("""
            SELECT name, 'NEWTYPE' as type, text, created, created_by
            FROM {}._newtype ORDER BY name
        """).format(sql.Identifier(lib_safe)))
        objects.extend([{**dict(r), 'library': lib} for r in cursor.fetchall()])
    except:
        pass
```

2. **Add display handler in _display_object** (`screens.py` ~line 8352):
```python
elif obj_type == 'NEWTYPE':
    session.field_values['selected_newtype'] = name
    session.field_values['selected_newtype_lib'] = library
    return self.get_screen(session, 'dspnewtype')
```

3. **Add delete handler in _delete_object** (`screens.py`):
```python
elif obj_type == 'NEWTYPE':
    return delete_newtype(library, name)
```

---

## Common Issues & Fixes

### psycopg2 % Escape in LIKE Patterns

**Problem:** `%` in SQL LIKE patterns gets interpreted as psycopg2 placeholder.

**Wrong:**
```python
cursor.execute("SELECT * FROM t WHERE name NOT LIKE '\\_%'", ())
# Error: tuple index out of range
```

**Correct:**
```python
cursor.execute("SELECT * FROM t WHERE name NOT LIKE '\\_%%'", ())
# %% becomes literal % in the SQL
```

### Column Field Name Mappings

`list_table_columns()` returns different keys than information_schema:

| list_table_columns | information_schema |
|-------------------|-------------------|
| `name` | `column_name` |
| `max_length` | `character_maximum_length` |
| `precision` | `numeric_precision` |
| `scale` | `numeric_scale` |
| `nullable` (bool) | `is_nullable` ('YES'/'NO') |

### get_cursor() Dict Mode

```python
# Default: returns RealDictRow (can use dict(row))
with get_cursor() as cursor:
    cursor.execute("SELECT * FROM qsys.users")
    row = cursor.fetchone()  # RealDictRow

# Tuple mode: returns plain tuples
with get_cursor(dict_cursor=False) as cursor:
    cursor.execute("SELECT * FROM qsys.users")
    row = cursor.fetchone()  # tuple
```

### Dict Cursor with SELECT EXISTS

**Problem:** `SELECT EXISTS(...)` returns a column named `exists`, not index 0.

**Wrong:**
```python
with get_cursor() as cursor:  # Dict cursor (default)
    cursor.execute("SELECT EXISTS (SELECT 1 FROM ...)")
    if not cursor.fetchone()[0]:  # ERROR: dict doesn't support [0]
```

**Correct:**
```python
with get_cursor() as cursor:
    cursor.execute("SELECT EXISTS (SELECT 1 FROM ...)")
    if not cursor.fetchone()['exists']:  # Use column name
```

**Or use tuple mode:**
```python
with get_cursor(dict_cursor=False) as cursor:
    cursor.execute("SELECT EXISTS (SELECT 1 FROM ...)")
    if not cursor.fetchone()[0]:  # OK with tuple cursor
```

### WebSocket Disconnects

Silent errors in screen methods cause WebSocket disconnects. Always check:
1. KeyError in dict access (use `.get()` with defaults)
2. Missing imports
3. Exceptions in try/except blocks being swallowed

**Debug approach:**
```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.screens import ScreenManager
from src.dk400.web.session import Session
sm = ScreenManager()
s = Session()
s.user = \"DOUG\"
s.field_values[\"selected_file\"] = \"users\"
s.field_values[\"selected_file_lib\"] = \"QSYS\"
print(sm._screen_dspfd(s))
'"
```

---

## Screen Patterns

### Standard Screen Layout

```
Line 1:  {hostname:<20}   {title:^30}   {user:>10}
Line 2:  {empty:50}                     {date}  {time}
Line 3:  (empty)
Line 4+: Content/fields
Line 20: Message line
Line 21: (empty)
Line 22: F-keys
```

### Option List Pattern (WRKXXX)

```python
def _screen_wrkxxx(self, session: Session) -> dict:
    items = get_xxx_list()
    offset = session.get_offset('wrkxxx')
    page_size = PAGE_SIZES.get('wrkxxx', 10)

    content = [
        # Header lines...
        pad_line(" Type options, press Enter."),
        pad_line("   2=Change   4=Delete   5=Display"),
        pad_line(""),
        [{"type": "text", "text": pad_line(" Opt  Name       Description"), "class": "field-reverse"}],
    ]

    fields = []
    page_items = items[offset:offset + page_size]
    for i, item in enumerate(page_items):
        fields.append({"id": f"opt_{i}", "row": 8 + i, "col": 2, "len": 2, "value": ""})
        content.append(pad_line(f"      {item['name']:<10} {item['desc']}"))

    # Pagination indicator
    more = "More..." if len(items) > offset + page_size else "Bottom"
    content.append(pad_line(f"{'':>70}{more}"))

    return {
        "type": "screen",
        "screen": "wrkxxx",
        "cols": 80,
        "content": content,
        "fields": fields,
        "activeField": 0,
    }
```

### Submit Handler for Options

```python
def _submit_wrkxxx(self, session: Session, fields: dict) -> dict:
    items = get_xxx_list()
    offset = session.get_offset('wrkxxx')
    page_size = PAGE_SIZES.get('wrkxxx', 10)
    page_items = items[offset:offset + page_size]

    for i, item in enumerate(page_items):
        opt = fields.get(f'opt_{i}', '').strip()
        if opt == '2':  # Change
            session.field_values['selected_xxx'] = item['name']
            return self.get_screen(session, 'chgxxx')
        elif opt == '4':  # Delete
            success, msg = delete_xxx(item['name'])
            session.message = msg
            break
        elif opt == '5':  # Display
            session.field_values['selected_xxx'] = item['name']
            return self.get_screen(session, 'dspxxx')

    return self.get_screen(session, 'wrkxxx')
```

---

## Testing

### Syntax Check
```bash
cd /Users/doug/Programming/dkSRC/infrastructure/dk400
python3 -m py_compile src/dk400/web/database.py
python3 -m py_compile src/dk400/web/screens.py
python3 -m py_compile src/dk400/web/users.py
```

### Direct Database Test
```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U dk400 -c 'SELECT * FROM qsys.users;'"
```

### Function Test in Container
```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.database import get_library_objects
objs = get_library_objects(\"QSYS\", \"*ALL\")
for o in objs[:5]: print(o)
'"
```

### Password Reset
```bash
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.users import user_manager
success, msg = user_manager.change_password(\"USERNAME\", \"NEWPASS\")
print(f\"{success}: {msg}\")
'"
```

---

## Key Constants

### PAGE_SIZES (`screens.py` ~line 200)
```python
PAGE_SIZES = {
    'wrklib': 10,
    'wrkobj': 12,
    'wrkusrprf': 10,
    'wrksysval': 12,
    'wrkqry': 10,
    'qryfields': 15,
    'qrywhere': 8,
    'qrysort': 8,
    'qryrun': 18,
    'dspfd': 12,
    # ...
}
```

### USER_CLASS_GRANTS (`database.py` ~line 80)
Defines table permissions by user class (*SECOFR, *SECADM, *PGMR, *SYSOPR, *USER).

### QUERY_OPERATORS (`database.py`)
```python
QUERY_OPERATORS = {
    'EQ': ('=', 'Equal'),
    'NE': ('<>', 'Not Equal'),
    'GT': ('>', 'Greater Than'),
    'LT': ('<', 'Less Than'),
    'GE': ('>=', 'Greater/Equal'),
    'LE': ('<=', 'Less/Equal'),
    'CT': ('LIKE', 'Contains'),
    'SW': ('LIKE', 'Starts With'),
    'NL': ('IS NULL', 'Is Null'),
    'NN': ('IS NOT NULL', 'Not Null'),
}
```

---

## WRKQRY - Query/400 Implementation

### Overview

WRKQRY provides AS/400 Query/400-style prompted SQL interface. Users build queries through menu-driven screens without writing SQL.

### Screen Flow

```
WRKQRY (list)
    │
    ├── F6=Create / Opt 1=Create / Opt 2=Change
    │   └── qrydefine (Define Query menu)
    │           ├── Opt 1: qryfiles (Select file - schema/table)
    │           ├── Opt 2: qryfields (Select columns)
    │           ├── Opt 3: qrywhere (WHERE conditions)
    │           │           └── F6=Add / Opt 2=Change → qrycond
    │           ├── Opt 4: qrysort (ORDER BY)
    │           ├── F5=Run → qryrun (preview results)
    │           └── F10=Save
    │
    ├── Opt 4=Delete (confirm)
    │
    └── Opt 5=Run → qryrun (execute and display)
```

### Commands

| Command | Screen | Description |
|---------|--------|-------------|
| WRKQRY | wrkqry | Work with Query Definitions |
| RUNQRY | qryrun | Run Query (with QRY parameter) |

### Session State Keys

```python
# Query definition being built/edited
'qry_name': 'CUSTQRY'           # Query name (max 10 chars)
'qry_library': 'QGPL'           # Library to save in
'qry_desc': 'Customer list'     # Description (max 50 chars)
'qry_mode': 'create'            # 'create' or 'change'

# Source file
'qry_schema': 'public'          # PostgreSQL schema
'qry_table': 'customers'        # Table name

# Query components
'qry_columns': [                # Selected columns with sequence
    {'name': 'ID', 'seq': 10},
    {'name': 'NAME', 'seq': 20},
]
'qry_conditions': [             # WHERE conditions
    {'field': 'STATUS', 'op': 'EQ', 'value': 'ACTIVE', 'and_or': 'AND'},
]
'qry_orderby': [                # ORDER BY fields
    {'field': 'NAME', 'seq': 1, 'dir': 'ASC'},
]

# Condition editing
'qry_cond_mode': 'add'          # 'add' or 'change'
'qry_edit_cond_idx': 0          # Index being edited

# Results navigation
'qry_return_screen': 'qrydefine'  # Where F12 returns from qryrun
```

### Database Table: `{library}._qrydfn`

Query definitions are stored per-library in `_qrydfn` tables:

```sql
CREATE TABLE IF NOT EXISTS {schema}._qrydfn (
    name VARCHAR(10) PRIMARY KEY,
    text VARCHAR(50) DEFAULT '',
    source_schema VARCHAR(128),
    source_table VARCHAR(128),
    selected_columns JSONB DEFAULT '[]',
    where_conditions JSONB DEFAULT '[]',
    order_by_fields JSONB DEFAULT '[]',
    summary_functions JSONB DEFAULT '[]',
    group_by_fields JSONB DEFAULT '[]',
    output_type VARCHAR(10) DEFAULT '*DISPLAY',
    row_limit INTEGER DEFAULT 0,
    created_by VARCHAR(10),
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_run TIMESTAMP
);
```

### Key Functions (`database.py`)

```python
# Query Definition CRUD
create_query_definition(name, library, description, source_schema, source_table,
                       selected_columns, where_conditions, order_by_fields, ...) -> tuple[bool, str]
get_query_definition(name, library) -> dict | None
update_query_definition(name, library, **kwargs) -> tuple[bool, str]
delete_query_definition(name, library) -> tuple[bool, str]
list_query_definitions(library=None, created_by=None) -> list[dict]

# Query Execution
execute_query(schema, table, columns, conditions, order_by, limit, offset) -> tuple[bool, list|str, list]
```

### QUERY_OPERATORS

```python
QUERY_OPERATORS = {
    'EQ': ('=', 'Equal'),
    'NE': ('<>', 'Not Equal'),
    'GT': ('>', 'Greater Than'),
    'LT': ('<', 'Less Than'),
    'GE': ('>=', 'Greater/Equal'),
    'LE': ('<=', 'Less/Equal'),
    'CT': ('LIKE', 'Contains'),      # Adds % wildcards
    'SW': ('LIKE', 'Starts With'),   # Adds trailing %
    'EW': ('LIKE', 'Ends With'),     # Adds leading %
    'NL': ('IS NULL', 'Is Null'),
    'NN': ('IS NOT NULL', 'Not Null'),
}
```

### F-Key Behavior

| Screen | F5 | F6 | F10 | F12 |
|--------|----|----|-----|-----|
| wrkqry | Refresh | Create new | - | Exit |
| qrydefine | Run preview | - | Save | Cancel to wrkqry |
| qryfiles | - | - | - | Cancel to qrydefine |
| qryfields | Run preview | - | - | Cancel to qrydefine |
| qrywhere | Run preview | Add condition | - | Cancel to qrydefine |
| qrycond | Run preview | - | - | Cancel to qrywhere |
| qrysort | Run preview | - | - | Cancel to qrydefine |
| qryrun | Refresh | - | - | Return to caller |

### Testing WRKQRY

```bash
# List saved queries
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.database import list_query_definitions
for q in list_query_definitions(): print(q)
'"

# Run a query directly
ssh doug@192.168.20.19 "docker exec dk400-web python3 -c '
from src.dk400.web.database import execute_query
success, rows, cols = execute_query(\"qsys\", \"users\", [], [], [], 10, 0)
print(cols)
for r in rows: print(r)
'"
```

---

## Git Workflow

### Updating Public dk400 (AS/400 simulation code)
```bash
# Local development (in submodule)
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab/dk400
# Make changes to screens.py, database.py, etc...
python3 -m py_compile src/dk400/web/screens.py  # Syntax check
python3 -m py_compile src/dk400/web/database.py
git add -A
git commit -m "Description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push origin main  # Push to PUBLIC dk400 repo

# Update submodule reference in private repo
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab
git add dk400
git commit -m "Update dk400 submodule"
git push  # Push to PRIVATE dk400-homelab repo
```

### Updating Private dk400-homelab (tasks, config)
```bash
cd /Users/doug/Programming/dkSRC/infrastructure/dk400-homelab
# Make changes to tasks/, celery_app.py, etc...
git add -A
git commit -m "Description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push
```

### Deploying to .19
```bash
# Standard deploy
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull --recurse-submodules && docker compose up -d --build"

# Force rebuild (when cached layers cause issues)
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull --recurse-submodules && docker compose build --no-cache && docker compose up -d"
```

---

## AS/400 Screen Design Style Guide

This guide defines the standards for creating and maintaining DK/400 screens, based on IBM AS/400 5250 terminal conventions and SAA CUA (Common User Access) guidelines.

### Screen Fundamentals

#### Display Size
- **Standard:** 80 columns x 24 rows (1920 characters)
- **Wide mode:** 132 columns x 27 rows (available but not default)
- Row numbering: 1-24 (top to bottom)
- Column numbering: 1-80 (left to right)

#### The 24-Line Grid
```
Row 1:   System identifier line (hostname, title, user)
Row 2:   Date/time line
Row 3:   (usually blank separator)
Rows 4-6: Instructions or parameter prompts
Rows 7-19: Main content area (list data, form fields)
Row 20:  Message line (error/informational messages)
Row 21:  (usually blank separator)
Rows 22-24: Function key legend
```

### Header Standards (Rows 1-3)

#### Row 1 Format
```
{hostname:<20}   {title:^38}   {user:>10}
```
- **Hostname:** Left-justified, columns 2-21 (leave col 1 for attribute byte)
- **Title:** Centered in remaining space, describes the current display
- **User:** Right-justified, columns 70-79

#### Row 2 Format
```
{blank:59}                    {date}  {time}
```
- Date format: `MM/DD/YY` (columns 63-70)
- Time format: `HH:MM:SS` (columns 73-80)

#### Row 3
- Always blank (visual separator)

### Screen Types

#### 1. Menu Screens
Used for selection menus (like main menu after signon).

```
Row 4:  "Select one of the following:"
Row 5:  (blank)
Row 6+: " n. Option description" (n = number, 2 spaces before number)
...
Row 18: (end options)
Row 19: (blank)
Row 20: Message line
Row 21: "Selection or command"
Row 22: "===>" followed by input field
Row 23: Function keys
```

Menu option format: `   n. Description` (3 spaces, number, period, space, description)

#### 2. Entry/Prompt Screens (DSPXXX/CHGXXX)
Used for data entry forms and parameter prompts.

```
Row 4:  "Type choices, press Enter."
Row 5:  (blank)
Row 6+: "  Field label . . . . . . . :  [input field]"
...     (labels right-aligned with dots, colon before value)
Row 20: Message line
Row 21-22: (blank or continuation)
Row 23-24: Function keys
```

Label format rules:
- Labels end with ` . . . . . . . :` (dots with spaces, then colon)
- Align colons vertically (typically column 28-30)
- Input fields start 2 spaces after colon
- Protected/display fields use same format but no underline

#### 3. List/Work-With Screens (WRKXXX)
Used for listing objects with options.

```
Row 4:  "Type options, press Enter."
Row 5:  "  2=Change   4=Delete   5=Display   ..." (option legend)
Row 6:  (blank)
Row 7:  Column headers (reverse video) - "Opt  Name       Type       Library    Text"
Row 8+: Data rows with option column
...
Row 19: "More..." or "Bottom" indicator (right-justified)
Row 20: Message line
Row 21: (blank)
Row 22-24: Function keys
```

Option column rules:
- Option field is 2 characters wide, column 2-3
- Leave column 1 empty (attribute byte)
- Common options: 1=Create, 2=Change, 3=Copy, 4=Delete, 5=Display, 7=Rename, 8=Work with

#### 4. Confirmation Screens
Used before destructive actions.

```
Row 4:  "Press Enter to confirm your choices. Press F12 to return."
Row 5:  (blank)
Row 6:  Explanation of what will happen
Row 7+: Details of items being affected
Row 20: Message line
Row 22-24: Function keys (minimal - usually just F12)
```

### Function Key Standards

#### Universal Keys (must be consistent across ALL screens)
| Key | Action | Notes |
|-----|--------|-------|
| F1 | Help | Display context-sensitive help |
| F3 | Exit | Exit program/function entirely |
| F4 | Prompt | Show valid values for current field |
| F5 | Refresh | Reload current display |
| F12 | Cancel | Return to previous screen |

#### Common Optional Keys
| Key | Action | Typical Use |
|-----|--------|-------------|
| F6 | Create/Add | Add new item to list |
| F9 | Retrieve | Retrieve previous command |
| F10 | Save | Save changes (entry screens) |
| F11 | Toggle view | Alternate view/more details |
| F13-F24 | Extended | Shift+F1-F12 |

#### Function Key Legend Format
```
Row 22: F3=Exit   F4=Prompt   F5=Refresh   F6=Create
Row 23: F11=Display text   F12=Cancel
```
- Format: `Fn=Action` with 3 spaces between keys
- If too many keys, use `F24=More keys` to toggle display
- Group related keys together
- Most important/common keys on first line

### Color and Attribute Conventions

#### Display Attributes (DSPATR equivalents)
| Attribute | CSS Class | Usage |
|-----------|-----------|-------|
| Normal (GRN) | `field-normal` | Regular text, protected fields |
| High Intensity (WHT) | `field-high` | Emphasis, column headers |
| Reverse Image (RI) | `field-reverse` | Column headers, selection bars |
| Underline (UL) | `field-input` | Input fields |
| Red/Blink | `field-error` | Error messages |
| Blue/Column Sep | `field-info` | Informational text |

#### Semantic Usage
- **Green (normal):** Standard text, labels, protected values
- **White (high intensity):** Headings, important information, emphasis
- **Reverse video:** Column headers in lists, selected items
- **Underline:** Input-capable fields
- **Red:** Error messages only (never for regular content)
- **Yellow:** Warning messages (use sparingly)

### Input Field Standards

#### Field Attributes
- Input fields display with underline attribute
- Field length indicated by underline extent
- Fields should be sized appropriately:
  - Name fields: 10 characters (AS/400 object name limit)
  - Description fields: 50 characters
  - Library names: 10 characters
  - Full paths: 128 characters

#### Field Positioning
- Align related fields vertically (same starting column)
- Group logically related fields together
- Use consistent label-to-field spacing
- Never start fields in column 1 (reserved for attribute byte)

### Cursor Positioning and Navigation

#### Initial Cursor Position (DSPATR(PC) equivalent)
The `activeField` property controls initial cursor position:
```python
return {
    "type": "screen",
    "screen": "screenname",
    "content": content,
    "fields": fields,
    "activeField": 0,  # Index into fields array (0 = first field)
}
```

**Rules:**
- Default to first input field (index 0)
- After an error, position cursor on the field with the error
- On prompt screens, position on the primary action field (e.g., Option)
- On list screens, position on first option field
- Field order in `fields` array determines tab order

#### Field Exit and Auto-Tab
IBM 5250 has two distinct field navigation behaviors:

1. **Tab Key:** Move to next input field without validation
2. **Field Exit:** Move to next field AND trigger field-level validation

In DK/400 web implementation:
- Tab moves between fields (browser native)
- Enter submits the screen (triggers validation)
- Field Exit behavior simulated via JavaScript for auto-advance

**Auto-advance pattern (optional):**
```javascript
// When field is filled to max length, auto-advance
if (field.value.length >= field.maxLength) {
    focusNextField();
}
```

#### Cursor Movement Keys
| Key | Action |
|-----|--------|
| Tab | Next input field (tab order) |
| Shift+Tab | Previous input field (tab order) |
| Arrow Up | Move to field above (spatial - same column) |
| Arrow Down | Move to field below (spatial - same column) |
| Arrow Left | Move left in field; at start → previous field (cursor at end) |
| Arrow Right | Move right in field; at end → next field (cursor at start) |
| Cmd/Ctrl+Home | First field on screen |
| Cmd/Ctrl+End | Last field on screen |
| Home | Start of current field |
| End | End of current field |
| Enter | Submit screen |
| Shift+Enter | Field Exit (move to next field) |
| Cmd/Alt+Up | Roll Up (page up) |
| Cmd/Alt+Down | Roll Down (page down) |
| PageUp | Roll Up |
| PageDown | Roll Down |

#### Auto-Advance Behavior
When a field is filled to its maximum length, the cursor automatically advances to the next field. This mimics IBM 5250 behavior where filling a field triggers auto-tab.

**Implementation (terminal.js):**
```javascript
handleFieldInput(e, fieldIndex) {
    const input = e.target;
    const maxLength = parseInt(input.getAttribute('maxlength')) || 999;
    if (input.value.length >= maxLength) {
        setTimeout(() => this.focusNextField(), 0);
    }
}
```

#### Spatial Navigation (Arrow Up/Down)
Arrow Up and Down move to the nearest field in that visual direction, not just the next field in tab order:

1. Get current field's row and column position
2. Find all fields above (or below)
3. From those, find the one closest to the current column position
4. If no field in that direction, wrap to opposite end of screen

This ensures pressing Down on a field moves to the field visually below it, even if that's not the next field in tab order.

#### Protected Area Handling
When cursor attempts to enter protected area:
- Arrow keys skip to next input field in that direction
- Mouse clicks on protected text focus nearest input field
- Prevents typing in non-input areas

### Session Defaults and Memory

#### Last-Used Values
AS/400 remembers values from previous operations within a session:

| Context | Remembered Values | Storage |
|---------|-------------------|---------|
| Library prompts | Last library used | `session.field_values['last_library']` |
| Query work | Last query library | `session.field_values['qry_last_library']` |
| Object lists | Last position | `session.offsets[screen_name]` |
| Command line | Command history | `session.field_values['cmd_history']` |

**Implementation pattern:**
```python
def _screen_wrkqry(self, session: Session) -> dict:
    # Use last library if available, else QGPL
    default_lib = session.field_values.get('qry_last_library', 'QGPL')

    # ... render screen with default_lib ...

def _submit_wrkqry(self, session: Session, fields: dict) -> dict:
    library = fields.get('library', '').strip().upper() or 'QGPL'

    # Remember for next time
    session.field_values['qry_last_library'] = library

    # ... process submission ...
```

#### Job-Level Defaults
These defaults persist for the entire session (from signon to signoff):

| Default | Source | Usage |
|---------|--------|-------|
| Current Library (*CURLIB) | User profile | Where new objects are created |
| Library List (*LIBL) | Job description | Search order for objects |
| Output Queue | User profile | Default print destination |
| Message Queue | User profile | Where messages are sent |

**Accessing in screens:**
```python
curlib = session.current_library  # From user profile
liblist = session.library_list    # From job description
```

#### Screen-Specific Positioning
List screens remember scroll position:
```python
# Get current position
offset = session.get_offset('wrkobj')

# After navigation, restore position
session.set_offset('wrkobj', offset)
```

### Message Line Standards (Row 20)

#### Message Types
1. **Error messages:** Displayed in red/reverse, describe what went wrong
2. **Completion messages:** Confirm successful actions
3. **Informational messages:** Provide status or guidance

#### Message Format
```
CPF0001 - Description of the error or message
```
- Optional message ID prefix (like CPF0001)
- Clear, actionable text
- For errors: describe what went wrong AND how to fix it

#### Message Priority
- Error messages override informational messages
- Most recent message displays
- Clear message after successful navigation

### Subfile/List Patterns

#### Subfile Structure
A list screen consists of three parts:
1. **Header format:** Screen title, instructions, function keys
2. **Subfile format (SFL):** One row template repeated for each item
3. **Control format (SFLCTL):** Column headers, pagination controls

#### Pagination
- Use "More..." when more records exist below
- Use "Bottom" when showing last page
- PageDown/PageUp (or F7/F8) for navigation
- Show position indicator: "Position to..." field for jumping

#### Column Headers
```
[{"type": "text", "text": " Opt  Name       Type       Library    Text", "class": "field-reverse"}]
```
- Always use reverse video for column headers
- Align columns with data below
- Include "Opt" header for option column

### Specific Patterns

#### Library Field with F4 Prompt
When a screen has a library input field:
- Default value: `*LIBL` (search library list)
- F4 shows available libraries
- Allow `*CURLIB` for current library
- Allow specific library name

#### Create vs Change Screens
- Create screens: All fields empty/defaulted, title says "Create..."
- Change screens: Pre-populate with existing values, title says "Change..."
- Use same field layout for both (code reuse)

#### Confirmation Flows
Before delete/destructive actions:
1. Show confirmation screen listing affected items
2. Require Enter to confirm, F12 to cancel
3. After action, return to list with message

### Implementation Guidelines

#### Python Screen Method Template
```python
def _screen_wrkxxx(self, session: Session) -> dict:
    """Work with XXX screen."""
    hostname, date_str, time_str = get_system_info()

    # Build header
    content = [
        pad_line(f" {hostname:<20}   Work with XXX               {session.user:>10}"),
        pad_line(f"                                                          {date_str}  {time_str}"),
        pad_line(""),
        pad_line(" Type options, press Enter."),
        pad_line("   2=Change   4=Delete   5=Display"),
        pad_line(""),
        [{"type": "text", "text": pad_line(" Opt  Name       Description"), "class": "field-reverse"}],
    ]

    # Build list with pagination
    items = get_xxx_list()
    offset = session.get_offset('wrkxxx')
    page_size = PAGE_SIZES.get('wrkxxx', 10)
    page_items = items[offset:offset + page_size]

    fields = []
    for i, item in enumerate(page_items):
        fields.append({"id": f"opt_{i}", "row": 8 + i, "col": 2, "len": 2, "value": ""})
        content.append(pad_line(f"      {item['name']:<10} {item['description'][:50]}"))

    # Pagination indicator
    more = "More..." if len(items) > offset + page_size else "Bottom"
    content.append(pad_line(f"{'':>70}{more}"))

    # Footer with function keys
    content.extend([
        pad_line(""),  # Row 20 - message line (or session.message)
        pad_line(""),
        pad_line(" F3=Exit   F5=Refresh   F6=Create   F12=Cancel"),
    ])

    return {
        "type": "screen",
        "screen": "wrkxxx",
        "cols": 80,
        "content": content,
        "fields": fields,
        "activeField": 0,
    }
```

#### Common Mistakes to Avoid
1. **Using column 1:** Always leave column 1 empty (attribute byte position)
2. **Inconsistent function keys:** F3/F12 must always behave the same way
3. **Mixing colors randomly:** Follow the semantic color rules
4. **Crowded layouts:** Leave breathing room, use blank rows as separators
5. **Missing pagination:** Lists must handle more items than fit on screen
6. **No confirmation for deletes:** Always confirm destructive actions
7. **Unclear error messages:** Messages should say what went wrong AND what to do

---

## OS/400 Screen Reference (Exact Patterns)

This section documents exact IBM OS/400 screen layouts that DK/400 screens must match.

### MAIN - IBM i Main Menu

```
MAIN                           IBM i Main Menu

Select one of the following:

     1. User tasks
     2. Office tasks
     3. General system tasks
     4. Files, libraries, and folders
     5. Programming
     6. Communications
     7. Define or change the system
     8. Problem handling
     9. Display a menu
    10. Information Assistant options
    11. IBM i Access tasks

    90. Sign off

Selection or command
===>
```

**Pattern Notes:**
- Screen identifier "MAIN" at top-left
- Centered title without hostname/date (different from list screens)
- "Select one of the following:" instruction
- Options: 5 spaces, number, period, space, description
- Options are left-aligned (NO command names on right)
- "Selection or command" label above command line
- `===>` prompt (4 equals signs, greater-than)

### WRKUSRPRF - Work with User Profiles

```
                           Work with User Profiles

Type options, press Enter.
  1=Create   2=Change   3=Copy   4=Delete   5=Display
  12=Work with objects by owner

     User
Opt  Profile     Text
 _   DPTSM       Sales and Marketing Department
 _   DPTWH       Warehouse Department
                                                              More...

F3=Exit   F5=Refresh   F6=Create   F12=Cancel
```

**Pattern Notes:**
- Centered title (no hostname/date on this screen variant)
- "Type options, press Enter." instruction
- Options listed with `n=Action` format, 3 spaces between
- Column headers: "Opt", "User Profile", "Text"
- NO separate Status/Class columns (those are on Display screen)
- "More..." or "Bottom" right-justified
- Standard function keys at bottom

### CRTUSRPRF - Create User Profile

```
                        Create User Profile (CRTUSRPRF)

Type choices, press Enter.

User profile . . . . . . . . . .   __________    Name
User password  . . . . . . . . .   *NONE         Character value, *USRPRF...
Set password to expired  . . . .   *YES          *NO, *YES
Status . . . . . . . . . . . . .   *ENABLED      *ENABLED, *DISABLED
User class . . . . . . . . . . .   *USER         *USER, *SYSOPR, *PGMR...
Assistance level . . . . . . . .   *SYSVAL       *SYSVAL, *BASIC, *INTERMED...
Current library  . . . . . . . .   *CRTDFT       Name, *CRTDFT
Initial program to call  . . . .   *NONE         Name, *NONE
  Library  . . . . . . . . . . .                 Name, *LIBL, *CURLIB
Initial menu . . . . . . . . . .   MAIN          Name, *SIGNOFF
  Library  . . . . . . . . . . .   QSYS          Name, *LIBL, *CURLIB
Text 'description' . . . . . . .   *BLANK


F3=Exit   F4=Prompt   F12=Cancel   F24=More keys
```

**Pattern Notes:**
- Title includes command name in parentheses: "Create User Profile (CRTUSRPRF)"
- "Type choices, press Enter." instruction (NOT "Type options")
- Label format: `Label . . . . . . . . . . :   [value]    Valid values`
- Dots and spaces align colons vertically (around column 35)
- Current/default value in center column
- Valid values/hints right-justified on same line
- Sub-fields indented 2 spaces (e.g., "Library" under "Initial program")
- F4=Prompt for list selection

### WRKQRY - Work with Queries (IMPORTANT: NOT a list screen!)

```
                          Work with Queries

 Type choices, press Enter.

   Option  . . . . . .   _              1=Create, 2=Change, 3=Copy, 4=Delete
                                        5=Display, 6=Print definition
                                        8=Run in batch, 9=Run
   Query . . . . . . .   __________     Name, F4 for list
     Library . . . . .     *LIBL        Name, *LIBL, F4 for list


F3=Exit   F4=Prompt   F12=Cancel
```

**CRITICAL:** WRKQRY is a **prompt screen**, NOT a list screen. User enters:
1. Option number (what action to take)
2. Query name (or F4 for list)
3. Library name

The list of queries appears when user presses F4, not on the main screen.

### Define the Query (qrydefine)

```
                            Define the Query

 Query . . . . . . :   QRY1              Option  . . . . . :   CREATE
   Library . . . . :     QGPL            CCSID . . . . . . :      37

 Type options, press Enter.  Press F21 to select all.
   1=Select

 Opt    Query Definition Option
  _     Specify file selections
  _     Define result fields
  _     Select and sequence fields
  _     Select records
  _     Select sort fields
  _     Select collating sequence
  _     Specify report column formatting
  _     Select report summary functions
  _     Define report breaks
  _     Select output type and output form
  _     Specify processing options

F3=Exit   F5=Report   F12=Cancel   F13=Layout   F18=Files   F21=Select all
```

**Pattern Notes:**
- Header shows current query name, library, and mode
- "Type options, press Enter." with additional "Press F21 to select all."
- Single option "1=Select" (not typical 2/4/5 options)
- List of definition steps (file, fields, conditions, sort, etc.)
- More function keys for query-specific actions (F5=Report, F13=Layout)

### WRKSYSVAL - Work with System Values

```
                         Work with System Values

Type options, press Enter.
  2=Change   5=Display


Opt  System Value    Description
 _   QDATE           System date
 _   QTIME           System time
 _   QSYSNAME        System name
 _   QSECOFR         Security officer user profile
                                                              More...

F3=Exit   F5=Refresh   F12=Cancel
```

**Pattern Notes:**
- Column headers: "System Value" and "Description" (not "Value" and "Category")
- The actual value is shown on the Display (option 5) screen, not in the list
- Minimal options (2=Change, 5=Display)

### WRKLIB - Work with Libraries

```
                           Work with Libraries

Type options, press Enter.
  2=Change   4=Delete   5=Display   8=Display description   12=Work with objects


Opt  Library     Type     Text
 _   QGPL        *PROD    General Purpose Library
 _   QSYS        *PROD    System Library
 _   MYLIB       *TEST    My Test Library
                                                              More...

F3=Exit   F5=Refresh   F6=Create   F12=Cancel
```

**Pattern Notes:**
- Columns: "Library", "Type" (*PROD/*TEST), "Text"
- Option 12=Work with objects (goes to WRKOBJ for that library)

### WRKOBJ - Work with Objects

```
                           Work with Objects

Library  . . . . . . :   QGPL

Type options, press Enter.
  2=Change   3=Copy   4=Delete   5=Display   7=Rename   8=Display description


Opt  Object      Type      Attribute   Text
 _   MYPGM       *PGM      RPGLE       My Program
 _   MYFILE      *FILE     PF          My Data File
 _   MYDTAARA    *DTAARA   DEC         My Data Area
                                                              More...
Position to  . . . . .   __________

F3=Exit   F5=Refresh   F12=Cancel
```

**Pattern Notes:**
- Shows current library being viewed at top
- Columns: "Object", "Type", "Attribute", "Text"
- "Position to" field for quick navigation in long lists
- Attribute varies by object type (RPGLE for *PGM, PF for *FILE, etc.)

### Sign On Screen

```
                             Sign On

                         System  . . . . . :   DK400
                         Subsystem . . . . :   QINTER
                         Display . . . . . :   DSP01

                         User  . . . . . . . . . . . . . :  __________
                         Password  . . . . . . . . . . . :  __________
                         Program/procedure . . . . . . . :  __________
                         Menu  . . . . . . . . . . . . . :  __________
                         Current library . . . . . . . . :  __________




                  (C) COPYRIGHT IBM CORP. 1980, 2024.
```

**Pattern Notes:**
- Centered title "Sign On"
- System info block (System, Subsystem, Display) right-aligned
- Entry fields use dot leaders to colon alignment
- Copyright at bottom, centered
- NO function keys displayed (Enter to sign on)

---

## DK/400 Screen Compliance Checklist

When creating or updating a screen, verify:

### For Menu Screens (GO xxx)
- [ ] Screen identifier at top-left (e.g., "MAIN", "USER", "CMDENT")
- [ ] Centered title
- [ ] "Select one of the following:" instruction
- [ ] Options formatted: `     n. Description`
- [ ] NO command names on right side of options
- [ ] "Selection or command" label
- [ ] `===>` prompt for command/selection input

### For List/Work-with Screens (WRKxxx)
- [ ] Centered title OR hostname + title + date/time format
- [ ] "Type options, press Enter." instruction
- [ ] Option legend: `n=Action` with 3 spaces between
- [ ] Column headers match IBM (Opt, Name, Type, Text pattern)
- [ ] Column headers in reverse video
- [ ] "More..." or "Bottom" right-justified
- [ ] NO logo on list screens
- [ ] Standard function keys (F3, F5, F6, F12)

### For Entry/Prompt Screens (CRTxxx, CHGxxx)
- [ ] Title includes command name: "Create xxx (CRTxxx)"
- [ ] "Type choices, press Enter." instruction
- [ ] Label format with dots: `Label . . . . . . . :   [field]   Valid values`
- [ ] Colons aligned vertically (around column 35)
- [ ] Valid values/hints shown on right
- [ ] Sub-fields indented 2 spaces
- [ ] F4=Prompt available for fields with lists

### For Display Screens (DSPxxx)
- [ ] Title includes command name: "Display xxx (DSPxxx)"
- [ ] All fields protected (display only)
- [ ] Same label format as entry screens
- [ ] F3=Exit, F12=Cancel (no F4/F6)

---

---

## Clickable Hotspots

DK/400 supports clickable hotspots for mouse-based navigation, matching classic 5250 emulator behavior.

### Hotspot Types

| Type | Action | Usage |
|------|--------|-------|
| `page_up` / `roll_up` | Roll up (previous page) | `<Prev>` indicators |
| `page_down` / `roll_down` | Roll down (next page) | `<More>` indicators |
| `fkey_F3`, `fkey_F5`, etc. | Trigger function key | Clickable F-key labels |

### Creating Hotspots in Screens

```python
# Navigation hotspots
nav_line = []
if page > 1:
    nav_line.append({"type": "hotspot", "text": "<Prev>", "action": "page_up"})
if page < max_page:
    nav_line.append({"type": "hotspot", "text": "<More>", "action": "page_down"})
content.append(nav_line)
```

### Function Key Lines with fkey_line()

Use the `fkey_line()` helper to create clickable function key rows:

```python
# Instead of:
content.append(pad_line(" F3=Exit  F5=Refresh  F12=Cancel"))

# Use:
content.append(fkey_line("F3=Exit  F5=Refresh  F12=Cancel"))

# With PageUp/PageDown:
content.append(fkey_line("F3=Exit  F5=Refresh  F12=Cancel  PageDown=Roll Down  PageUp=Roll Up"))

# For 132-column screens:
content.append(fkey_line("F3=Exit  F5=Refresh  F12=Cancel", 132))
```

The `fkey_line()` function:
- Parses `Fn=Label` patterns and makes them clickable
- Handles `PageDown=...` and `PageUp=...` as roll hotspots
- Preserves spacing between keys
- Pads to specified width (default 80)

### CSS Styling

Hotspots are styled in `terminal.css`:
```css
.hotspot {
    cursor: pointer;
    text-decoration: underline;
}
.hotspot:hover {
    color: var(--phosphor-bright);
}
```

### JavaScript Handler

In `terminal.js`, clicks on `.hotspot` elements trigger actions:
- `page_down` / `roll_down` → `handleRoll('down')`
- `page_up` / `roll_up` → `handleRoll('up')`
- `fkey_F3`, `fkey_F12`, etc. → `handleFunctionKey('F3')`, etc.

---

## Journaling System

DK/400 implements AS/400-style journaling for change tracking and recovery.

### Journal Objects

| Object | Table | Purpose |
|--------|-------|---------|
| Journal (*JRN) | `qsys._jrn` | Journal configuration |
| Journal Receiver (*JRNRCV) | `qsys._jrnrcv` | Physical storage for entries |
| Journal Entries | `qsys._jrne` | Before/after images of changes |
| Journaled Files | `qsys._jrnpf` | Which tables are being journaled |

### Entry Types (Journal Code 'F' - File Operations)

| Code | Meaning | Data Stored |
|------|---------|-------------|
| PT | Record Added (Put) | After-image |
| UP | Record Updated (After) | After-image |
| UB | Record Updated (Before) | Before-image |
| DL | Record Deleted | Before-image |

### Commands

| Command | Screen | Purpose |
|---------|--------|---------|
| WRKJRN | wrkjrn | Work with Journals |
| DSPJRN | dspjrn | Display Journal Entries |
| CRTJRN | crtjrn | Create Journal |
| CRTJRNRCV | crtjrnrcv | Create Journal Receiver |
| STRJRNPF | strjrnpf | Start Journaling Physical File |
| ENDJRNPF | endjrnpf | End Journaling Physical File |

### Creating a Journal

```sql
-- Via screens:
CRTJRNRCV JRNRCV(QGPL/MYRCV)
CRTJRN JRN(QGPL/MYJRN) JRNRCV(QGPL/MYRCV)
STRJRNPF FILE(PUBLIC/CUSTOMERS) JRN(QGPL/MYJRN) IMAGES(*BOTH)
```

### Database Functions

```python
# Journal CRUD
create_journal(name, library, receiver, text, images='*AFTER') -> tuple[bool, str]
get_journal(name, library) -> dict | None
list_journals(library=None) -> list[dict]

# Receiver CRUD
create_journal_receiver(name, library, journal, journal_library, text) -> tuple[bool, str]
attach_receiver(journal, receiver, library) -> tuple[bool, str]
detach_receiver(journal, library) -> tuple[bool, str]

# Start/End journaling
start_journal_pf(schema, table, journal, library, images='*AFTER') -> tuple[bool, str]
end_journal_pf(schema, table) -> tuple[bool, str]

# Query entries
get_journal_entries(journal, library, object_name, entry_type, from_time, to_time, limit) -> list[dict]
```

### PostgreSQL Trigger

Journaling uses a trigger function `qsys.journal_trigger_fn()` that:
1. Checks if table is being journaled (via `_jrnpf`)
2. Gets current receiver from journal
3. Inserts before/after images based on IMAGES setting
4. Updates receiver and journal statistics

### Viewing Journal Entries

```
DSPJRN JRN(QGPL/MYJRN)
```

Entry detail shows:
- Sequence number, entry type, timestamp
- User, job, program
- Object schema and name
- Before-image and after-image (as formatted JSONB)

---

## User Profiles (QAUSRPRF)

User profiles are stored in `qsys.qausrprf` with full AS/400 field compatibility.

### Table: qsys.qausrprf

The table follows AS/400 QAUSRPRF (QA* audit prefix) naming:

```sql
-- Key columns (54 total)
username VARCHAR(10) PRIMARY KEY    -- User ID
password_hash, salt                  -- Authentication
user_class VARCHAR(10)               -- *SECOFR, *SECADM, *PGMR, *SYSOPR, *USER
status VARCHAR(10)                   -- *ENABLED, *DISABLED
description VARCHAR(50)              -- Text description

-- Password settings
password_expires VARCHAR(10)         -- *NOMAX, or days
password_last_changed TIMESTAMP
password_expired VARCHAR(4)          -- *YES, *NO
signon_attempts INTEGER

-- Authority
spcaut JSONB                         -- Special authorities array
group_profile VARCHAR(10)            -- Primary group
supgrpprf JSONB                      -- Supplemental groups array
owner VARCHAR(10)                    -- *USRPRF, *GRPPRF
grpaut, grpauttyp VARCHAR(10)

-- Initial program/menu
inlpgm, inlpgm_lib VARCHAR(10)
inlmnu, inlmnu_lib VARCHAR(10)
lmtcpb VARCHAR(10)                   -- Limit capabilities

-- Library list
current_library VARCHAR(10)          -- *CURLIB
inllibl JSONB                        -- Initial library list array

-- Output/print
outq, outq_lib VARCHAR(10)
prtdev VARCHAR(10)

-- Message queue
msgq, msgq_lib VARCHAR(10)
dlvry VARCHAR(10)                    -- *NOTIFY, *BREAK, *HOLD
sev INTEGER

-- Job description
jobd, jobd_lib VARCHAR(10)

-- Attention program
atnpgm, atnpgm_lib VARCHAR(10)

-- Locale
srtseq, srtseq_lib VARCHAR(10)
langid, cntryid, ccsid VARCHAR(10)

-- Environment
spcenv VARCHAR(10)
astlvl VARCHAR(10)                   -- Assistance level
dspsgninf VARCHAR(4)
lmtdevssn VARCHAR(10)
kbdbuf VARCHAR(10)

-- Storage
maxstg VARCHAR(10)                   -- *NOMAX or KB
curstrg INTEGER

-- Other
acgcde VARCHAR(15)
homedir VARCHAR(256)
usropt JSONB
objaud, audlvl VARCHAR(10)
```

### DSPUSRPRF - Display User Profile

Multi-page display matching AS/400 format:

**Page 1:** Identity, sign-on, password, authorities, groups
**Page 2:** Initial program/menu, output, print device, job attributes
**Page 3:** Message queue, job description, locale settings

Navigation:
- PageUp/PageDown or click `<Prev>`/`<More>` hotspots
- F3=Exit, F12=Cancel

### UserProfile Dataclass

```python
from src.dk400.web.users import UserProfile

@dataclass
class UserProfile:
    username: str
    user_class: str = "*USER"
    status: str = "*ENABLED"
    description: str = ""
    # ... 50+ fields matching AS/400

    # JSONB fields initialized as lists
    spcaut: list = field(default_factory=list)
    supgrpprf: list = field(default_factory=list)
    inllibl: list = field(default_factory=lambda: ["QGPL", "QSYS"])
```

### User Management Functions

```python
from src.dk400.web.users import user_manager

# Create user
success, msg = user_manager.create_user(
    username="NEWUSER",
    password="password",
    user_class="*USER",
    description="New user",
    group_profile="*NONE"
)

# Get user profile
profile = user_manager.get_user("DOUG")  # Returns UserProfile or None

# Update user
success, msg = user_manager.update_user(
    username="DOUG",
    user_class="*PGMR",
    description="Developer"
)

# Change password
success, msg = user_manager.change_password("DOUG", "newpass")
```

### Migration for Existing Tables

If upgrading from older schema, run the migration:

```python
from src.dk400.web.database import _add_usrprf_columns
_add_usrprf_columns()  # Adds missing columns to existing qausrprf
```

---

### Reference Sources

- [5250 Terminal Overview](https://as400i.com/2013/03/07/overview-of-the-green-screen-5250-terminal/)
- [Display File Design Standards](https://techdocs.broadcom.com/us/en/ca-enterprise-software/it-operations-management/ca-2e/8-7/Standards/ibm-i-general-design-standards/design-standards-for-display-files.html)
- [5250 Colors and Display Attributes](https://try-as400.pocnet.net/wiki/5250_colors_and_display_attributes)
- [DSPATR Keyword Reference](https://www.ibm.com/docs/en/i/7.3.0?topic=80-dspatr-display-attribute-keyword-display-files)
- [Subfile Programming](https://www.mcpressonline.com/programming/rpg/as400-subfile-programming-part-ii-basic-coding)
- [Query/400 Getting Started](https://www.mcpressonline.com/analytics-cognitive/business-intelligence/getting-started-with-query400)
- [IBM WRKUSRPRF Documentation](https://www.ibm.com/docs/en/i/7.3?topic=profiles-using-work-user-command)

---

## System Testing Protocol

This section documents the comprehensive testing protocol for DK/400.

### Test Environment

- **Test Instance:** http://192.168.20.19:8400 (Ubuntu .19)
- **Production:** Heroku (deploy after all tests pass)
- **Test Credentials:** QSECOFR / SECURITY (or QSECOFR if fresh install)

### Running Tests via Playwright MCP

Use the Playwright MCP tools for browser-based testing:

```python
# 1. Navigate to instance
mcp__playwright__browser_navigate(url="http://192.168.20.19:8400")

# 2. Sign on
mcp__playwright__browser_type(ref="user_field", element="User field", text="QSECOFR")
mcp__playwright__browser_type(ref="password_field", element="Password field", text="SECURITY", submit=True)

# 3. Test a command
mcp__playwright__browser_type(ref="cmd_field", element="Command input", text="WRKUSRPRF", submit=True)

# 4. Verify screen loaded
mcp__playwright__browser_snapshot()  # Check for expected elements

# 5. Test function keys
mcp__playwright__browser_press_key(key="F3")  # Exit
mcp__playwright__browser_press_key(key="F5")  # Refresh
mcp__playwright__browser_press_key(key="F12") # Cancel
mcp__playwright__browser_press_key(key="PageDown")  # Scroll
```

### Command Test Checklist

| Category | Command | Test Steps | Expected Result |
|----------|---------|------------|-----------------|
| **System** | DSPSYSSTS | Run command | Shows CPU, memory, pools |
| **Jobs** | WRKACTJOB | Run command, opt 5 | Shows active jobs, detail |
| **Jobs** | WRKJOBQ | Run command | Shows job queues |
| **Jobs** | WRKJOBSCDE | Run command, opt 2 | Shows schedules, detail |
| **Jobs** | SBMJOB | Run command | Shows submit form |
| **Jobs** | WRKJOBD | Run command, opt 2 | Shows job descriptions |
| **Users** | WRKUSRPRF | Run command, opt 5 | Shows users, profile detail |
| **Users** | CRTUSRPRF | Run command | Shows create form |
| **Libraries** | WRKLIB | Run command | Shows libraries |
| **Libraries** | CRTLIB | Run command | Shows create form |
| **Services** | WRKSVC | Run command | Shows Docker containers |
| **Services** | WRKHLTH | Run command | Shows health checks |
| **Output** | WRKOUTQ | Run command, opt 5 | Shows output queues, spool |
| **Output** | WRKSPLF | Run command | Shows spooled files |
| **Messages** | WRKMSGQ | Run command | Shows message queues |
| **Messages** | WRKALR | Run command, opt 5 | Shows alerts, detail |
| **System Values** | WRKSYSVAL | Run, PageDown | Shows sysvals, paging |
| **Data Areas** | WRKDTAARA | Run command | Shows data areas |
| **Data Areas** | CRTDTAARA | Run command | Shows create form |
| **Journaling** | WRKJRN | Run command | Shows journals |
| **Journaling** | CRTJRN | Run command | Shows create form |
| **Journaling** | CRTJRNRCV | Run command | Shows create form |
| **Journaling** | DSPJRN | Run command | Shows prompt |
| **Journaling** | STRJRNPF | Run command | Shows start form |
| **Query** | WRKQRY | Run command | Shows queries |
| **Query** | Full flow | Create/select/run | Full query workflow |
| **Network** | WRKNETDEV | Run command, opt 5 | Shows devices, detail |
| **Backup** | WRKBKP | Run command, opt 5 | Shows backups, detail |
| **Auth** | WRKAUTL | Run command | Shows auth lists |
| **Subsystem** | WRKSBSD | Run command | Shows subsystem descs |
| **Log** | DSPLOG | Run command | Shows system log |

### Function Key Test Checklist

| Key | Expected Behavior |
|-----|-------------------|
| F3 | Exit current screen, return to parent |
| F5 | Refresh current screen data |
| F6 | Create new item (on list screens) |
| F12 | Cancel and return to previous screen |
| PageDown | Scroll down in lists |
| PageUp | Scroll up in lists |
| Enter | Submit form/selection |

### Common Bugs and Fixes

| Bug Pattern | Root Cause | Fix |
|-------------|------------|-----|
| `KeyError: 'field_name'` | Database returns different field | Use `dict.get('field', default)` |
| `relation "x" does not exist` | Missing schema prefix or case | Use `schema.table`, check case |
| WebSocket disconnect | Unhandled exception in screen | Add try/except, check for None |
| Screen not updating | Missing return statement | Ensure all paths return screen dict |
| Pagination not working | Wrong offset calculation | Check `session.get_offset()` |

### Deploying Fixes

```bash
# 1. Make fix locally
# 2. Syntax check
python3 -m py_compile src/dk400/web/screens.py
python3 -m py_compile src/dk400/web/database.py

# 3. Commit
git add -A && git commit -m "Fix description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push

# 4. Deploy to .19
ssh doug@192.168.20.19 "cd /home/doug/dkSRC/infrastructure/dk400-homelab && git pull --recurse-submodules && docker compose down && docker compose up -d --build"

# 5. Wait for containers
sleep 10

# 6. Re-test the fixed command
```

### Test Results Location

Test results are stored in: `tests/test_results.md`

Format:
```markdown
# DK/400 Test Results

Test Date: YYYY-MM-DD
Instance: http://192.168.20.19:8400

## Command Tests
| Command | Result | Notes |
|---------|--------|-------|
| WRKACTJOB | PASS | Shows jobs correctly |
| WRKMSGQ | FIXED | Was KeyError, fixed delivery field |
```

### Heroku Deployment (After All Tests Pass)

Only deploy to Heroku when ALL tests pass on .19:

```bash
# Push to Heroku
git push heroku main

# Check logs
heroku logs --tail --app dk400
```
