# Claude Broker Specification

> Central message broker for Claude multi-agent coordination
> 
> **Status:** Draft v0.1
> **Location:** Runs on Doug's Mac (192.168.20.150)
> **Connects to:** homelab-dashboard via WebSocket

## Overview

claude-broker is a local service that:
- Routes messages between PM (via GitHub) and CC sessions (local)
- Manages entity registration and discovery
- Spawns CC terminal sessions on-demand
- Tracks session state (running/idle)
- Provides WebSocket API for dashboard integration
- Sends macOS notifications for human attention

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Mac (192.168.20.150)                                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  claude-broker (launchd daemon, port 9500)            │  │
│  │  ├── SQLite: ~/.claude-broker/messages.db             │  │
│  │  ├── Config: ~/.claude-broker/config.yaml             │  │
│  │  ├── Entities: ~/.claude-broker/entities.yaml         │  │
│  │  ├── GitHub sync (polls claude-messages repo)         │  │
│  │  ├── Session manager (spawns Terminal.app)            │  │
│  │  ├── Notification service (terminal-notifier)         │  │
│  │  └── WebSocket + REST API                             │  │
│  └───────────────────────────────────────────────────────┘  │
│           │                           │                     │
│           │ spawns                    │ WebSocket           │
│           ▼                           ▼                     │
│  ┌─────────────┐              ┌─────────────────────┐      │
│  │ CC sessions │              │ homelab-dashboard   │      │
│  │ (Terminal)  │              │ (192.168.20.19)     │      │
│  └─────────────┘              └─────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Data Model

### Entity

```yaml
id: CC-snowmelt           # Unique identifier
type: cc                  # cc | pm
name: "Snowmelt Expert"   # Human-readable name
directory: ~/dkSRC/signalk/signalk-snowmelt
repo: dougkimmerly/signalk-snowmelt
capabilities:
  - weather
  - C4-TCP
  - thermostat
auto_spawn: true          # Spawn when message arrives?
status: idle              # idle | running | busy
pid: null                 # Process ID if running
last_seen: 2025-12-29T17:00:00Z
```

### Message

```yaml
id: MSG-20251229-001      # Unique ID
from: PM-web-001          # Sender entity ID
to: CC-snowmelt           # Recipient entity ID
timestamp: 2025-12-29T17:00:00Z
type: task                # task | response | query | ack
ref: null                 # Reply-to message ID (threading)
status: pending           # pending | claimed | complete | failed
priority: normal          # critical | high | normal | low
payload: |
  Document the TCP protocol for C4 integration.
  Include message formats and code locations.
expires: null             # Optional TTL
```

## Directory Structure

```
~/.claude-broker/
├── config.yaml           # Broker configuration
├── entities.yaml         # Registered entities
├── messages.db           # SQLite message store
├── logs/
│   └── broker.log        # Service logs
├── sessions/
│   ├── CC-snowmelt.pid   # Running session PIDs
│   └── CC-homelab.pid
└── github/
    ├── last_sync         # Timestamp of last GitHub poll
    └── token             # GitHub PAT (gitignored)
```

## Configuration

```yaml
# ~/.claude-broker/config.yaml
broker:
  port: 9500
  host: 0.0.0.0           # Allow dashboard connection

github:
  enabled: true
  repo: dougkimmerly/claude-messages
  poll_interval: 300      # 5 minutes
  # token stored in ~/.claude-broker/github/token

notifications:
  enabled: true
  sound: true
  
sessions:
  terminal: Terminal.app  # or iTerm.app
  shell: /bin/zsh
  auto_spawn: true        # Spawn on message arrival

logging:
  level: info
  file: ~/.claude-broker/logs/broker.log
```

## API

### WebSocket (ws://192.168.20.150:9500/ws)

**Server → Client Events:**

```json
// Entity status update
{
  "event": "entity_status",
  "data": {
    "id": "CC-snowmelt",
    "status": "running",
    "inbox_count": 0,
    "outbox_count": 1
  }
}

// New message notification
{
  "event": "message_new",
  "data": {
    "id": "MSG-20251229-001",
    "from": "PM-web-001",
    "to": "CC-snowmelt",
    "type": "task",
    "preview": "Document the TCP protocol..."
  }
}

// Session spawned
{
  "event": "session_spawned",
  "data": {
    "entity": "CC-snowmelt",
    "pid": 12345
  }
}

// Full state broadcast (on connect, every 30s)
{
  "event": "state_sync",
  "data": {
    "entities": [...],
    "pending_messages": 3,
    "active_sessions": 2
  }
}
```

**Client → Server Commands:**

```json
// Spawn a session
{ "command": "spawn", "entity": "CC-snowmelt" }

// Send a message
{ 
  "command": "send",
  "to": "CC-homelab",
  "type": "task",
  "payload": "What's the C4 controller IP?"
}

// Sync with GitHub now
{ "command": "github_sync" }

// Get entity details
{ "command": "get_entity", "id": "CC-snowmelt" }
```

