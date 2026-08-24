#!/usr/bin/env bash
# SessionStart hook: announce this repo's batchq queue (if registered) so every
# session starts queue-aware — jobs may be running/held right now, and work in
# this repo should flow THROUGH the queue (see the batchq skill). Silent when
# the repo has no registered queue.
#
# messaging-plane M1-S4: also peek-summarizes the workspace entity's unread
# msgq inbox (depth only) — PEEK, never advance (r3 R3-F06: a SessionStart
# that both counts AND advances marks messages read while only ever showing
# a count; UserPromptSubmit, M1-S5, is the only advancer). Entity discovery
# for the peek does NOT reuse the REPO sed-match loop above (r3 R3-F05: a
# REMOTE-STUB config has no `REPO=` line, so that match's `repo=""` degrades
# to the glob `"/*"` — every absolute path on the host — silently resolving
# every session's cwd to whichever remote stub is registered first, e.g.
# `dk-w5-ci`). Instead it sources `whichq.sh` (messaging-plane M1-S1a, the
# one cwd->entity implementation) and calls `default_entity discovery`,
# which explicitly skips remote-stub queues and returns "" (not "unknown")
# when nothing resolves — preserving "no queue -> exit 0/no note, silently"
# for the peek exactly as the queue-status block above already does.
#
# The inbox itself lives only on the worker host (homecore, ADR 0049) — this
# script runs `msgq peek <entity>` over ssh there (engine/config's
# WORKER_HOST_SSH, the same target sbmjob forwards to), never locally.
set -u
ROOT="${BATCHQ_ROOT:-$HOME/.batchq}"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
q=""
for c in "$ROOT"/*/config; do
  [ -f "$c" ] || continue
  name=$(basename "$(dirname "$c")")
  [ "$name" = "engine" ] && continue
  repo=$(sed -n 's/^REPO=//p' "$c" | tr -d '"')
  case "$dir/" in "$repo"/*|"$repo") q="$name"; Q="$ROOT/$name" ;; esac
done
[ -n "$q" ] || exit 0
count() { ls "$1"/*.job 2>/dev/null | wc -l | tr -d ' '; }
run=$(count "$Q/running"); que=$(count "$Q/queue"); hld=$(count "$Q/held")
msgw=""
[ -f "$Q/MSGW" ] && msgw=$(head -1 "$Q/MSGW")
state="idle"
[ "$run" -gt 0 ] && state="ACTIVE ($run running)"
[ -n "$msgw" ] && state="HELD (MSGW)"

# --- M1-S4: unread-inbox peek (depth only, no cursor advance) -------------
inbox_note=""
whichq="$ROOT/engine/whichq.sh"
if [ -f "$whichq" ]; then
  entity=$(cd "$dir" 2>/dev/null && ROOT="$ROOT" zsh -c '
    source "$1"
    default_entity discovery
  ' _ "$whichq" 2>/dev/null)
  if [ -n "$entity" ]; then
    conf="$ROOT/engine/config"
    [ -f "$conf" ] && . "$conf" 2>/dev/null
    : "${WORKER_HOST_NAME:=homecore}"; : "${WORKER_HOST_SSH:=doug@192.168.20.19}"
    if [ "$(hostname -s 2>/dev/null)" = "$WORKER_HOST_NAME" ]; then
      peek_out=$("$ROOT/engine/msgq" peek "$entity" 2>/dev/null)
    else
      peek_out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$WORKER_HOST_SSH" \
        "~/.batchq/engine/msgq peek '$entity'" 2>/dev/null)
    fi
    unread=$(printf '%s\n' "$peek_out" | head -1 | sed -n 's/^[^:]*: \([0-9]\{1,\}\) unread$/\1/p')
    if [ -n "${unread:-}" ] && [ "$unread" -gt 0 ] 2>/dev/null; then
      plural=""; [ "$unread" = "1" ] || plural="s"
      inbox_note="📬 $unread unread message${plural} for $entity — msgq read"
    fi
  fi
fi

jq -n --arg q "$q" --arg state "$state" --arg run "$run" --arg que "$que" \
      --arg hld "$hld" --arg msgw "$msgw" --arg inbox "$inbox_note" '{
  systemMessage: ("🗂  JOBQ " + ($q|ascii_upcase) + ": " + $state
                  + (if ($que|tonumber) > 0 then ", " + $que + " queued" else "" end)
                  + (if $inbox != "" then "  |  " + $inbox else "" end)),
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("This repo has a registered batchq job queue (\"" + $q
      + "\"): " + $run + " running, " + $que + " queued, " + $hld + " held"
      + (if $msgw != "" then "; MSGW: " + $msgw else "" end)
      + ". Jobs run in isolated git worktrees, so interactive edits are safe; "
      + "substantial build work in this repo should be SUBMITTED AS JOBS "
      + "(sbmjob — read the batchq skill before queue work), not built inline. "
      + "Monitor: http://localhost:8250/ or `sbmjob -wrk`; per-job results in "
      + "~/.batchq/" + $q + "/JOBLOG.md. If MSGW is set, read the marker + "
      + "held job log and resolve (fix or merge, then sbmjob -release) before "
      + "queuing more work."
      + (if $inbox != "" then " " + $inbox + "." else "" end))
  }
}'
