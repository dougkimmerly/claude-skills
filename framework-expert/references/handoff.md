# Handoff System Reference

Complete PM↔CC coordination protocol.

## System Overview

The handoff system enables asynchronous task coordination between:
- **PM (Project Manager):** Web Claude instances that plan and coordinate
- **CC (Claude Code):** CLI Claude instances that execute code changes

## Directory Structure

```
.claude/handoff/
├── todo/                        # PM writes tasks here
│   ├── 20231229-143000-add-feature.md
│   └── 20231229-150000-fix-bug.md
├── complete/                    # CC writes responses here
│   └── 20231229-143000-add-feature.md
└── archive/                     # Both archive completed work
    ├── 20231229-120000-old-task.md
    └── 20231229-120000-old-task-response.md
```

## File Naming Convention

```
YYYYMMDD-HHMMSS-brief-description.md
```

**Examples:**
- `20231229-143527-implement-auth.md`
- `20231229-150342-fix-validation-bug.md`
- `20231230-091234-refactor-api.md`

**Rules:**
- Timestamp when task was created
- Brief description (3-5 words)
- Lowercase, hyphen-separated
- `.md` extension

## Task File Format

PM writes this in `.claude/handoff/todo/`:

```markdown
# Task: [Brief description]

**Created:** 2023-12-29 14:35:27
**Priority:** high|medium|low
**Type:** feature|bug|refactor|docs|test

## Context
Background information about why this task is needed.
Links to related issues, PRs, or discussions.

## Requirements
- Specific requirement 1
- Specific requirement 2
- Specific requirement 3

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Files to Consider
- `src/path/to/file1.js` - description
- `src/path/to/file2.js` - description

## Related Issues
Fixes #123
Relates to #456
```

### Field Descriptions

| Field | Required | Purpose |
|-------|----------|---------|
| Created | Yes | Timestamp when PM created task |
| Priority | Yes | high/medium/low - helps CC prioritize |
| Type | Yes | Categorizes work type |
| Context | Yes | Why this task exists |
| Requirements | Yes | What needs to be done |
| Acceptance Criteria | Yes | How to verify success |
| Files to Consider | Optional | Hint which files likely need changes |
| Related Issues | Optional | Links to GitHub issues |

## Response File Format

CC writes this in `.claude/handoff/complete/`:

```markdown
# Response: [Task description]

**Completed:** 2023-12-29 15:42:18
**Status:** success|partial|blocked
**Task File:** 20231229-143527-implement-auth.md

## Summary
Brief summary of what was accomplished.

## Changes Made
- `src/auth/login.js` - Added JWT authentication
- `src/middleware/auth.js` - Created auth middleware
- `tests/auth.test.js` - Added authentication tests

## Testing
How changes were verified:
- Unit tests: `npm test` - all passing
- Manual testing: tested login flow locally
- Edge cases: tested invalid credentials, expired tokens

## Issues Encountered
- Initial approach with sessions didn't work
- Switched to JWT tokens instead
- Required adding new dependency: `jsonwebtoken`

## Follow-up Needed
- [ ] PM should review security approach
- [ ] May need to add token refresh mechanism
- [ ] Consider rate limiting for login attempts

## Related Commits
- abc123f - Add JWT authentication
- def456a - Add auth middleware
- ghi789b - Add authentication tests
```

### Field Descriptions

| Field | Required | Purpose |
|-------|----------|---------|
| Completed | Yes | Timestamp when CC finished |
| Status | Yes | success/partial/blocked |
| Task File | Yes | Links back to original task |
| Summary | Yes | What was done |
| Changes Made | Yes | List of file changes |
| Testing | Yes | How it was verified |
| Issues Encountered | Optional | Problems faced |
| Follow-up Needed | Optional | What's left or needs review |
| Related Commits | Optional | Git commit SHAs |

### Status Values

| Status | Meaning | When to Use |
|--------|---------|-------------|
| `success` | Task fully completed | All requirements met, tests passing |
| `partial` | Some progress made | Blocked or ran out of time |
| `blocked` | Cannot proceed | Missing info, external dependency |

## Workflow: PM Perspective

### Creating a Task

1. **Decide what needs to be done**
   - Reference GitHub issues
   - Be specific about requirements

2. **Create task file in `todo/`:**
   ```bash
   # Via GitHub MCP:
   github:create_or_update_file
     path: .claude/handoff/todo/20231229-143527-task-name.md
     content: [task format above]
     message: "Add task: task-name"
   ```

3. **Notify broker (if using):**
   ```bash
   # Broker automatically notifies CC on next poll
   # No action needed from PM
   ```

4. **Wait for response in `complete/`**

### Reading a Response

1. **Check `complete/` directory:**
   ```bash
   github:get_file_contents
     path: .claude/handoff/complete/
   ```

2. **Read response file** matching task name

3. **Verify changes:**
   - Review changed files
   - Check test results
   - Validate acceptance criteria met

4. **Archive completed work:**
   ```bash
   # Move both task and response to archive/
   github:create_or_update_file
     path: .claude/handoff/archive/20231229-143527-task-name.md
   github:create_or_update_file
     path: .claude/handoff/archive/20231229-143527-task-name-response.md

   # Delete from todo/ and complete/
   ```

## Workflow: CC Perspective

### Checking for Tasks

User runs: `msg`

Hook script does:
```bash
#!/bin/bash
# .claude/hooks/prompt-submit.sh

# Match pattern: user types "msg"
if [[ "$USER_MESSAGE" == "msg" ]]; then
  # Pull latest from remote
  git pull origin main

  # Check for tasks
  TASKS=$(ls .claude/handoff/todo/*.md 2>/dev/null | wc -l)

  if [ "$TASKS" -gt 0 ]; then
    echo "✅ Found $TASKS task(s) in queue"
    ls -1 .claude/handoff/todo/
  else
    echo "✅ No tasks in queue"
  fi
fi
```

