#!/bin/bash
# account-switch-check.sh — read-only pre-flight for the `account-switch` skill.
#
# SCOPE: the repo this is run in, and nothing else. Doug migrates repos to a new
# Claude identity ONE AT A TIME and decides each on its own evidence, so this
# never scans the estate and never reports another repo's state.
#
# A Claude identity here is a CLAUDE_CONFIG_DIR chosen at launch. Switching
# splits per-config state (memory, history, sessions) while symlinked content
# (skills, CLAUDE.md) stays shared. The failure mode is finding out AFTER the
# switch, mid-task, with the old session gone.
#
# Deliberately NOT covered: the batchq worker's own account. Unattended spend
# does not follow an interactive switch, and moving it is a separate decision
# with its own process.
#
# This reports; it never changes anything.
#
# Usage: account-switch-check.sh [target-config-dir]

set -uo pipefail
TARGET="${1:-}"
CUR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO" ]; then
  echo "Not inside a git repo — this skill is per-repo. cd to the repo first."
  exit 1
fi
SLUG="$(printf '%s' "$REPO" | sed 's|/|-|g')"

# The DEFAULT identity keeps its .claude.json at ~/.claude.json, NOT inside
# ~/.claude/; only a custom CLAUDE_CONFIG_DIR holds its own.
acct() {  # acct <config-dir> -> "email | org", or "" if unreadable
  python3 -c "
import json,os,sys
d=os.path.realpath(os.path.expanduser(sys.argv[1]))
p=(os.path.expanduser('~/.claude.json')
   if d==os.path.realpath(os.path.expanduser('~/.claude'))
   else d+'/.claude.json')
try:
    a=json.load(open(p)).get('oauthAccount',{})
    print(f\"{a.get('emailAddress','?')} | {a.get('organizationName','?')}\")
except Exception:
    pass
" "$1" 2>/dev/null
}

echo "═══ Repo ═══"
echo "  ${REPO/#$HOME/~}"

echo
echo "═══ Identity ═══"
echo "  current: ${CUR/#$HOME/~}"
echo "           $(acct "$CUR")"
if [ -n "$TARGET" ]; then
  echo "  target:  ${TARGET/#$HOME/~}"
  if [ -d "$TARGET" ]; then
    echo "           $(acct "$TARGET")"
  else
    echo "           ⚠️  does not exist — see 'Setting up a new identity' in the skill"
  fi
fi

echo
echo "═══ Unlanded work (commit AND push — the worker pulls from origin) ═══"
cd "$REPO" || exit 1
dirty="$(git status --porcelain 2>/dev/null)"
unpushed=""
if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  n=$(git rev-list --count "${up}..HEAD" 2>/dev/null || echo 0)
  [ "$n" != "0" ] && unpushed="$n unpushed → $up"
else
  unpushed="no upstream branch — nothing is backed off this machine"
fi
[ -n "$unpushed" ] && echo "  ⚠️  $unpushed"
if [ -n "$dirty" ]; then
  echo "  ⚠️  $(printf '%s\n' "$dirty" | wc -l | tr -d ' ') file(s) uncommitted:"
  printf '%s\n' "$dirty" | head -10 | sed 's/^/        /'
fi
[ -z "$dirty" ] && [ -z "$unpushed" ] && echo "  ✔ committed and pushed"

echo
echo "═══ This repo's memory (does NOT follow the switch) ═══"
src="$CUR/projects/$SLUG/memory"
if [ -d "$src" ]; then
  echo "  $(ls "$src" 2>/dev/null | wc -l | tr -d ' ') file(s) in the current identity"
  if [ -n "$TARGET" ]; then
    if [ -d "$TARGET/projects/$SLUG/memory" ]; then
      echo "  ✔ already present in the target"
    else
      echo "  ⚠️  DECISION: carry it across, or knowingly start cold? (skill, step 3)"
    fi
  fi
else
  echo "  none recorded for this repo"
fi

echo
echo "═══ This repo's queue ═══"
if command -v sbmjob >/dev/null 2>&1; then
  qname="$(basename "$REPO")"
  wrk="$(sbmjob -wrk 2>/dev/null)"
  # Take only this repo's queue block, and drop its "recent done:" list — those
  # filenames contain words like "queued" and otherwise read as live work.
  mine="$(printf '%s\n' "$wrk" \
          | awk -v q="$qname" 'BEGIN{IGNORECASE=1}
              /^=== Queue/{inq = (tolower($0) ~ tolower(q)); skip=0}
              /recent done:/{skip=1}
              inq && !skip' \
          | grep -vE '^\s*\(empty\)|^\s*running: \(none\)' \
          | grep -E '^\s*running:|MSGW|HELD|^\s{4}[0-9]{8}-')"
  if [ -n "$(printf '%s' "$mine" | tr -d '[:space:]')" ]; then
    printf '%s\n' "$mine"
    echo "  → these finish under the worker's own account; an MSGW hold needs a human"
  else
    echo "  ✔ nothing running, queued, or held for this repo"
  fi
else
  echo "  ? sbmjob not on PATH"
fi

echo
echo "Remaining, and not automatable: land durable state in this repo (STATUS /"
echo "PUNCHLIST / ADR / HANDOFF), then write the resume note. See the skill."
