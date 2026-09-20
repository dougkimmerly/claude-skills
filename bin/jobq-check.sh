#!/usr/bin/env bash
# SessionStart hook: announce this repo's batchq queue (if registered) so every
# session starts queue-aware — jobs may be running/held right now, and work in
# this repo should flow THROUGH the queue (see the batchq skill). Silent when
# the repo has no registered queue.
#
# messaging-plane M1-S4: also peek-summarizes the workspace entity's unread
# msgq inbox (depth only) — PEEK, never advance (r3 R3-F06: a SessionStart
# that both counts AND advances marks messages read while only ever showing
# a count; UserPromptSubmit, M1-S5, is the only advancer).
#
# cwd->queue resolution (both the banner below and the peek) goes through
# `whichq.sh`'s `default_entity discovery` (messaging-plane M1-S1a, the one
# cwd->entity implementation) instead of a locally sed-parsed REPO= match.
# This script used to carry its OWN REPO= parser for the banner, separate
# from the peek's whichq.sh call, and the two diverged once already: an
# empty REPO= on a REMOTE-STUB config degrades a naive glob match to "/*",
# matching every absolute path on the host (r3 R3-F05) — the peek was built
# stub-safe from the start, but the banner's own parser had to be
# independently patched with a `[ -n "$repo" ] || continue` guard on
# 2026-08-24, and even that guard alone still let a REPO-less stub's
# alphabetic position in the loop clobber an EARLIER, correct real-REPO
# match (fixer cross-domain report 2026-08-25: opening the fixer repo
# announced "JOBQ SHARD" because "shard" sorted after "fixer" and its empty
# REPO overwrote the loop's `q` on every later iteration). whichq.sh's
# resolve() does proper longest-prefix matching across ALL queues at once
# instead of last-match-wins, so retiring the banner's own parser in favour
# of the one whichq.sh implementation removes this whole class of bug.
#
# The inbox itself lives only on the worker host (homecore, ADR 0049) — this
# script runs `msgq peek <entity>` over ssh there (engine/config's
# WORKER_HOST_SSH, the same target sbmjob forwards to), never locally.
set -u
ROOT="${BATCHQ_ROOT:-$HOME/.batchq}"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
whichq="$ROOT/engine/whichq.sh"
q=""
if [ -f "$whichq" ]; then
  q=$(cd "$dir" 2>/dev/null && ROOT="$ROOT" zsh -c '
    source "$1"
    default_entity discovery
  ' _ "$whichq" 2>/dev/null)
fi
[ -n "$q" ] || exit 0
Q="$ROOT/$q"
count() { ls "$1"/*.job 2>/dev/null | wc -l | tr -d ' '; }
run=$(count "$Q/running"); que=$(count "$Q/queue"); hld=$(count "$Q/held")
msgw=""
[ -f "$Q/MSGW" ] && msgw=$(head -1 "$Q/MSGW")
state="idle"
[ "$run" -gt 0 ] && state="ACTIVE ($run running)"
[ -n "$msgw" ] && state="HELD (MSGW)"

# --- M1-S4: unread-inbox peek (depth only, no cursor advance) -------------
# entity == $q: both come from the same default_entity discovery call above.
inbox_note=""
entity="$q"
conf="$ROOT/engine/config"
[ -f "$conf" ] && . "$conf" 2>/dev/null
[ -f "$conf.local" ] && . "$conf.local" 2>/dev/null  # per-host overrides, untracked
: "${WORKER_HOST_NAME:=homecore}"; : "${WORKER_HOST_SSH:=doug@192.168.20.19}"
if [ "$(hostname -s 2>/dev/null)" = "$WORKER_HOST_NAME" ]; then
  peek_out=$("$ROOT/engine/msgq" peek "$entity" 2>/dev/null)
else
  peek_out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$WORKER_HOST_SSH" \
    "~/.batchq/engine/msgq peek '$entity'" 2>/dev/null)
fi
unread=$(printf '%s\n' "$peek_out" | awk '/unread$/{print $(NF-1); exit}')  # portable: BSD sed rejects the GNU form (this runs on the Mac)
if [ -n "${unread:-}" ] && [ "$unread" -gt 0 ] 2>/dev/null; then
  plural=""; [ "$unread" = "1" ] || plural="s"
  inbox_note="📬 $unread unread message${plural} for $entity — ~/.batchq/engine/msgq read"
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
