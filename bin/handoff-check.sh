#!/usr/bin/env bash
# SessionStart hook: surface the repo-root HANDOFF.md cross-session inbox.
# Convention: any Claude session that fixes/finds something in another repo's
# domain appends a "## <date> — from <who> — <title>" entry to that repo's
# HANDOFF.md and commits it. This hook guarantees the owning session sees it
# at startup (context injection), instead of hoping they run git status.
set -u
f="${CLAUDE_PROJECT_DIR:-.}/HANDOFF.md"
[ -f "$f" ] || exit 0
n=$(grep -c '^## ' "$f" 2>/dev/null) || n=0
[ "${n:-0}" -gt 0 ] 2>/dev/null || exit 0
jq -n --arg n "$n" '{
  systemMessage: ("📬 HANDOFF.md: " + $n + " pending item(s) from other sessions"),
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("The repo root contains HANDOFF.md — the cross-session inbox — with " + $n + " pending item(s) left by other Claude sessions (fixer, health, voice, ...). Read HANDOFF.md EARLY this session, before starting other work: each entry says what happened in this repo'\''s domain and what this session should do about it. When an item is handled, delete its section and commit (git history preserves the record). If an item is not yours to handle, leave it.")
  }
}'
