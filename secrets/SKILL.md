---
name: secrets
description: How to work with the homelab's machine secrets (SOPS + age). Read/add/edit/rotate a secret, provision a new host as a SOPS host, inject secrets into a container or a generated .env, and enforce the pre-commit hook. Use for ANY "where does this secret live / how do I add/read/rotate a secret / how do programs get their credentials" question. Two stores only: LastPass (human) + SOPS (everything cc and programs read) — NEVER use `bw`/Vaultwarden (retiring).
---

# secrets

The machine-secrets operating manual. **Decision = fixer ADR 0017** (why; supersedes 0016). **Rollout plan = `fixer/docs/runbooks/secrets-migration.md`** (what's migrated, what's left). This skill is the *how-to*.

## The model (two stores, that's it)
- **LastPass** — human/interactive (Doug, autofill). cc does not touch it.
- **SOPS + age** — **everything cc and programs read.** Secrets encrypted at rest in the git repo **`homelab-secrets`** (`github.com/dougkimmerly/homelab-secrets`); each host holds an age key and decrypts locally.
- **cc NEVER reads a vault API.** No `bw get`, no Vaultwarden — that's retiring (ADR 0017). To get any secret, `sops -d` it.
- **`.env` files are generated from SOPS** — never hand-authored; gitignored. A render, not a store.

## Where things are
- Repo (Mac clone): `infrastructure/homelab-secrets/`. Layout: `.sops.yaml` (recipients by path), `secrets/home/*.sops.yaml`, `secrets/boat/*.sops.yaml`.
- **`.sops.yaml`** maps path → age recipients (which keys can decrypt). Home secrets → admin + relevant home host keys; boat → admin + `age1centralsk`.
- **age keys:** authoring key `age1admin` on the Mac at `~/.config/sops/age/keys.txt`; each host has its own (`age1dockerserver`, future `age1synology`/`age1centralsk`) at the same path on that host. Break-glass copies in **LastPass**.

## How-to

**Read a secret (cc, on the Mac):**
```bash
cd ~/Programming/dkSRC/infrastructure/homelab-secrets
sops -d secrets/home/<file>.sops.yaml                 # to stdout
sops exec-env secrets/home/<file>.sops.yaml -- <cmd>  # run cmd with the secrets as env vars
```

**Add / edit a secret:**
```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"   # REQUIRED in scripts — see Diagnostics
sops secrets/home/<file>.sops.yaml                    # opens $EDITOR on decrypted content; re-encrypts on save
sops set secrets/home/<file>.sops.yaml '["KEY"]' '"value"'   # scripted, no editor
```

**New multi-key file without ever writing plaintext to disk** (preferred over "write plaintext YAML then `sops -e -i`"):
```bash
F=secrets/home/<svc>.sops.yaml
printf 'INIT: x\n' > "$F"; sops -e -i "$F"            # encrypt a throwaway placeholder first
sops set "$F" '["KEY1"]' "\"$VAL1\""                 # each set re-encrypts; values never hit disk in cleartext
sops set "$F" '["KEY2"]' "\"$VAL2\""
sops unset "$F" '["INIT"]'                            # drop the placeholder
```

**Value hygiene** — never echo a secret. Capture it into a shell var and pass it on:
```bash
VAL=$(ssh doug@<host> "grep '^KEY=' /path/.env | cut -d= -f2-")   # stays in the var, not printed
# ... sops set ... ; then:  VAL=
```
Migrate the value *on the box where it already lives* when you can (keeps it off your workstation). `age1dockerserver` decrypts/edits home secrets too, so docker-server can `sops set` locally.

**Provision a NEW host as a SOPS host** (the proven 6-step pattern — also in the runbook):
1. Install `age` + `sops` on the host.
2. `age-keygen -o ~/.config/sops/age/keys.txt` (0600); note its **public** key.
3. Add that public key as a recipient on its site's path in `.sops.yaml` (Mac); `sops updatekeys secrets/<site>/*.sops.yaml` to rewrap existing files.
4. Commit + push; clone `homelab-secrets` on the host; `git config core.hooksPath .githooks`.
5. The host now decrypts its scoped secrets with `sops -d` / `sops exec-env`.

