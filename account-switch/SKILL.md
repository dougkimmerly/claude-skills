---
name: account-switch
description: Wrap up THIS repo's session cleanly before Doug switches Claude accounts (hit a usage limit, moved onto extra credits, or just changing identity), and verify the new identity afterwards. One repo at a time — Doug migrates them individually. Use when Doug says "I need to switch accounts", "we're on extra credits", "I'm nearly out of tokens", "wrap up so I can switch", "prepare to switch", or when a session opens under a different identity and something that was there yesterday is missing. Covers what does and does not survive a config-dir switch, landing this repo's work, and carrying this repo's memory across.
---

# account-switch — finish this repo and change identity

**Scope: the repo this session is in. One at a time.** Doug migrates repos
individually and decides each on its own evidence. Do not scan the estate, do
not touch another repo's work, and do not batch several together.

Each Claude identity on this Mac is a **separate `CLAUDE_CONFIG_DIR`**, selected
by how the session was started. Discover them, never assume:

```bash
alias | grep '^claude-'                      # the launchers
echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"   # which one THIS session is using
```

## Why this skill exists

A switch is not a login — it is a **different directory**. Everything the
session leans on silently splits in two, and the failure mode is discovering it
*after* switching, mid-task, with the old session's context gone.

**Does NOT survive** (per config dir, invisible from the new one):

| What | Where |
|---|---|
| **This repo's memory** | `<config>/projects/<repo-slug>/memory/` — `MEMORY.md` + fact files |
| Conversation history | `<config>/history.jsonl` |
| `--resume` / `--continue` sessions | `<config>/sessions/` |
| Saved plans, todos, file-history | `<config>/plans/`, `<config>/file-history/` |

**Survives** — if the new config dir was set up to share it. Symlinked or
absolute-path content resolves from one home regardless of identity: `skills/`,
`CLAUDE.md`, `commands/`, `settings.json` hooks + statusline, plugin cache.

**Neither** — account-level OAuth grants, held by the account and not on disk:
**connectors** (Gmail, Calendar, Drive, memory bridges). Re-authorise them in
the new account if this repo's work needs them. Local MCP servers are config and
do carry; connectors do not.

## Not this skill's job

**Unattended spend does not follow an interactive switch.** The batchq worker
authenticates as its own account on its own host, so switching a session here
changes nothing about what the queue burns. Moving it is a **separate, deliberate
decision with its own process** — out of scope here. Do not touch the worker's
auth from a repo wrap-up.

## Wrap-up checklist

Read-only pre-flight for steps 1–3, scoped to this repo:

```bash
bash ~/.claude/skills/bin/account-switch-check.sh [target-config-dir]
```

**1. Land this repo's work — commit AND push.** Push is not optional: the batch
worker pulls from origin, so unpushed commits mean this repo's queued jobs run
against stale code. Unpushed work is also invisible to the next identity in
every practical sense.

**2. Move durable state out of the session and into the repo.** Anything the
next session must know goes in a tracked file, because the conversation will not
be there:
- status → `docs/STATUS.md`
- faults → `docs/PUNCHLIST.md`
- decisions → an ADR (`adr` skill)
- a note for the next session here → `HANDOFF.md` at the repo root
- another repo's domain → a verify-first batchq job (`batchq` skill), **not** a
  detour into that repo

**3. Carry this repo's memory, or knowingly start cold.** The single biggest
silent loss — without it the new identity starts this repo with no memory at
all. Memory files are plain markdown, no credentials, safe to copy.

```bash
SLUG=$(pwd | sed 's|/|-|g')          # e.g. -Users-doug-Programming-dkSRC-bosun
SRC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$SLUG/memory"
DST="$TARGET/projects/$SLUG"
mkdir -p "$DST" && cp -Rn "$SRC" "$DST/"
```

Starting cold is defensible when the new identity is for different work — but
say so out loud; do not let it happen by accident.

**4. Check this repo's queue.** Jobs already queued keep running under the
worker's own account and finish without you — but one that ends in **MSGW**
needs a human, and its message routes to this repo's inbox. Do not queue new
work you intend to supervise if you are about to lose the session that
supervises it.

**5. Leave the resume note.** Last written, first read: what you were doing,
what is decided, what to pick up. `HANDOFF.md` if it belongs to this repo; a
Bosun todo if it is Doug's to do (`bosun-todo`).

## Switching

The config dir is chosen at launch and cannot be changed mid-session. Start the
new one **from this repo's directory**:

```bash
cd <this repo> && claude-kbl      # or whichever launcher the alias list showed
```

## Verify after switching

```bash
claude mcp list                   # local MCP servers connected?
ls "$TARGET/skills"               # skills resolving (symlink → one home)?
ls "$TARGET/projects/$SLUG/memory" 2>/dev/null || echo "cold start (intended?)"
```

Then confirm in-session: skills listed, `CLAUDE.md` loaded, this repo's memory
present or knowingly absent. Connectors will be missing until re-authorised —
expected, not a fault.

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
# 4. merge global mcpServers into ~/.claude-NEW/.claude.json (back it up first)
```

**Symlink, never copy**, for skills and `CLAUDE.md`. A second copy of the
operating principles drifts, and a stale one is worse than none.
