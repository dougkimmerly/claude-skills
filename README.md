# claude-skills

Version-controlled backup of `~/.claude/skills/`. The **canonical copy is the live
directory** — edit skills in place, commit here for history + off-machine backup.
This is NOT a clone/sync repo (that earlier model was archived); just `git init`
in place. Skills auto-discover every Claude Code session on this Mac — no registry.

## Secrets
Skills NEVER embed secret values — they reference **SOPS** (`sops -d …`), the
machine-secrets store (ADR 0017; LastPass + SOPS only). The gitleaks pre-commit
hook enforces this. On a fresh clone: `git config core.hooksPath .githooks`.