**Inject into a container — prefer `environment:` interpolation, NOT a tmpfs env_file.** Worked examples: `dk400-homelab/deploy.sh`, `command-centre/deploy.sh`, `galley/deploy.sh` (all in their `/opt/docker-server/<svc>/` or repo dirs).
```bash
sops exec-env secrets/home/<file>.sops.yaml -- docker compose up -d --build <svc>
```
compose forwards each var: `environment: { VAR: ${VAR:-} }`. `sops exec-env` puts the secret in the shell env, compose interpolates it, and docker **bakes the value into the container config at `up` time** — so it survives restart/reboot. A bare `docker compose up` ships empty vars — always deploy via the wrapper (a `deploy.sh` makes that the default).

⚠️ **Do NOT render secrets to a tmpfs `env_file`** (`/run/...`) for a container with `restart: unless-stopped`: `/run` evaporates on reboot, the container auto-restarts, and it comes up with **missing secrets**. Tmpfs `.env` is only safe for a one-shot process. Convert an `env_file: .env` service to `environment: ${VAR}` interpolation instead.

**Deploy `deploy.sh` shape** (single-quote the command so `$VAR` expands in the shell `sops exec-env` spawns, not when the script is read):
```bash
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
git -C "$SECRETS_REPO" pull -q --ff-only 2>/dev/null || true
sops exec-env "$SECRETS" 'docker compose up -d --build <svc>'
# GHCR/private-image pull: log in ephemerally with the secret, then logout
sops exec-env "$SECRETS" 'echo "$GHCR_TOKEN" | docker login ghcr.io -u <user> --password-stdin && docker compose pull && docker compose up -d && docker logout ghcr.io'
```

**Rotate / break-glass:**
- Rewrap recipients after a key change: `sops updatekeys secrets/<site>/<file>.sops.yaml`.
- Rotate a value: edit it (`sops <file>`), then rotate it upstream (the provider) too.
- A host key leaked → re-provision that host's key + `updatekeys`. The `age1admin` break-glass lives in LastPass (and the Mac) — it's what recovers everything; it can't live in SOPS (it decrypts SOPS).

## Migrate a running service to SOPS (proven on dk400 / command-centre / galley, 2026-06-01)

Storage-first, verify at every step, never break the live service. Tighten scope *after*, as a separate pass.

1. **Discover** what's actually a secret. Read the running container's env (`docker exec <svc> printenv`) and the compose `environment:`/`env_file:` — separate true secrets (tokens, passwords, DB URLs) from config (ports, URLs). Config stays in `.env`; secrets go to SOPS.
2. **Build the SOPS file** with the no-plaintext recipe above; **round-trip-verify each value vs the live `.env` by hash** before touching anything:
   ```bash
   a=$(sops -d --extract '["KEY"]' "$F" | tr -d '[:space:]' | shasum -a256 | cut -c1-12)
   b=$(grep '^KEY=' /path/.env | cut -d= -f2- | tr -d '[:space:]' | shasum -a256 | cut -c1-12)
   [ "$a" = "$b" ] && echo MATCH   # only proceed on MATCH
   ```
   Commit + push (hook scans it).
3. **Wire the deploy** — add `${VAR}` lines to compose `environment:`, add a `deploy.sh` (above). Commit to the repo that owns the compose.
4. **Pre-check on the consuming host** that it can decrypt AND the decrypted values match the `.env` (same hash compare, run over SSH) — this gates the strip; abort if any mismatch.
5. **Strip the secrets from `.env`** (leave a breadcrumb comment pointing at the SOPS file), then run `deploy.sh`.
6. **Verify the result**: container env fingerprint matches SOPS (`docker exec <svc> printenv KEY | sha256sum`), a deploy-only var like `GHCR_TOKEN` is **absent** from the container, and a **functional** check passes (live API/auth `200`/`302`, `/health` `200`, healthcheck `healthy`).
7. **Scrub stale plaintext copies** (`.env.bak.*`, `.env.pre-*`, dead CasaOS/duplicate dirs) — `grep -rE 'ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}'` to find them; some are root-owned (`sudo rm`).
8. **Scope-reduce later**: swap a broad token for a least-privilege one (`sops set` over the value, redeploy, revoke the old) — a separate, low-risk pass once storage is proven.

