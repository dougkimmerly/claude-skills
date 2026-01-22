# Proxy & DNS Skill

Manage DNS records (Pi-hole) and reverse proxy hosts (Nginx Proxy Manager) for the homelab.

---

## Quick Reference

| Component | Location | Access |
|-----------|----------|--------|
| Pi-hole (Primary) | 192.168.20.16 (Synology) | SSH + Docker |
| Pi-hole (Secondary) | 192.168.20.3 (Raspberry Pi) | SSH |
| NPM | 192.168.20.19:81 | REST API |

**IMPORTANT:** Primary and secondary Pi-hole are NOT synced automatically. Add records to both for redundancy. See `references/pihole.md` for secondary Pi-hole commands.

---

## Common Operations

### Add New Service (DNS + Proxy)

When adding a new service that needs both DNS and reverse proxy:

```bash
# 1. Add DNS record (points to NPM)
ssh doug@192.168.20.16 "echo 'cname=SERVICE.kbl55.com,npm.kbl55.com' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/05-pihole-custom-cname.conf"
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"

# 2. Add NPM proxy host (see NPM API section below)
```

### Add DNS Record Only

For services that don't need a proxy (direct IP access):

```bash
# A record (direct IP)
ssh doug@192.168.20.16 "echo 'address=/SERVICE.kbl55.com/192.168.20.XX' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/custom.conf"

# CNAME record (alias to npm.kbl55.com for proxied services)
ssh doug@192.168.20.16 "echo 'cname=SERVICE.kbl55.com,npm.kbl55.com' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/05-pihole-custom-cname.conf"

# Reload DNS
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
```

### List Current DNS Records

```bash
# Custom A records
ssh doug@192.168.20.16 "cat /volume1/docker/homelab-synology/pihole/dnsmasq.d/custom.conf"

# CNAME records
ssh doug@192.168.20.16 "cat /volume1/docker/homelab-synology/pihole/dnsmasq.d/05-pihole-custom-cname.conf"
```

### Verify DNS Resolution

```bash
# Query Pi-hole directly
nslookup SERVICE.kbl55.com 192.168.20.16
```

---

## Pi-hole Details

**Version:** Pi-hole v6
**Container:** `Pi-Hole` (note capitalization)
**Host:** Synology NAS (192.168.20.16)
**Config path:** `/volume1/docker/homelab-synology/pihole/`

### Config Files

| File | Purpose |
|------|---------|
| `dnsmasq.d/custom.conf` | A records (`address=/domain/ip`) |
| `dnsmasq.d/05-pihole-custom-cname.conf` | CNAME records |
| `pihole/custom.list` | Legacy format (not used in v6) |

### DNS Record Formats

```
# A record (direct IP mapping)
address=/service.kbl55.com/192.168.20.19

# CNAME record (alias)
cname=service.kbl55.com,npm.kbl55.com
```

### Reload Commands

```bash
# Full reload (recommended after changes)
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"

# Quick reload (may not pick up all changes)
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker exec Pi-Hole pihole reloaddns"
```

---

## NPM (Nginx Proxy Manager) Details

**URL:** http://192.168.20.19:81
**API Base:** http://192.168.20.19:81/api

### Authentication

```bash
# Get token (store in variable)
NPM_TOKEN=$(curl -s -X POST "http://192.168.20.19:81/api/tokens" \
  -H "Content-Type: application/json" \
  -d '{"identity":"EMAIL","secret":"PASSWORD"}' | jq -r '.token')
```

### List Proxy Hosts

```bash
curl -s "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.[] | {id, domain_names, forward_host, forward_port}'
```

### Create Proxy Host

```bash
curl -s -X POST "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["SERVICE.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.XX",
    "forward_port": PORT,
    "access_list_id": 0,
    "certificate_id": 0,
    "ssl_forced": false,
    "http2_support": false,
    "block_exploits": true,
    "advanced_config": "",
    "meta": {
      "letsencrypt_agree": false,
      "dns_challenge": false
    },
    "allow_websocket_upgrade": true,
    "caching_enabled": false,
    "locations": []
  }'
```

### Create Proxy Host with SSL (Let's Encrypt)

```bash
# First create without SSL
PROXY_ID=$(curl -s -X POST "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["SERVICE.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.XX",
    "forward_port": PORT,
    "block_exploits": true,
    "allow_websocket_upgrade": true
  }' | jq -r '.id')

# Then request certificate (requires domain to be publicly accessible)
# For internal-only services, use certificate_id: 0 (no SSL) or existing wildcard
```

### Delete Proxy Host

```bash
curl -s -X DELETE "http://192.168.20.19:81/api/nginx/proxy-hosts/ID" \
  -H "Authorization: Bearer $NPM_TOKEN"
```

---

## Complete Example: Add New Service

Adding `newapp.kbl55.com` pointing to `192.168.20.19:8888`:

```bash
# 1. Add CNAME to Pi-hole (points to NPM)
ssh doug@192.168.20.16 "echo 'cname=newapp.kbl55.com,npm.kbl55.com' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/05-pihole-custom-cname.conf"

# 2. Restart Pi-hole
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"

# 3. Verify DNS
nslookup newapp.kbl55.com 192.168.20.16

# 4. Get NPM token
NPM_TOKEN=$(curl -s -X POST "http://192.168.20.19:81/api/tokens" \
  -H "Content-Type: application/json" \
  -d '{"identity":"EMAIL","secret":"PASSWORD"}' | jq -r '.token')

# 5. Create proxy host
curl -s -X POST "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["newapp.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.19",
    "forward_port": 8888,
    "block_exploits": true,
    "allow_websocket_upgrade": true
  }'

# 6. Test
curl -s -o /dev/null -w '%{http_code}' http://newapp.kbl55.com
```

---

## Troubleshooting

### DNS Not Resolving After Adding Record

1. Verify file was updated:
   ```bash
   ssh doug@192.168.20.16 "cat /volume1/docker/homelab-synology/pihole/dnsmasq.d/custom.conf"
   ```

2. Restart Pi-hole (not just reload):
   ```bash
   ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
   ```

3. Query Pi-hole directly (bypass local cache):
   ```bash
   nslookup domain.kbl55.com 192.168.20.16
   ```

### NPM 502 Bad Gateway

- Upstream service not running
- Wrong port in proxy host
- Firewall blocking connection

### NPM API Returns 401

Token expired - re-authenticate:
```bash
NPM_TOKEN=$(curl -s -X POST "http://192.168.20.19:81/api/tokens" ...)
```

---

## Credential Storage

NPM credentials should be stored in Bitwarden under "Nginx Proxy Manager" or "NPM".

To use in scripts:
```bash
# If using Bitwarden CLI
NPM_PASS=$(bw get password "Nginx Proxy Manager")
```

---

## Related

- **Pi-hole Admin:** http://192.168.20.16/admin
- **NPM Admin:** http://192.168.20.19:81
- **Docker Server Skill:** docker-server/skill.md
- **Synology Skill:** synology/skill.md
