# Broker API Reference

Complete broker registration and task routing documentation.

## Overview

The broker is a central coordination service running at `http://localhost:9500` that:
- Registers CC entities (Claude Code instances)
- Routes tasks between PM (web Claude) and CC (CLI Claude)
- Maintains entity directory
- Monitors task queues

## Broker URL

**Default:** `http://localhost:9500`

Set in each project's CLAUDE.md:
```markdown
## Entity Info

| Field | Value |
|-------|-------|
| **Broker** | `http://localhost:9500` |
```

## Endpoints

### Register Entity

**Endpoint:** `POST /register`

**Purpose:** CC entities register themselves on startup

**Request:**
```json
{
  "entity_id": "CC-projectname",
  "entity_type": "CC",
  "repo": "dougkimmerly/projectname",
  "directory": "/Users/doug/Programming/dkSRC/projectname"
}
```

**Response:**
```json
{
  "status": "registered",
  "entity_id": "CC-projectname",
  "timestamp": "2023-12-29T14:35:27Z"
}
```

**Example (from hook):**
```bash
#!/bin/bash
# .claude/hooks/prompt-submit.sh

curl -X POST http://localhost:9500/register \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "CC-projectname",
    "entity_type": "CC",
    "repo": "dougkimmerly/projectname",
    "directory": "/Users/doug/Programming/dkSRC/projectname"
  }'
```

### Get Tasks

**Endpoint:** `GET /tasks/{entity_id}`

**Purpose:** CC checks for pending tasks

**Request:**
```bash
curl http://localhost:9500/tasks/CC-projectname
```

**Response (with tasks):**
```json
{
  "entity_id": "CC-projectname",
  "tasks": [
    {
      "file": "20231229-143527-implement-auth.md",
      "priority": "high",
      "created": "2023-12-29T14:35:27Z",
      "type": "feature"
    },
    {
      "file": "20231229-150000-fix-validation.md",
      "priority": "medium",
      "created": "2023-12-29T15:00:00Z",
      "type": "bug"
    }
  ],
  "count": 2
}
```

**Response (no tasks):**
```json
{
  "entity_id": "CC-projectname",
  "tasks": [],
  "count": 0
}
```

### List Entities

**Endpoint:** `GET /entities`

**Purpose:** List all registered entities

**Request:**
```bash
curl http://localhost:9500/entities
```

**Response:**
```json
{
  "entities": [
    {
      "entity_id": "CC-projectname",
      "entity_type": "CC",
      "repo": "dougkimmerly/projectname",
      "directory": "/Users/doug/Programming/dkSRC/projectname",
      "registered_at": "2023-12-29T14:35:27Z",
      "last_seen": "2023-12-29T15:42:18Z"
    },
    {
      "entity_id": "CC-another-project",
      "entity_type": "CC",
      "repo": "dougkimmerly/another-project",
      "directory": "/Users/doug/Programming/dkSRC/another-project",
      "registered_at": "2023-12-29T10:00:00Z",
      "last_seen": "2023-12-29T15:30:00Z"
    }
  ],
  "count": 2
}
```

### Heartbeat

**Endpoint:** `POST /heartbeat/{entity_id}`

**Purpose:** Update last_seen timestamp

**Request:**
```bash
curl -X POST http://localhost:9500/heartbeat/CC-projectname
```

**Response:**
```json
{
  "entity_id": "CC-projectname",
  "last_seen": "2023-12-29T15:45:00Z"
}
```

## Entity Registration

### When to Register

CC entities MUST register:
- On first startup
- After broker restart
- When returning from long idle period

### Registration via Hook

Automated via `.claude/hooks/prompt-submit.sh`:

```bash
#!/bin/bash
# .claude/hooks/prompt-submit.sh

ENTITY_ID="CC-projectname"
BROKER_URL="http://localhost:9500"
REPO="dougkimmerly/projectname"
PROJECT_DIR="/Users/doug/Programming/dkSRC/projectname"

# Register with broker on startup (match on "msg" or startup pattern)
if [[ "$USER_MESSAGE" =~ ^(msg|startup)$ ]]; then
  RESPONSE=$(curl -s -X POST "$BROKER_URL/register" \
    -H "Content-Type: application/json" \
    -d "{
      \"entity_id\": \"$ENTITY_ID\",
      \"entity_type\": \"CC\",
      \"repo\": \"$REPO\",
      \"directory\": \"$PROJECT_DIR\"
    }")

  if [[ $? -eq 0 ]]; then
    echo "✅ Registered with broker: $ENTITY_ID"
  else
    echo "❌ Failed to register with broker"
  fi
