---
name: discovery
description: Review and manage discovered network devices
triggers:
  - discovery
  - new devices
  - unknown devices
  - review devices
location: project
---

# Device Discovery

Guide for reviewing unknown devices found by NetAlertX and adding them to NetBox.

## Architecture

**Both network devices AND Docker containers require approval before being added to NetBox.**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Discovery Sources                                 │
├─────────────────────────────────────────────────────────────────────┤
│  NetAlertX (Network Scanner)     │  Docker Hosts (SSH)              │
│  Port: 20212 (API)               │  docker-server, synology         │
│  Port: 20211 (Web UI)            │                                  │
└─────────────────────────────────────────────────────────────────────┘
                    │                              │
                    ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  netalertx_sync Program          │  docker_sync Program             │
│  (runs every 15 minutes)         │  (runs hourly via INFRA_DOCKER)  │
├─────────────────────────────────────────────────────────────────────┤
│  • Fetches devices from API      │  • SSH to hosts, run docker ps   │
│  • Compares with NetBox (MAC)    │  • Compares with NetBox VMs      │
│  • Creates ISSUE for new devices │  • Creates ISSUE for new containers│
│  • Updates existing device info  │  • Updates existing VM status    │
└─────────────────────────────────────────────────────────────────────┘
                    │                              │
                    ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    fixer.unified_issues                              │
│              (Issues for approval - source_type='discovery')         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (manual approval)
┌─────────────────────────────────────────────────────────────────────┐
│                         NetBox                                       │
│                    (Source of truth)                                 │
│                      Port: 8000                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principle:** Discovery programs NEVER auto-create entries in NetBox. They create issues that must be reviewed and approved.

## List Discovery Issues (All Types)

```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT id, source_name, LEFT(title, 50) as title, last_seen::date
FROM fixer.unified_issues
WHERE source_type = 'discovery' AND status NOT IN ('resolved', 'ignored')
ORDER BY last_seen DESC;
\""
```

Discovery issues have `source_name` prefixed by type:
- `docker:container-name` - Docker container discovery
- `netalertx_sync` - Network device discovery

---

## Docker Container Discovery

### How It Works

`docker_sync` runs hourly and:
1. SSHs to docker-server and synology
2. Runs `docker ps -a` to list all containers
3. Compares with VMs in NetBox
4. **New containers**: Creates issue for approval
5. **Existing VMs**: Updates status (running ↔ offline)

### Ignored Containers

These are automatically skipped (defined in `docker_sync.py`):
- `dk400-autoheal`
- `watchtower`
- `cloudflared`

### Review Docker Discovery Issue

When you get a "New container" issue:

```bash
# Get issue details
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT message, metadata FROM fixer.unified_issues WHERE id = {ISSUE_ID};
\""
```

The metadata includes:
- `container_name`: Container name
- `host`: Which Docker host (docker-server, synology)
- `host_ip`: IP address
- `image`: Docker image
- `port`: Exposed port (if any)
- `check_url`: Suggested health check URL

### Approve and Add to NetBox

If container should be tracked:

```bash
# Create VM in NetBox (use metadata from issue)
ssh doug@192.168.20.19 'source /home/doug/dkSRC/infrastructure/homelab-brain/.env && curl -s -X POST \
  -H "Authorization: Token $NETBOX_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Container-Name\",
    \"cluster\": 1,
    \"status\": \"active\",
    \"description\": \"What this container does\",
    \"comments\": \"Host: docker-server\\nImage: image:tag\",
    \"custom_fields\": {
      \"check_enabled\": true,
      \"check_type\": \"http\",
      \"check_url\": \"http://192.168.20.19:PORT\"
    }
  }" \
  "http://192.168.20.19:8000/api/virtualization/virtual-machines/"'

# Then resolve the issue
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U fixer -d dk400 -c "
UPDATE fixer.unified_issues SET status = '\''resolved'\'', resolution = '\''Added to NetBox'\''
WHERE id = {ISSUE_ID};
"'
```

### Ignore Container

