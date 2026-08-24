#!/usr/bin/env bash
# UserPromptSubmit hook: messaging-plane M1-S5 (the CRUX, DoD5) — surfaces
# NEW msgq messages for the workspace entity as a terse, capped
# system-reminder between turns, no polling required.
#
# This is THE ONLY cursor-advancer (r3 R3-F06): SessionStart (M1-S4) only
# peeks. Overflow rule (r3 R3-F07): show at most MSGQ_HOOK_CAP (default 5)
# of the oldest unread messages, advance the cursor past EXACTLY those shown
# (never past the whole backlog, never past none) and, if any remain
# unread, end the block with a "+K more — msgq read" line pointing at the
# manual escape hatch (M1-S3). This is what `msgq read --cap N` (M1-S5)
# exists to do — see msgq's own header comment.
#
# Consumer gate (r2 R2-F03), per docs/messaging-plane/PROBE-RESULT.md's
# CONFIRM of P-M08 option (a): `UserPromptSubmit` DOES fire under `claude -p`
# (real probe, 2026-08-22), so this gate is load-bearing, not a no-op stub.
# Primary check: the worker's `BATCHQ_JOB` env export (P-M08(a), wired in
# M1-S1c/worker.sh). Corroborating fallback (probe's "belt"):
# `CLAUDE_CODE_ENTRYPOINT=sdk-cli`, which the probe observed `-p` sets and
# interactive does not — checked in ADDITION to, never instead of, the
# primary, since the probe explicitly warns this internal name could change
# across claude versions. Either signal alone is enough to no-op: a batch
# job's `-p` session must never drain or advance the interactive cursor.
#
# Kill switch: MSGQ_HOOK=off no-ops unconditionally (any consumer, gated or
# not) — an operator escape hatch independent of the consumer gate.
#
# Entity discovery mirrors M1-S4's jobq-check.sh exactly (same r3 R3-F05
# guard: whichq.sh's own `default_entity discovery`, never jobq-check's
# REPO sed-match loop, which degrades to "/*" on a REPO-less remote-stub
# config). The inbox lives only on the worker host (homecore, ADR 0049);
# this script runs `msgq read --cap N` there over ssh, same as S4's peek.
#
# Landing zone (P-M04, attended, substrate #5): ships here in the batchq
# engine repo; the live hook is `~/.claude/skills/bin/msgq-prompt-submit.sh`
# on the authoritative `~/.claude` host, registered by hand in that host's
# `~/.claude/settings.json` (untracked) — the worker never installs it.
set -u

[ "${MSGQ_HOOK:-}" = "off" ] && exit 0

# --- consumer gate (r2 R2-F03): a batch/-p session never reads or advances.
if [ -n "${BATCHQ_JOB:-}" ] || [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "sdk-cli" ]; then
  exit 0
fi

ROOT="${BATCHQ_ROOT:-$HOME/.batchq}"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
CAP="${MSGQ_HOOK_CAP:-5}"

whichq="$ROOT/engine/whichq.sh"
[ -f "$whichq" ] || exit 0

entity=$(cd "$dir" 2>/dev/null && ROOT="$ROOT" zsh -c '
  source "$1"
  default_entity discovery
' _ "$whichq" 2>/dev/null)
[ -n "$entity" ] || exit 0

conf="$ROOT/engine/config"
[ -f "$conf" ] && . "$conf" 2>/dev/null
: "${WORKER_HOST_NAME:=homecore}"; : "${WORKER_HOST_SSH:=doug@192.168.20.19}"

if [ "$(hostname -s 2>/dev/null)" = "$WORKER_HOST_NAME" ]; then
  out=$("$ROOT/engine/msgq" read "$entity" --cap "$CAP" 2>/dev/null)
else
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$WORKER_HOST_SSH" \
    "~/.batchq/engine/msgq read '$entity' --cap $CAP" 2>/dev/null)
fi
[ -n "$out" ] || exit 0

unread=$(printf '%s\n' "$out" | sed -n '1{s/^[^:]*: \([0-9]\{1,\}\) unread$/\1/p}')
[ -n "${unread:-}" ] && [ "$unread" -gt 0 ] 2>/dev/null || exit 0

remaining=$(printf '%s\n' "$out" | sed -n 's/^[^:]*: \([0-9]\{1,\}\) remaining$/\1/p')
[ -n "${remaining:-}" ] || remaining=0

lines=$(printf '%s\n' "$out" | grep '^{')
[ -n "$lines" ] || exit 0

detail=$(printf '%s\n' "$lines" | jq -r \
  '"- [" + .queue + "] " + .job + ": " + .disposition + (if .summary_ref != "" then " — " + .summary_ref else "" end)')

shown=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
plural=""; [ "$shown" = "1" ] || plural="s"

block="📬 $shown new message${plural} for $entity:
$detail"
if [ "$remaining" -gt 0 ] 2>/dev/null; then
  block="$block
+$remaining more — msgq read"
fi

jq -n --arg ctx "$block" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
