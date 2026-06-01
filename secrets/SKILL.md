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
sops secrets/home/<file>.sops.yaml                    # opens $EDITOR on decrypted content; re-encrypts on save
sops set secrets/home/<file>.sops.yaml '["KEY"]' '"value"'   # scripted, no editor
```
New file: write a flat plaintext YAML (`KEY: value` per line), then `sops -e -i secrets/home/<file>.sops.yaml` (it picks recipients from `.sops.yaml` by path). Name it `*.sops.yaml`. Commit + push (the hook scans it).

**Provision a NEW host as a SOPS host** (the proven 6-step pattern — also in the runbook):
1. Install `age` + `sops` on the host.
2. `age-keygen -o ~/.config/sops/age/keys.txt` (0600); note its **public** key.
3. Add that public key as a recipient on its site's path in `.sops.yaml` (Mac); `sops updatekeys secrets/<site>/*.sops.yaml` to rewrap existing files.
4. Commit + push; clone `homelab-secrets` on the host; `git config core.hooksPath .githooks`.
5. The host now decrypts its scoped secrets with `sops -d` / `sops exec-env`.

**Inject into a container** (worked example: `dk400-homelab/deploy.sh`):
```bash
sops exec-env secrets/home/<file>.sops.yaml -- docker compose up -d --build <svc>
```
compose must forward each var: `environment: { VAR: ${VAR:-} }`. A bare `docker compose up` then ships empty vars — always deploy via the wrapper.

**Materialize a `.env`** when a tool insists on a file:
```bash
sops -d --output-type dotenv secrets/home/<file>.sops.yaml > /run/<svc>/.env   # /run = tmpfs, evaporates on reboot
```

**Rotate / break-glass:**
- Rewrap recipients after a key change: `sops updatekeys secrets/<site>/<file>.sops.yaml`.
- Rotate a value: edit it (`sops <file>`), then rotate it upstream (the provider) too.
- A host key leaked → re-provision that host's key + `updatekeys`. The `age1admin` break-glass lives in LastPass (and the Mac) — it's what recovers everything; it can't live in SOPS (it decrypts SOPS).

## Enforce (this is the security model)
The `gitleaks`/`sops` **pre-commit hook IS the enforcement** — SOPS won't stop a plaintext commit. On every clone:
```bash
git config core.hooksPath .githooks
```
The hook (in `homelab-secrets/.githooks/` and the `claude-skills` repo) blocks any unencrypted file under `secrets/` and any gitleaks hit. **A plaintext secret reaching git history = treat as a full rotation.** Skills/code must reference SOPS, never embed a secret value.

## Diagnostics
- **"Can this host decrypt X?"** → is its age key present (`~/.config/sops/age/keys.txt`) AND a recipient on X's path in `.sops.yaml`? `sops -d` errors `no key could decrypt` if not.
- **"Is the hook on this clone?"** → `git config core.hooksPath` should be `.githooks`.
- **"Where does secret Y live / is it migrated?"** → grep `.sops.yaml` + `secrets/`; check the migration runbook for what's still plaintext (e.g. Kometa `config.yml` was still host-only as of 2026-06-01).
- **Tooling:** sops 3.13.x, age 1.x, gitleaks 8.x. `SOPS_AGE_KEY_FILE` overrides the key path if needed.

## Don't
- Don't `bw get` / use Vaultwarden — retiring (ADR 0017). Don't add a third store.
- Don't hand-edit a secret outside `sops`, commit plaintext, or paste a secret value into a skill, program, or compose file. Point at SOPS.
