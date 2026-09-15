#!/bin/bash
# claude-identity.sh — the per-repo LIVE ACCOUNT registry.
#
# Three Claude identities now share this Mac, each a CLAUDE_CONFIG_DIR chosen at
# launch. A repo is worked under ONE of them at a time — its memory, history and
# sessions live there. Opening a repo under the wrong identity is silent: skills
# and CLAUDE.md still load (they are symlinked), so nothing looks wrong until
# memory is missing and the session starts writing a second, diverging copy.
#
# There is no system that knows which identity owns a repo — it is Doug's choice
# — so this IS the system of record. It lives at ~/.claude-identity/, a sibling
# of the config dirs, owned by NO identity, so all three read the same file. It
# is machine-local state and is deliberately NOT in git: it says what is true
# right now, not what was decided.
#
# Usage:
#   claude-identity.sh get  [repo]              → config dir of the live account
#   claude-identity.sh set  <config-dir> [repo] → record the live account
#   claude-identity.sh list                     → every registered repo
#   claude-identity.sh whoami                   → this session's identity
# Repo defaults to the git root of the working directory.

set -uo pipefail
REG_DIR="$HOME/.claude-identity"
REG="$REG_DIR/registry.json"

repo_root() { git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null; }
cur_cfg()   { python3 -c "import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

# The launcher for a config dir: the ~/.local/bin wrapper that sets it, else the
# bare `claude` for the default dir. Derived, never assumed — launchers are Doug's.
#
# Wrappers, not shell aliases: an alias is absent from every non-interactive
# shell and from any shell opened before ~/.zshrc changed. .zshrc is still
# scanned as a fallback so an identity defined the old way still resolves.
#
# The match MUST be anchored on the closing quote. `$HOME/.claude` is a prefix of
# `$HOME/.claude-xtl`, so a loose pattern reports the default identity as whichever
# suffixed launcher happens to be found first.
launcher_for() {
  local cfg="$1" name pat
  [ "$cfg" = "$(python3 -c "import os;print(os.path.realpath(os.path.expanduser('~/.claude')))")" ] \
    && { printf 'claude'; return; }
  pat="CLAUDE_CONFIG_DIR=\"\$HOME/$(basename "$cfg")\""
  name=$(grep -lF "$pat" "$HOME"/.local/bin/claude-* 2>/dev/null | head -1)
  [ -n "$name" ] && { basename "$name" | tr -d '\n'; return; }
  name=$(grep -hF "$pat" "$HOME/.zshrc" 2>/dev/null \
         | sed -n "s/^alias \([a-zA-Z0-9_-]*\)=.*/\1/p" | head -1)
  if [ -n "$name" ]; then printf '%s' "$name"
  else printf 'CLAUDE_CONFIG_DIR=%s claude' "$cfg"; fi
}

acct_for() {
  python3 -c "
import json,os,sys
d=os.path.realpath(os.path.expanduser(sys.argv[1]))
p=(os.path.expanduser('~/.claude.json')
   if d==os.path.realpath(os.path.expanduser('~/.claude')) else d+'/.claude.json')
try: print(json.load(open(p)).get('oauthAccount',{}).get('emailAddress','?'))
except Exception: print('?')
" "$1" 2>/dev/null
}

case "${1:-}" in
  get)
    r=$(repo_root "${2:-$PWD}") || exit 1
    [ -z "$r" ] && exit 1
    python3 -c "
import json,os,sys
try: reg=json.load(open(os.path.expanduser('$REG')))
except Exception: sys.exit(1)
e=reg.get(sys.argv[1])
print(e['config_dir']) if e else sys.exit(1)
" "$r"
    ;;

  set)
    cfg="${2:?usage: claude-identity.sh set <config-dir> [repo]}"
    cfg=$(python3 -c "import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "$cfg")
    [ -d "$cfg" ] || { echo "no such config dir: $cfg" >&2; exit 1; }
    r=$(repo_root "${3:-$PWD}")
    [ -z "$r" ] && { echo "not inside a git repo" >&2; exit 1; }
    mkdir -p "$REG_DIR"
    python3 -c "
import json,os,sys,datetime
p=os.path.expanduser('$REG')
try: reg=json.load(open(p))
except Exception: reg={}
reg[sys.argv[1]]={'config_dir':sys.argv[2],
                  'set_at':datetime.datetime.now().isoformat(timespec='seconds')}
json.dump(reg,open(p,'w'),indent=2,sort_keys=True)
" "$r" "$cfg"
    echo "live account for ${r/#$HOME/~}: $(launcher_for "$cfg")  ($(acct_for "$cfg"))"
    ;;

  list)
    [ -f "$REG" ] || { echo "no repos registered yet"; exit 0; }
    python3 -c "
import json,os
reg=json.load(open(os.path.expanduser('$REG')))
h=os.path.expanduser('~')
for r,e in sorted(reg.items()):
    print(f\"{r.replace(h,'~'):55} {e['config_dir'].replace(h,'~'):20} {e.get('set_at','')}\")
"
    ;;

  whoami)
    c=$(cur_cfg)
    echo "$(launcher_for "$c")  ($(acct_for "$c"))  [$c]"
    ;;

  launcher)  # bare launcher command for a config dir — for scripts
    launcher_for "$(python3 -c "import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${2:?}")"
    echo
    ;;

  describe)  # "launcher  (email)" for a config dir — for messages
    c=$(python3 -c "import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${2:?}")
    echo "$(launcher_for "$c")  ($(acct_for "$c"))"
    ;;

  *)
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac
