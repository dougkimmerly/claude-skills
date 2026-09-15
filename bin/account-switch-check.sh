#!/bin/bash
# account-switch-check.sh — read-only pre-flight for the `account-switch` skill.
#
# A Claude identity on this Mac is a CLAUDE_CONFIG_DIR chosen at launch. Switching
# identity silently splits per-config state (memory, history, sessions) while
# leaving symlinked content (skills, CLAUDE.md) shared. The failure mode is
# finding out AFTER the switch, mid-task, with the old session gone.
#
# This reports; it never changes anything. Every fix is left to a human or to
# the session running the skill, because each one is a judgment call.
#
# Usage: account-switch-check.sh [target-config-dir]

set -uo pipefail
TARGET="${1:-}"
CUR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# The DEFAULT identity keeps its .claude.json at ~/.claude.json, NOT inside
# ~/.claude/; only a custom CLAUDE_CONFIG_DIR holds its own. Try both.
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

echo "═══ Identity ═══"
echo "  current: $CUR"
echo "           $(acct "$CUR")"
if [ -n "$TARGET" ]; then
  echo "  target:  $TARGET"
  if [ -d "$TARGET" ]; then
    echo "           $(acct "$TARGET")"
  else
    echo "           ⚠️  does not exist — see 'Setting up a new identity' in the skill"
  fi
fi

echo
echo "═══ Unlanded work (commit AND push — the batch worker pulls from origin) ═══"
found=0
while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"
  cd "$repo" 2>/dev/null || continue
  dirty="$(git status --porcelain 2>/dev/null)"
  unpushed=""
  if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
    n=$(git rev-list --count "${up}..HEAD" 2>/dev/null || echo 0)
    [ "$n" != "0" ] && unpushed="$n unpushed → $up"
  fi
  [ -z "$dirty" ] && [ -z "$unpushed" ] && continue
  found=1
  echo "  ${repo/#$HOME/~}"
  [ -n "$unpushed" ] && echo "      $unpushed"
  [ -n "$dirty" ] && echo "      $(printf '%s\n' "$dirty" | wc -l | tr -d ' ') file(s) uncommitted"
done < <(find "$HOME/Programming" -maxdepth 4 -name .git -type d -not -path '*/node_modules/*' 2>/dev/null)
[ "$found" = 0 ] && echo "  ✔ everything committed and pushed"

echo
echo "═══ Per-project memory (does NOT follow the switch) ═══"
cur_mem=$(ls -d "$CUR"/projects/*/memory 2>/dev/null | wc -l | tr -d ' ')
echo "  $cur_mem project(s) with memory in the current identity"
if [ -n "$TARGET" ] && [ -d "$TARGET" ]; then
  tgt_mem=$(ls -d "$TARGET"/projects/*/memory 2>/dev/null | wc -l | tr -d ' ')
  echo "  $tgt_mem in the target"
  [ "$cur_mem" -gt "$tgt_mem" ] && \
    echo "  ⚠️  DECISION: carry memory across, or knowingly start cold? (skill, step 3)"
fi

echo
echo "═══ Unattended spend — the worker has its OWN account ═══"
worker=$(ssh -o ConnectTimeout=6 -o BatchMode=yes 192.168.20.13 'python3 -c "
import json,os
a=json.load(open(os.path.expanduser(\"~/.claude.json\"))).get(\"oauthAccount\",{})
print(a.get(\"emailAddress\",\"?\"))
"' 2>/dev/null)
if [ -n "$worker" ]; then
  echo "  batchq worker (192.168.20.13) runs as: $worker"
  echo "  ⚠️  switching this Mac does NOT move that spend — moving it is Doug's call"
else
  echo "  ? worker unreachable (Zscaler holds the tailnet down during the work day)"
fi

echo
echo "═══ In flight ═══"
if command -v sbmjob >/dev/null 2>&1; then
  # Only the queues with something live matter here; the full listing is long.
  wrk="$(sbmjob -wrk 2>/dev/null)"
  # Drop each queue's "recent done:" block first — those filenames contain words
  # like "queued" and otherwise match as if they were live work.
  live="$(printf '%s\n' "$wrk" \
          | awk '/recent done:/{skip=1} /^=== Queue/{skip=0} !skip' \
          | grep -vE '^\s*\(empty\)|^\s*running: \(none\)' \
          | grep -E '^\s*running:|MSGW|HELD|^\s{4}[0-9]{8}-')"
  if [ -n "$(printf '%s' "$live" | tr -d '[:space:]')" ]; then
    printf '%s\n' "$live"
  else
    echo "  ✔ no jobs running, queued, or held"
  fi
else
  echo "  ? sbmjob not on PATH"
fi

echo
echo "Remaining, and not automatable: land durable state in the repo (STATUS /"
echo "PUNCHLIST / ADR / HANDOFF), then write the resume note. See the skill."
