---
name: bitwarden
description: Access credentials from Bitwarden vault. The `bw` CLI on Doug's Mac is the canonical fetch path because it decrypts items client-side using his master password. The OAuth REST API can list and create but returns ciphertext; it cannot decrypt.
triggers:
  - bitwarden
  - credentials
  - secrets
  - password lookup
location: project
---

# Bitwarden Credential Lookup

Self-hosted Vaultwarden at `https://bitwarden.kbl55.com` (container on docker-server's dk400 network).

## Important reality (learned 2026-05-06)

**All vault items are end-to-end encrypted** with a key derived from Doug's master password. Two consequences for automation:

1. **OAuth `client_credentials` flow CAN list/search items and CAN create new items, but the items it returns are ciphertext** (`name` and `login.username`/`login.password` come back as `2.<base64>...` blobs). Server-side decryption never happens. Earlier versions of this skill claimed `select(.name == "x") | .login.password` would return plaintext — that's wrong. It returns the ciphertext.
2. **The `bw` CLI decrypts client-side** by holding the master-password-derived key in memory after `bw unlock`. So fetching a usable plaintext credential requires the CLI plus an active session.

**Decision rule:**
- **Reading a credential** → `bw` CLI on the Mac (this Mac). Requires Doug to have logged in + unlocked at least once.
- **Listing items / creating new items / verifying an item exists** → OAuth API is fine.
- **Reading from a server** (not the Mac) → not currently supported. If we need this, options are: (a) install `bw` CLI on the server and replicate the unlock pattern, (b) run `bw serve` as an authenticated REST proxy, (c) Bitwarden Secrets Manager (different product, machine-token-based). All deferred.

## Canonical read path: bw CLI on Mac

### One-time setup

```bash
# Confirm pointed at the right server
bw config server   # → https://bitwarden.kbl55.com

# Login (interactive — asks email, master password, 2FA if enabled)
bw login
```

### Per-session unlock

The session token expires after a configurable timeout (default ~15 min idle on Vaultwarden's setup, can be longer). When stale, `bw get` returns "You are not logged in." or "Vault is locked.".

```bash
# Unlock and capture session token
export BW_SESSION=$(bw unlock --raw)

# Now any fetch works:
bw get item "Synology - SMB Home Files" --session "$BW_SESSION" | jq -r '.login.password'
bw get username "Synology - SMB Home Files" --session "$BW_SESSION"
bw get password "Synology - SMB Home Files" --session "$BW_SESSION"
```

`bw get` reads `BW_SESSION` from env automatically — `--session` is only needed if env isn't propagated.

### Persisting session across Claude Code sessions

When Doug starts working, he runs `bw unlock` once in his shell. Claude Code inherits the env. When the session goes stale, the next `bw get` complains; ask Doug to re-unlock.

For multi-session continuity, write the session token to a file with strict permissions:

```bash
bw unlock --raw > ~/.bw-session
chmod 600 ~/.bw-session
# Then in any new session:
export BW_SESSION=$(cat ~/.bw-session)
```

Trade-off: session token in a file = if someone reads `~/.bw-session` they have read access to the vault until the session times out or `bw lock` is called. For a single-user homelab Mac that's behind FileVault and a Tailscale tailnet, acceptable. Don't do this on shared machines.

## OAuth API — list, search, create (NOT decrypt-read)

### Credentials

```bash
source /Users/doug/Programming/dkSRC/infrastructure/homelab/.env.local
# BITWARDEN_CLIENT_ID=user.b3483f91-...
# BITWARDEN_CLIENT_SECRET=...
# BITWARDEN_API_URL=https://bitwarden.kbl55.com
```

### Get token (uses --data-urlencode for safety on chars like quotes)

```bash
ACCESS_TOKEN=$(curl -s -X POST "$BITWARDEN_API_URL/identity/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$BITWARDEN_CLIENT_ID" \
  --data-urlencode "client_secret=$BITWARDEN_CLIENT_SECRET" \
  --data-urlencode "scope=api" \
  --data-urlencode "device_identifier=claude-code-client" \
  --data-urlencode "device_type=8" \
  --data-urlencode "device_name=Claude Code" | jq -r '.access_token')
```

`device_identifier`, `device_type`, `device_name` are required.

### List items the API user can see (count only — names are encrypted)

```bash
curl -s "$BITWARDEN_API_URL/api/ciphers" -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.data | length'
```

The API user only sees items in collections it's a member of. As of 2026-05-06 the user is `user.b3483f91-...` (Doug's primary account). Items in his personal vault are visible only when he's a member of an organization that holds them.

### Verify an item exists by ID (after creating one)

```bash
# After bw cli creates / lists items, you'll have an item id.
# To verify presence (without decryption) via the API:
curl -s "$BITWARDEN_API_URL/api/ciphers/<id>" -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.collectionIds, .organizationId'
```

### Create new item via API

Possible because the API client encrypts before posting. But you need an unlocked vault state to encrypt — which means using `bw create item` from the CLI is simpler. Don't use the raw API for this; use `bw`.

## Org / collection setup (one-time, done 2026-05-06)

For the OAuth API user to *see* items, the items need to live in collections that user can access:

1. Bitwarden web vault → top-right initials → Settings → Organizations → New
2. Create org `Homelab`, free plan (Vaultwarden allows unlimited)
3. Org → Collections → New → name e.g. `Homelab Credentials`
4. Members tab → confirm Doug's user is a member with **Can view** or higher
5. Move existing item: open item → Edit → Owner field → change `My Vault` to `Homelab` → tick `Homelab Credentials` collection → Save

Done state today: org `Homelab Creds` (ID `ef6642fb-c592-4560-a291-3093001e6360`), collection `Default collection` (ID `61d21aea-2d58-4729-b56d-6f3fbd8c4f14`). Use these IDs directly in `bw create` calls — don't filter by name "Homelab" (wrong) or "Homelab Credentials" (wrong).

## Known credential items (decrypt-read path = bw CLI)

| Item name in vault | What it's for |
|---|---|
| `Synology - SMB Home Files` | SMB user/pass for `//192.168.20.16/Home Files` (mounted at `/mnt/home-files` on docker-server). User: `home`. |
| `tailscale-api-key` | Tailscale API access |
| `mbb300 - Maretron MBB300C` | SSH to vessel monitoring black box (192.168.22.23) |
| `SignalK - HomeSK Admin Token` | Admin JWT for HomeSK (192.168.20.19:3000) |
| `SignalK - Nav Net Admin Token` | Admin JWT for Nav Net (192.168.22.16) |
| `SignalK - Power Net Admin Token` | Admin JWT for Power Net (192.168.22.14) |
| `Restic — DSII Backup` | Restic passphrase for boat (centralsk) + home (Synology) repos. Stored at `/etc/restic/password` on both hosts. See ADR 0011. |

## Helper script (legacy, broken)

There's a script at `/Users/doug/Programming/dkSRC/infrastructure/homelab/scripts/bitwarden-get-credential.sh`. It was written assuming OAuth could return plaintext — it can't. **Don't use it.** Either rewrite it to call `bw get` (relying on `BW_SESSION` from env) or remove it.

## Storing new credentials

**Preferred: via `bw create`:**

```bash
echo '{
  "organizationId": "<homelab-org-id>",
  "collectionIds": ["<homelab-credentials-collection-id>"],
  "type": 1,
  "name": "Service - Description",
  "notes": "Why this exists, when added, who uses it",
  "login": {"username": "user", "password": "secret"}
}' | bw encode | bw create item --session "$BW_SESSION"
```

**Or via the web UI** if interactive:

1. https://bitwarden.kbl55.com — login
2. Top right + → New → Login
3. Name: `Service - Server` style
4. Username, Password, optional URI (e.g. `smb://...`, `ssh://host`)
5. Notes: include who uses it, when added, mount path / consumer details
6. **Owner: choose `Homelab` org and tick `Homelab Credentials` collection** (otherwise OAuth API can't see it).

## Common gotchas

### `bw` CLI returns "You are not logged in." after a fresh shell
Run `export BW_SESSION=$(bw unlock --raw)` (you're logged in but session token isn't in env yet).

### `bw get item` returns "Not found"
- Item name is case-sensitive and exact. Try `bw list items --search "<term>"` first.
- Items are listed only after a successful `bw sync` (auto on unlock; force with `bw sync` if you just added an item via web UI).

### OAuth API returns 0 items but you know they exist
The user behind the API client isn't a member of the collection. Add to org/collection per the "Org / collection setup" section above.

### OAuth API returns names as `2.<base64>` blobs
Working as designed — those are encrypted. To read decrypted, use `bw` CLI. To verify presence, use `.id` and item count.

## Future Improvements

- [ ] Wrapper script that does `bw get` with auto-re-unlock prompt (reads from `~/.bw-session`, falls back to `bw unlock` if stale)
- [ ] Configure Home Assistant long-lived token in Bitwarden (under Homelab org)
- [ ] Add Wyze credentials for Wyze Bridge
- [ ] Add Meross credentials for smart plug management
- [ ] Investigate `bw serve` for server-side credential fetches when needed