fi
```

### Entity ID Format

**Pattern:** `CC-{projectname}`

**Examples:**
- `CC-framework` - claude-project-framework
- `CC-signalk55` - signalk55 project
- `CC-anchorAlarm` - signalk-anchorAlarmConnector

**Rules:**
- Prefix: `CC-` for Claude Code instances
- Project identifier: kebab-case or camelCase
- Unique across all projects

## Task Routing

### PM → CC (Task Creation)

1. **PM creates task file:**
   ```bash
   # Via GitHub MCP:
   github:create_or_update_file
     path: .claude/handoff/todo/20231229-143527-task.md
   ```

2. **Broker detects new file:**
   - Watches repo's `.claude/handoff/todo/` directory
   - Detects `*.md` files
   - Parses task metadata

3. **Broker adds to queue:**
   ```json
   {
     "entity_id": "CC-projectname",
     "task": {
       "file": "20231229-143527-task.md",
       "priority": "high",
       "created": "2023-12-29T14:35:27Z"
     }
   }
   ```

4. **CC polls for tasks:**
   ```bash
   # User runs: msg
   curl http://localhost:9500/tasks/CC-projectname
   ```

5. **CC processes task** and writes response

### CC → PM (Response)

1. **CC writes response:**
   ```bash
   .claude/handoff/complete/20231229-143527-task.md
   ```

2. **CC commits and pushes:**
   ```bash
   git add .
   git commit -m "Complete task: task-name"
   git push origin main
   ```

3. **PM polls for responses:**
   ```bash
   github:get_file_contents
     path: .claude/handoff/complete/
   ```

4. **PM reads and archives:**
   - Reads response
   - Verifies completion
   - Moves to archive

## Hook Integration

### Startup Registration

**Trigger:** User starts Claude Code session

**Hook:** `.claude/hooks/prompt-submit.sh`

```bash
# Match on startup or "msg" command
if [[ "$USER_MESSAGE" =~ ^(msg|startup)$ ]]; then
  # Register with broker
  curl -X POST http://localhost:9500/register ...

  # Pull latest from remote
  git pull origin main

  # Check for tasks
  curl http://localhost:9500/tasks/CC-projectname
fi
```

### Task Checking

**Trigger:** User types `msg`

**Hook:** Same as above, checks tasks after registration

**Output:**
```
✅ Registered with broker: CC-projectname
✅ Found 2 task(s) in queue:
  - 20231229-143527-implement-auth.md (high)
  - 20231229-150000-fix-validation.md (medium)
```

## Broker Configuration

### Environment Variables

Broker may use these (implementation-specific):

```bash
BROKER_PORT=9500
BROKER_HOST=localhost
BROKER_DB_PATH=/path/to/broker.db
BROKER_LOG_LEVEL=info
```

### Running the Broker

```bash
# Start broker service
npm start

# Or with PM2
pm2 start broker.js --name claude-broker

# Check status
pm2 status
```

### Broker Persistence

Broker maintains state in:
- In-memory registry (entities, tasks)
- Optional SQLite database
- Filesystem watch on `.claude/handoff/todo/`

## Error Handling

### Registration Failures

**Scenario:** Broker not running

**Error:**
```
curl: (7) Failed to connect to localhost port 9500: Connection refused
```

**Fix:**
```bash
# Start broker
npm start

# Or check if running
curl http://localhost:9500/entities
```

### Task Routing Failures

**Scenario:** Task not appearing in queue

**Possible causes:**
1. CC not registered
2. Task file malformed
3. Broker not watching repo

**Debug:**
```bash
# Check registration
curl http://localhost:9500/entities

# Check tasks
curl http://localhost:9500/tasks/CC-projectname

# Verify file exists
ls .claude/handoff/todo/
```

### Network Issues

**Scenario:** Intermittent connection

**Mitigation:**
- Hook retries registration
- Tasks persist in filesystem
- CC can process locally without broker

## Best Practices

### For CC

1. **Register on every startup** - Don't assume still registered
2. **Check tasks regularly** - Use `msg` command
3. **Pull before processing** - Ensure latest tasks
4. **Push after completing** - Make responses available

### For PM

1. **Use descriptive filenames** - Makes queue readable
2. **Set priority explicitly** - Don't rely on defaults
3. **Link to issues** - Maintain traceability
4. **Archive completed work** - Keep queues clean

### For Broker

1. **Monitor health** - Use heartbeats
2. **Log all routing** - Debug task issues
3. **Persist state** - Survive restarts
4. **Watch filesystem** - Detect new tasks

## Security Considerations

### Local-Only Broker

**Default setup:** Broker runs on localhost only

```bash
BROKER_HOST=127.0.0.1  # Not 0.0.0.0
```

**Why:** Prevents external access to task queue

### Authentication

**Current:** No authentication (local trust model)

**Future:** May add API keys for multi-user setups

### Task Content

**Warning:** Tasks may contain sensitive info

**Mitigation:**
- Private repos
- Local broker only
- No external task routing

## Monitoring

### Check Broker Status

```bash
curl http://localhost:9500/entities
```

### View Entity Details

```bash
curl http://localhost:9500/entities | jq '.'
```

### List Pending Tasks

```bash
curl http://localhost:9500/tasks/CC-projectname | jq '.'
```

### Monitor Logs

```bash
# If using PM2
pm2 logs claude-broker

# Or tail log file
tail -f broker.log
```

## Troubleshooting

### Broker won't start

**Check:**
- Port 9500 not in use: `lsof -i :9500`
- Node.js installed: `node --version`
- Dependencies installed: `npm install`

### Entity not appearing

**Check:**
- Registration succeeded
- Entity ID matches CLAUDE.md
- Broker running: `curl http://localhost:9500/entities`

### Tasks not routing

**Check:**
- CC registered: `curl http://localhost:9500/entities`
- Task files in `todo/`: `ls .claude/handoff/todo/`
- Broker watching repo
- Git pulled latest: `git pull`

### Multiple registrations

**Symptom:** Same entity appearing multiple times

**Fix:**
- Broker should deduplicate by entity_id
- Check for typos in entity IDs
- Restart broker to clear stale entries