If container shouldn't be tracked (test, temporary, internal):

```bash
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U fixer -d dk400 -c "
UPDATE fixer.unified_issues SET status = '\''ignored'\'', resolution = '\''Not tracking - internal/test container'\''
WHERE id = {ISSUE_ID};
"'
```

**Note:** Ignored issues won't alert again for the same container.

### Add to Ignore List (Permanent)

For containers that should never be reported, add to `IGNORE_CONTAINERS` in `docker_sync.py`:

```python
IGNORE_CONTAINERS = {
    "dk400-autoheal",
    "watchtower",
    "cloudflared",
    "new-internal-container",  # Add here
}
```

---

## Network Device Discovery

## Quick Reference

### NetAlertX API

```bash
# Endpoint
http://192.168.20.19:20212/devices

# Auth token (hardcoded in netalertx_sync.py)
${NETALERTX_TOKEN}

# Full query
curl -s -H "Authorization: Bearer ${NETALERTX_TOKEN}" \
  "http://192.168.20.19:20212/devices"
```

### NetBox API

```bash
# Get token from environment
source /home/doug/dkSRC/infrastructure/homelab-brain/.env
echo $NETBOX_API_TOKEN

# Query devices
curl -s -H "Authorization: Bearer $NETBOX_API_TOKEN" \
  "http://192.168.20.19:8000/api/dcim/devices/"
```

## List Unknown Devices

### From Issue Database (Quick)

```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
SELECT source_name, LEFT(message, 100), occurrence_count, last_seen
FROM fixer.unified_issues
WHERE source_type = 'discovery' AND status NOT IN ('resolved', 'ignored');
\""
```

### From dk400 Logs (Recent)

```bash
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep 'Created issue for new device' | tail -20"
```

Output format: `Created issue for new device: {IP} ({MAC})`

### From NetAlertX API (Full Details)

```bash
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Bearer ${NETALERTX_TOKEN}' 'http://192.168.20.19:20212/devices'" | python3 -c '
import sys, json
data = json.load(sys.stdin)
devices = data.get("devices", data) if isinstance(data, dict) else data
for d in devices:
    status = d.get("status", "?")
    if status == "new" or not d.get("devName"):
        print(f"IP: {d.get(\"dev_LastIP\", \"?\")}")
        print(f"  MAC: {d.get(\"dev_MAC\", \"?\")}")
        print(f"  Vendor: {d.get(\"dev_Vendor\", \"?\")}")
        print(f"  First seen: {d.get(\"dev_FirstConnection\", \"?\")}")
        print()
'
```

## Identify Device by MAC

### Common Vendor Prefixes

| Prefix | Vendor | Likely Device |
|--------|--------|---------------|
| 1c:12:b0, cc:f7:35 | Amazon | Echo, Ring, Fire TV |
| 2c:aa:8e, 80:48:2c, 7c:78:b2 | Wyze | Cameras, sensors |
| 34:29:8f | Meross | Smart plugs, switches |
| dc:a6:32, b8:27:eb, e4:5f:01 | Raspberry Pi | Pi devices |
| 00:11:32 | Synology | NAS |
| 3c:22:fb | Apple | iPhone, iPad, Mac |
| f4:d4:88 | Google | Nest, Chromecast |

### MAC Vendor Lookup

```bash
# Online lookup (rate limited)
curl -s "https://api.macvendors.com/1c:12:b0"

# First 3 octets identify vendor
MAC="1c:12:b0:cf:26:92"
curl -s "https://api.macvendors.com/${MAC:0:8}"
```

## Add Device to NetBox

**CRITICAL:** netalertx_sync matches devices by MAC address. The primary MAC source is the `asset_tag` field on the device (68/82 devices use this). It also checks `custom_fields.mac_address` as a fallback. If you add a device without setting `asset_tag` to the MAC, it will keep being reported as unknown.

### Via API (Recommended)

