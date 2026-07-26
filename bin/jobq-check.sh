#!/usr/bin/env bash
# SessionStart hook: announce this repo's batchq queue (if registered) so every
# session starts queue-aware — jobs may be running/held right now, and work in
# this repo should flow THROUGH the queue (see the batchq skill). Silent when
# the repo has no registered queue.
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
jq -n --arg q "$q" --arg state "$state" --arg run "$run" --arg que "$que" \
      --arg hld "$hld" --arg msgw "$msgw" '{
  systemMessage: ("🗂  JOBQ " + ($q|ascii_upcase) + ": " + $state
                  + (if ($que|tonumber) > 0 then ", " + $que + " queued" else "" end)),
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
      + "queuing more work.")
  }
}'