### Processing a Task

1. **Read task file:**
   ```bash
   cat .claude/handoff/todo/20231229-143527-implement-auth.md
   ```

2. **Understand requirements** - read carefully:
   - Context
   - Requirements
   - Acceptance criteria
   - Related files

3. **Execute the work:**
   - Make code changes
   - Write tests
   - Run tests
   - Commit changes

4. **Write response** in `complete/`:
   ```bash
   # Use Write tool to create response
   .claude/handoff/complete/20231229-143527-implement-auth.md
   ```

5. **Move task to archive:**
   ```bash
   mv .claude/handoff/todo/20231229-143527-implement-auth.md \
      .claude/handoff/archive/
   ```

6. **Commit and push:**
   ```bash
   git add .
   git commit -m "Complete task: implement-auth"
   git push origin main
   ```

## Broker Integration

The broker coordinates task routing between PM and CC.

### Registration (CC on Startup)

```bash
# .claude/hooks/prompt-submit.sh runs on startup
curl -X POST http://localhost:9500/register \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "CC-projectname",
    "entity_type": "CC",
    "repo": "dougkimmerly/projectname",
    "directory": "/Users/doug/Programming/dkSRC/projectname"
  }'
```

### Task Polling (CC)

```bash
# When user runs: msg
curl http://localhost:9500/tasks/CC-projectname
```

Broker returns:
```json
{
  "entity_id": "CC-projectname",
  "tasks": [
    {
      "file": "20231229-143527-implement-auth.md",
      "priority": "high",
      "created": "2023-12-29T14:35:27Z"
    }
  ]
}
```

### Task Notification (PM)

When PM creates task:
```bash
# Broker watches repo's .claude/handoff/todo/ directory
# Automatically detects new .md files
# Adds to task queue for registered CC
```

## Common Patterns

### Multi-Step Task

PM breaks into multiple tasks:
```
.claude/handoff/todo/
├── 20231229-140000-step1-setup-db.md
├── 20231229-140100-step2-create-api.md
└── 20231229-140200-step3-add-tests.md
```

Each task references previous steps in Context section.

### Blocked Task

CC encounters blocker:

```markdown
# Response: Implement payment integration

**Status:** blocked

## Summary
Cannot proceed without payment provider credentials.

## Changes Made
- Created payment service stub
- Added configuration placeholders

## Blocking Issues
- Need Stripe API keys (production and test)
- Need webhook secret for Stripe events

## Follow-up Needed
- [ ] PM to provide Stripe credentials in .env
- [ ] PM to configure webhook endpoint in Stripe dashboard
```

PM responds with new task:
```markdown
# Task: Provide Stripe credentials

**Type:** configuration

## Requirements
- Add Stripe API keys to .env
- Document webhook setup in README
```

### Iterative Refinement

CC completes task with `partial` status:

```markdown
**Status:** partial

## Summary
Basic authentication working, but needs security review.

## Follow-up Needed
- [ ] Review token expiration logic
- [ ] Add rate limiting
- [ ] Add logging for failed attempts
```

PM creates follow-up tasks for each item.

## Best Practices

### For PM

1. **Be specific** - Clear requirements prevent back-and-forth
2. **Reference issues** - Link to GitHub issues for context
3. **Prioritize explicitly** - Don't make CC guess importance
4. **Break down large tasks** - Smaller tasks = faster feedback
5. **Archive regularly** - Keep queues clean

### For CC

1. **Read carefully** - Understand all requirements before starting
2. **Test thoroughly** - Run all tests before responding
3. **Document changes** - List every file touched
4. **Commit frequently** - Small, logical commits
5. **Ask when blocked** - Use "blocked" status early

### For Both

1. **Use consistent naming** - Follow timestamp-description pattern
2. **Archive completed work** - Don't let queues grow
3. **Link to issues** - Maintain traceability
4. **Be explicit about status** - success/partial/blocked
5. **Keep responses in sync** - Response filename matches task filename

## Troubleshooting

### Task not appearing in CC queue

**Possible causes:**
- CC didn't pull latest from remote
- Task file not in `todo/` directory
- Filename doesn't match `*.md` pattern
- Broker not running

**Fix:**
```bash
git pull origin main
ls .claude/handoff/todo/
```

### Response not visible to PM

**Possible causes:**
- CC didn't push to remote
- Response in wrong directory
- GitHub MCP not refreshing

**Fix:**
```bash
git push origin main
ls .claude/handoff/complete/
```

### Duplicate task processing

**Possible causes:**
- Multiple CC instances running
- Task not moved to archive
- Git conflicts in handoff/

**Fix:**
- Only one CC per project
- Always move processed tasks to archive/
- Resolve git conflicts before processing

## Migration from Legacy System

Old system used single files:
- `.claude/handoff-queue.md`
- `.claude/task-queue.md`

New system uses directories:
- `.claude/handoff/todo/`
- `.claude/handoff/complete/`
- `.claude/handoff/archive/`

**Migration steps:**

1. Create new directory structure:
   ```bash
   mkdir -p .claude/handoff/{todo,complete,archive}
   ```

2. Split old queue into individual task files

3. Delete legacy files:
   ```bash
   rm .claude/handoff-queue.md
   rm .claude/task-queue.md
   ```

4. Update CLAUDE.md to reference new structure

5. Commit changes:
   ```bash
   git add .claude/
   git commit -m "Migrate to new handoff system"
   git push
   ```