```bash
ssh doug@192.168.20.19 'source /home/doug/dkSRC/infrastructure/homelab-brain/.env && curl -s -X POST \
  -H "Authorization: Bearer $NETBOX_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Device Name\",
    \"device_type\": 1,
    \"role\": 9,
    \"site\": 1,
    \"status\": \"active\",
    \"asset_tag\": \"AA:BB:CC:DD:EE:FF\",
    \"custom_fields\": {
      \"check_enabled\": false
    }
  }" \
  "http://192.168.20.19:8000/api/dcim/devices/"'
```

### Common Values

| Field | Value | Description |
|-------|-------|-------------|
| site | 1 | Homelab |
| device_type | 1 | Generic |
| role | 9 | IoT Device |
| status | active | Device is in use |

### Via Web UI

1. Go to http://192.168.20.19:8000/dcim/devices/add/
2. Fill in name, site, device type
3. Set **Asset tag** to the device MAC address (e.g., `aa:bb:cc:dd:ee:ff`)
4. Add primary IP in IPAM section
5. Save

## Resolve Discovery Issue

After adding device to NetBox or deciding to ignore:

```bash
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U fixer -d dk400 -c "
UPDATE fixer.unified_issues
SET status = '\''resolved'\'', resolution = '\''Added to NetBox'\''
WHERE source_type = '\''discovery'\'' AND id = {ISSUE_ID};
"'
```

Or mark as ignored (won't alert again for same MAC):

```bash
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U fixer -d dk400 -c "
UPDATE fixer.unified_issues
SET status = '\''ignored'\'', resolution = '\''Known device, not tracked in NetBox'\''
WHERE source_type = '\''discovery'\'' AND id = {ISSUE_ID};
"'
```

## Common Scenarios

### IoT Devices (Echo, Wyze, etc.)

Usually don't need monitoring. Options:
1. Add to NetBox with `check_enabled: false` - tracked but not monitored
2. Mark issue as ignored - won't alert again

### Devices Needing Physical Identification

For devices that can't be identified remotely (e.g., "which Meross plug is this?"):
1. Add to NetBox with a generic name like "Meross Device (unidentified)"
2. Leave `description` field **empty** - this flags it for identification
3. Add MAC and IP to `comments` field for reference
4. When physically home, identify and update `description` with what/where it is
5. Query devices needing identification:
   ```bash
   curl -s -H 'Authorization: Token ...' \
     'http://localhost:8000/api/dcim/devices/' | \
     jq '.results[] | select(.description == "") | {name, comments}'
   ```

### New Server/VM

Should be added to NetBox with proper configuration:
1. Add device with correct type and role
2. Set `check_enabled: true`
3. Configure `check_url` for health monitoring

### Unknown/Suspicious Device

Investigate before deciding:
1. Check if MAC matches any known devices
2. Check DHCP logs for hostname
3. Consider blocking at router if unauthorized

## Troubleshooting

### netalertx_sync Not Finding Devices

```bash
# Check if NetAlertX is running
curl -s http://192.168.20.19:20211/ | head -5

# Check sync logs
ssh doug@192.168.20.19 "docker logs dk400 2>&1 | grep netalertx_sync | tail -10"
```

### Device Keeps Being Reported

The sync matches by MAC address. Matching order: MAC → IP → name. If a device keeps being reported:

1. **Check asset_tag** — this is the primary MAC source (68/82 devices). If asset_tag is empty or doesn't contain the MAC, set it:
   ```bash
   curl -s -X PATCH \
     -H "Authorization: Token $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"asset_tag": "aa:bb:cc:dd:ee:ff"}' \
     "http://localhost:8000/api/dcim/devices/DEVICE_ID/"
   ```
2. **Check if device has a primary IP** — if the device has a static IP, ensure `primary_ip4` is set in NetBox for IP-based matching
3. **Check device name** — name matching is a fallback; the NetBox name must match what NetAlertX reports (case-insensitive)
4. **DHCP devices** — devices that get new IPs regularly will only match reliably by MAC. Always set asset_tag for these

## Related

- **Issue review skill**: `.claude/skills/issue-review/skill.md`
- **NetBox skill**: For detailed NetBox API operations
