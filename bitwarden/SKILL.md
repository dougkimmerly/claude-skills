---
name: bitwarden
description: RETIRED 2026-06-02 (ADR 0017). Vaultwarden is gone — containers decommissioned, all items moved to SOPS/LastPass. For ANY credential access use the `secrets` skill (SOPS+age) or LastPass (human). Never `bw`/`bw get`. This stub exists only so old references resolve to the replacement.
triggers:
  - vaultwarden
  - bitwarden
location: project
---

# Bitwarden / Vaultwarden — RETIRED

> **⛔ RETIRED 2026-06-02 (ADR 0017).** Vaultwarden is decommissioned. The two-store model is **LastPass (human/interactive) + SOPS (everything cc and programs read)**. There is no vault API to call — **do not use `bw`, `bw get`, or `~/.bw-session`.**

## Where credentials live now

| Need | Go to |
|------|-------|
| A secret a program/cc reads | **`secrets` skill** → `sops -d` from `homelab-secrets` |
| A human/interactive login (Doug autofill, manual restore) | **LastPass** |
| A network-device admin login | `homelab-secrets/secrets/home/network-devices.sops.yaml` |

## What happened to the old vault items (all preserved before teardown)

- **Peplink Admin, Plex token, Overseerr key, 3 SignalK tokens** → already in SOPS (verified byte-match / live-match before retiring).
- **age1admin break-glass key, Restic repo passphrase, Synology SMB cred** → LastPass.
- Restic passphrase was **rotated** 2026-06-02 (see [[restic-via-syncthing]]).

## Decommission record

- Containers `bitwarden` + `bitwarden-postgres` (a "one DB many schemas" violation — separate postgres) removed via `docker compose down` at `/opt/docker-server/bitwarden` on docker-server.
- Data dir `/opt/docker-server/bitwarden/data` (1.3M) kept on disk for a soak period — **delete after soak**.
- NetBox VM `Bitwarden` (id 25) → status `decommissioning`.
- Full detail: `fixer/docs/runbooks/secrets-migration.md` Phase 6; architecture in the `secrets` skill + ADR 0017.
