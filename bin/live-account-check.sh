#!/bin/bash
# live-account-check.sh — SessionStart hook: is this repo's LIVE account the one
# that just started?
#
# Wrong-identity is the silent failure. Skills and CLAUDE.md are symlinked, so
# they load either way and the session looks completely normal — right up until
# memory is missing and it starts writing a SECOND, diverging copy that the next
# correct session will not see. By then both sides need a hand merge.
#
# So: announce it FIRST, before any work. This hook cannot switch — the config
# dir is fixed at launch — so it tells the human and the session what is live and
# exactly how to get there, and leaves the decision to Doug.
#
# SILENT and exit 0 when the identity matches, when the repo is unregistered
# (never nag a repo Doug has not placed), or outside a git repo — zero cost to
# every session that is fine.
#
# Wired into the SessionStart hooks of EVERY identity's settings.json; an
# identity without it is exactly the one that will not warn you.

set -uo pipefail
ID="$HOME/.claude/skills/bin/claude-identity.sh"
[ -x "$ID" ] || exit 0

repo=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$repo" ] && exit 0

live=$("$ID" get "$repo" 2>/dev/null) || exit 0     # unregistered → silent
cur=$(python3 -c "import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))" \
      "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" 2>/dev/null)
[ "$cur" = "$live" ] && exit 0                       # correct identity → silent

started=$("$ID" describe "$cur" 2>/dev/null)
live_line=$("$ID" describe "$live" 2>/dev/null)
live_cmd=$("$ID" launcher "$live" 2>/dev/null)

cat <<EOF
⚠️  WRONG ACCOUNT FOR THIS REPO — say this to Doug before anything else.

  repo:    ${repo/#$HOME/~}
  started: $started
  LIVE:    $live_line

This session is NOT the live account for this repo. Its memory, history and
resumable sessions live under the live account, not here — working on anyway
starts a second, diverging copy that must later be merged by hand.

Tell Doug immediately: this is not the live account, the live one is
'$live_line', and ask whether he wants to switch. Do not start work first.
An identity cannot be changed mid-session; switching means ending this one:

  cd ${repo/#$HOME/~} && $live_cmd

If he chooses to stay, that is his call — say plainly that memory will diverge,
and use the 'account-switch' skill when he does move.
EOF
exit 0