### REST API (http://192.168.20.150:9500/api)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/entities` | GET | List all entities |
| `/api/entities/:id` | GET | Get entity details |
| `/api/entities/:id` | PUT | Update entity (register) |
| `/api/messages` | GET | List messages (query params for filtering) |
| `/api/messages` | POST | Send a message |
| `/api/messages/:id` | GET | Get message details |
| `/api/sessions` | GET | List running sessions |
| `/api/sessions/:entity` | POST | Spawn session |
| `/api/sessions/:entity` | DELETE | Kill session |
| `/api/github/sync` | POST | Trigger GitHub sync |
| `/api/status` | GET | Broker health/status |

## Session Spawning

When a message arrives for an idle CC entity with `auto_spawn: true`:

```bash
# Using osascript to open Terminal with command
osascript -e '
tell application "Terminal"
    activate
    do script "cd ~/dkSRC/signalk/signalk-snowmelt && claude"
end tell
'
```

The broker:
1. Detects new message for CC-snowmelt
2. Checks if CC-snowmelt is running (PID file)
3. If not running and auto_spawn=true, spawns session
4. Records PID in sessions/CC-snowmelt.pid
5. Session checks `/broker inbox` on startup (via CLAUDE.md instruction)

## CC Integration

Each CC project's CLAUDE.md includes:

```markdown
## Broker Integration

On session start, check for pending messages:
1. Run: `curl -s http://localhost:9500/api/messages?to=CC-snowmelt&status=pending`
2. Or use: `/broker inbox` command

To send messages:
```bash
curl -X POST http://localhost:9500/api/messages \
  -H "Content-Type: application/json" \
  -d '{"to":"CC-homelab","type":"query","payload":"What is the C4 IP?"}'
```

Or use: `/broker send CC-homelab "What is the C4 IP?"`
```

## GitHub Sync

The broker syncs with `claude-messages` repo for PM communication:

**Inbound (GitHub → Local):**
1. Poll repo every 5 minutes (or webhook trigger)
2. Check `inbox/CC-*/` directories for new files
3. Import messages to local SQLite
4. Trigger notifications/spawns as needed

**Outbound (Local → GitHub):**
1. When CC sends message to PM-*
2. Write to `outbox/PM-*/MSG-xxx.yaml`
3. Commit and push to GitHub
4. PM fetches on next session start

## Notifications

When a message requires human attention:

```bash
# macOS notification via terminal-notifier
terminal-notifier \
  -title "Claude Broker" \
  -subtitle "Response from CC-snowmelt" \
  -message "TCP protocol documentation ready" \
  -sound default \
  -open "claude://messages/MSG-20251229-001"
```

Notification triggers:
- Response ready for PM (requires you to start PM session)
- CC session spawned
- Message failed/expired
- Broker errors

## Implementation Stack

| Component | Technology |
|-----------|------------|
| Runtime | Node.js (matches dashboard stack) |
| HTTP/WS | Express + ws |
| Database | SQLite (better-sqlite3) |
| Config | yaml |
| Process | child_process + osascript |
| Notifications | terminal-notifier |
| Daemon | launchd |
| GitHub | octokit or simple fetch |

## Launchd Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dougkimmerly.claude-broker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/Users/doug/dkSRC/tools/claude-broker/index.js</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/doug/.claude-broker/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/doug/.claude-broker/logs/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

## Dashboard Panel

homelab-dashboard adds a "Message Broker" panel:

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Message Broker                    [Sync] [Settings] │
├─────────────────────────────────────────────────────────────┤
│  ENTITIES                                                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Entity          Status      Inbox   Outbox   Actions   ││
│  │ ─────────────────────────────────────────────────────── ││
│  │ PM-web-001      ⏳ waiting    -       2 ●    [View]    ││
│  │ CC-snowmelt     🟢 running    0       1      [Stop]    ││
│  │ CC-homelab      ⚪ idle       3 ●     0      [Spawn]   ││
│  │ CC-anchor       ⚪ idle       0       0      [Spawn]   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  RECENT MESSAGES                                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ 17:05 PM-web → CC-snowmelt [task] Document TCP proto... ││
│  │ 17:12 CC-snowmelt → PM-web [resp] Here's the protocol...││
│  │ 17:15 CC-homelab → CC-snow [query] What port for C4?   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  GitHub: Last sync 2 min ago │ 0 pending │ [Sync Now]      │
└─────────────────────────────────────────────────────────────┘
```

## Repo Location

```
dougkimmerly/claude-broker/
├── CLAUDE.md              # Project context for CC
├── src/
│   ├── index.js           # Entry point
│   ├── server.js          # Express + WebSocket
│   ├── database.js        # SQLite operations
│   ├── entities.js        # Entity management
│   ├── messages.js        # Message routing
│   ├── sessions.js        # Terminal spawning
│   ├── github.js          # GitHub sync
│   └── notifications.js   # macOS notifications
├── package.json
└── install.sh             # Sets up launchd, directories
```

## Future Enhancements

- [ ] MCP server integration (expose broker as MCP tools)
- [ ] Message encryption for sensitive payloads
- [ ] Rate limiting per entity
- [ ] Message TTL and auto-cleanup
- [ ] Session health monitoring
- [ ] Broker clustering (multiple Macs?)
- [ ] Web UI for broker (beyond dashboard panel)