**Watch for stale deployed-vs-git drift**: the file *deployed* on a host can differ from what's committed (hand-edited in place, never pushed). Trust the running container's env + a real `count(*)`/hash, not the repo's compose or `.env`. Commit the deployed reality back when you find drift.

## GitHub machine tokens (today's domain knowledge)

Full inventory + plan live in the migration runbook; the reusable rules:
- **No expiration on machine tokens** — an unattended host can't renew, so an expiry is a scheduled outage. Control via **tight scope + SOPS + revocation**, not expiry.
- **Pure git access → SSH deploy key** (per-repo, read-only where possible; no token to leak). **Anything a deploy key can't do** (GHCR packages, org/workflow/codespace) → **fine-grained PAT** in SOPS. **GHCR pulls** → a **`read:packages`-only classic** token (fine-grained GHCR for *user*-owned packages is flaky).
- **Identify a classic token by its scope signature** (`curl -sI -H "Authorization: token <val>" https://api.github.com/user` → `x-oauth-scopes`) — a value's scope set usually maps to exactly one named token. **Classic PATs can't be listed/deleted via API** (UI only); the "Last used" column is laggy/unreliable. **Verify a revocation** by cur/`HTTP 401`.
- **MCP-server tokens stay plaintext in the Claude config env** (`~/.claude.json`, Claude Desktop `claude_desktop_config.json`) — the Claude apps can't SOPS-inject. To re-token, regenerate + string-replace the value in both configs (preserves formatting; keep other env vars). `mcp__github` tools come from Claude's own integration, not the stdio `@modelcontextprotocol/server-github`.
- **A token's name can lie** — e.g. `n8n-galley-recipies` is galley's live token, not n8n's. Confirm a value↔name mapping by fingerprint + what actually holds it (running container env) before deleting anything that "shows recent use."

## Enforce (this is the security model)
The `gitleaks`/`sops` **pre-commit hook IS the enforcement** — SOPS won't stop a plaintext commit. On every clone:
```bash
git config core.hooksPath .githooks
```
The hook (in `homelab-secrets/.githooks/` and the `claude-skills` repo) blocks any unencrypted file under `secrets/` and any gitleaks hit. **A plaintext secret reaching git history = treat as a full rotation.** Skills/code must reference SOPS, never embed a secret value.

## Diagnostics
- **`sops -d` fails `no identity matched any of the recipients` / `Did not find keys in locations 'SOPS_AGE_KEY_FILE'…` — even though the key IS at `~/.config/sops/age/keys.txt`.** sops does **not** auto-discover the default key path in non-interactive/scripted shells. **Fix: `export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"` before any sops command** (in scripts and over SSH). This is the #1 gotcha — set it first, always. Confirm the key matches a recipient with `age-keygen -y "$SOPS_AGE_KEY_FILE"` (should equal an `age1…` in the file's `.sops.yaml` path rule).
- **"Can this host decrypt X?"** → is its age key present (`~/.config/sops/age/keys.txt`) AND a recipient on X's path in `.sops.yaml`? (And is `SOPS_AGE_KEY_FILE` exported — see above.)
- **"Is the hook on this clone?"** → `git config core.hooksPath` should be `.githooks`.
- **"Where does secret Y live / is it migrated?"** → grep `.sops.yaml` + `secrets/`; check the migration runbook for what's still plaintext (e.g. Kometa `config.yml` was still host-only as of 2026-06-01).
- **Tooling:** sops 3.13.x, age 1.x, gitleaks 8.x.

## Don't
- Don't `bw get` / use Vaultwarden — retiring (ADR 0017). Don't add a third store.
- Don't hand-edit a secret outside `sops`, commit plaintext, or paste a secret value into a skill, program, or compose file. Point at SOPS.
