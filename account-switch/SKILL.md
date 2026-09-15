---
name: account-switch
description: Wrap up a session cleanly before Doug switches Claude accounts (hit a usage limit, moved onto extra credits, or just changing identity), and verify the new identity afterwards. Use when Doug says "I need to switch accounts", "we're on extra credits", "I'm nearly out of tokens", "wrap up so I can switch", "prepare to switch", or when a session opens under a different identity and something that was there yesterday is missing. Covers what does and does not survive a config-dir switch, the land-the-work checklist, moving per-project memory, and the batch worker's SEPARATE account (switching the Mac does not move unattended spend).
---

# account-switch — finish up and change identity

Each Claude identity on this Mac is a **separate `CLAUDE_CONFIG_DIR`**, selected
by how the session was started. Discover them, never assume:

```bash
alias | grep '^claude-'                  # the launchers
echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"   # which one THIS session is using
```

Read the account behind any config dir:

```bash
python3 -c "
import json,os,sys
d=json.load(open(os.path.expanduser(sys.argv[1]+'/.claude.json')))
a=d.get('oauthAccount',{})
print(a.get('emailAddress'), '|', a.get('organizationName'))
" ~/.claude-kbl
```

## Why this skill exists

A switch is not a login — it is a **different directory**. Everything the
session leans on silently splits in two. The failure mode is discovering that
*after* switching, mid-task, with the old session's context gone.

**Does NOT survive the switch** (per config dir, invisible from the new one):

| What | Where |
|---|---|
| **Per-project memory** | `<config>/projects/*/memory/` — the `MEMORY.md` index + fact files |
| Conversation history | `<config>/history.jsonl` |
| `--resume` / `--continue` sessions | `<config>/sessions/` |
| Saved plans, todos, file-history | `<config>/plans/`, `<config>/file-history/` |

**Survives** — only if the new config dir was set up to share it. Symlinked or
absolute-path content resolves from one home regardless of identity:
`skills/`, `CLAUDE.md`, `commands/`, `settings.json` hooks + statusline,
plugin cache.

**Neither** — account-level OAuth grants, held by the Claude account and not on
disk at all: **connectors** (Gmail, Calendar, Drive, memory bridges). These must
be re-authorised in the new account's own settings. Local MCP servers are config,
and do carry; connectors do not.

## The trap: unattended spend does not follow you

**The batch worker authenticates as its own account, independently of the Mac.**
Switching an interactive session changes nothing about what batchq burns. Check
before assuming the switch solved a limit problem:

```bash
ssh 192.168.20.13 'python3 -c "
import json,os
a=json.load(open(os.path.expanduser(\"~/.claude.json\"))).get(\"oauthAccount\",{})
print(a.get(\"emailAddress\"))
"'
```

If that prints the account you are trying to move *off*, the queue keeps
spending it. Moving the worker is a separate, deliberate act — `claude
setup-token` on `192.168.20.13` under the new account — and it is **Doug's
call**, not a session's: the worker is unattended and shared by every repo's
queue, and `worker.sh` holds queues for re-login on an auth lapse
(`DECISIONS.md`, "batch worker plane self-manages auth").

## Wrap-up checklist

Run the diagnostic first; it does steps 1–4 read-only and prints what needs a
decision:

```bash
bash ~/.claude/skills/bin/account-switch-check.sh [target-config-dir]
```

**1. Land the work — commit AND push.** Push is not optional: the batch worker
pulls from origin, so unpushed commits mean queued jobs run against stale code.
Unpushed work is also invisible to the next identity in every practical sense.

**2. Move durable state out of the session and into a repo.** Anything the next
session must know goes in a file that git tracks, because the conversation will
not be there:
- status → that repo's `docs/STATUS.md`
- faults → `docs/PUNCHLIST.md`
- decisions → an ADR (`adr` skill)
- another repo's domain → a verify-first batchq job (`batchq` skill)
- a note for the next session *here* → `HANDOFF.md` at the repo root

**3. Decide what happens to memory.** Per-project memory is the biggest silent
loss — a new identity starts cold in every repo. Two honest options, and it is
Doug's choice:
- **Carry it** — copy the memory dirs into the target config dir. Safe: memory
  files are plain markdown, no credentials.
  ```bash
  for m in ~/.claude/projects/*/memory; do
    p=$(dirname "$m"); slug=$(basename "$p")
    mkdir -p "$TARGET/projects/$slug"
    cp -Rn "$m" "$TARGET/projects/$slug/"
  done
  ```
- **Start clean** — defensible when the new identity is for different work.
  Say so out loud; do not let it happen by accident.

**4. Check what is in flight.** Jobs already queued keep running under the
worker's account and will finish without you — but a job that ends in **MSGW**
needs a human, and its message routes to the submitting entity's inbox.

```bash
sbmjob -wrk
```

Do not queue new work you intend to supervise if you are about to lose the
session that supervises it.

**5. Leave the resume note.** Last thing written, first thing read: what you
were doing, what is decided, what the next session should pick up. `HANDOFF.md`
if it belongs to this repo; a Bosun todo if it is Doug's to do (`bosun-todo`).

## Switching

Start the new session from the repo you want to work in — the config dir is
chosen at launch and cannot be changed mid-session:

```bash
claude-kbl          # or whichever launcher the alias list showed
```

## Verify after switching

```bash
claude mcp list           # local MCP servers connected?
ls ~/.claude-kbl/skills   # skills resolving (symlink → one home)?
```

Then confirm in-session: skills listed, `CLAUDE.md` loaded, memory present or
knowingly absent. Connectors will be missing until re-authorised in the new
account — that is expected, not a fault.

## Setting up a new identity from scratch

```bash
# 1. alias in ~/.zshrc
alias claude-NEW='CLAUDE_CONFIG_DIR="$HOME/.claude-NEW" claude'
# 2. first run logs in and populates the dir
source ~/.zshrc && claude-NEW
# 3. share the one-home content
ln -sfn ~/.claude/CLAUDE.md ~/.claude-NEW/CLAUDE.md
ln -sfn ~/.claude/skills    ~/.claude-NEW/skills
ln -sfn ~/.claude/commands  ~/.claude-NEW/commands
cp ~/.claude/settings.json  ~/.claude-NEW/settings.json
cp ~/.claude/plugins/installed_plugins.json ~/.claude-NEW/plugins/
# 4. merge global MCP servers (back up .claude.json first)
```

**Symlink, never copy**, for skills and `CLAUDE.md`. A second copy of the
operating principles drifts, and a stale one is worse than none.
