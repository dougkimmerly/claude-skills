#!/bin/bash
# warn-uncommitted-skills.sh — backup safety net for ADR 0022.
#
# ~/.claude/skills is a git repo that BACKS UP real-file universal skills. The
# recurring gap (lightroom 2026-06-08; archive+lotus-notes 2026-06-26) is a
# real-file skill authored but never committed → it lives only on this SSD with
# no off-machine backup. No git hook catches this, because the failure mode is
# "never runs git at all".
#
# This script is wired as a Claude Code SessionStart hook. It is SILENT and
# exits 0 when the repo is clean (zero cost to every session), and prints a
# warning ONLY when there is uncommitted REAL-FILE skill content. Symlinked
# skills are intentionally skipped: git tracks only the link here; their content
# is backed up by the project repo that owns the real file (ADR 0022 tier 2).

set -euo pipefail
SKILLS_DIR="$HOME/.claude/skills"

cd "$SKILLS_DIR" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

dirty=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"                 # strip the 'XY ' porcelain status prefix
  top="${path%%/*}"                # first path component (the skill dir / file)
  [ -L "$top" ] && continue        # symlinked skill → backed up by its owning repo
  dirty="${dirty}    ${line}"$'\n'
done < <(git status --porcelain 2>/dev/null)

# Also warn if local commits exist that were never pushed (committed but still
# only on this machine — backup is the PUSH, per ADR 0022).
unpushed=""
if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  n=$(git rev-list --count "${up}..HEAD" 2>/dev/null || echo 0)
  [ "$n" != "0" ] && unpushed="$n local commit(s) not pushed to ${up}"
fi

[ -z "$dirty" ] && [ -z "$unpushed" ] && exit 0

echo "⚠️  ~/.claude/skills backup gap (ADR 0022) — real-file skills not safely backed up:"
if [ -n "$dirty" ]; then
  echo "  Uncommitted real-file skill content:"
  printf '%s' "$dirty"
fi
[ -n "$unpushed" ] && echo "  $unpushed"
echo "  Fix: cd ~/.claude/skills && git add -A && git commit && git push"
exit 0
