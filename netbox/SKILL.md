# NetBox Skill

Query and update infrastructure data in NetBox.

## Quick Reference

```bash
# Get token from dk400 container
TOKEN=$(ssh doug@192.168.20.19 "docker exec dk400 printenv NETBOX_TOKEN")

# Query with token
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' 'http://localhost:8000/api/...'"
```

## Database — single consolidated DB (since 2026-05-31)

There is **one** NetBox, living as the `netbox` schema in the **`dk400` database** on `dk400-postgres`. The old standalone `netbox-postgres` container was decommissioned (see fixer ADR 0013). Two access paths, **same data**:
- **Web app / REST API** (`netbox` + `netbox-worker` containers) → `dk400-postgres`, db `dk400`, role `netbox` (role-level `search_path = netbox, public`).
- **dk400 programs** (`health_check`, `backup_unified`, `netbox_*`) → direct SQL via `dk400.db` into the `netbox` schema.

Direct SQL: `docker exec dk400-postgres psql -U fixer -d dk400 -c "... FROM netbox.<table> ..."` (schema-qualify with `netbox.`).

## Authentication

Tokens are **v2 (HMAC-peppered)**: stored as `key` (12-char fragment) + `pepper_id` + `hmac_digest`; the plaintext is **never stored**. A token is presented as `nbt_<key>.<secret>`. Always read it from the env, never hardcode:

```bash
TOKEN=$(ssh doug@192.168.20.19 "docker exec dk400 printenv NETBOX_TOKEN")   # nbt_<key>.<secret>
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' 'http://localhost:8000/api/ENDPOINT'"
# NETBOX_URL=http://192.168.20.19:8000
```

**Minting a token** (the full secret is shown only once, at creation — read `.token`, NOT the nulled `.plaintext` field):
```bash
docker exec netbox /opt/netbox/netbox/manage.py shell -c "
from users.models import Token, User
t=Token(user=User.objects.get(username='admin'), write_enabled=False, description='<purpose>'); t.save()
print('nbt_'+t.key+'.'+t.token)"
```
Each API consumer gets its own token (Command Centre uses a read-only one); `NETBOX_TOKEN` lives in each consumer's compose `.env`.

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/dcim/devices/` | Physical devices (servers, switches, routers) |
| `/api/virtualization/virtual-machines/` | VMs and containers |
| `/api/ipam/services/` | Application services running on VMs/devices |
| `/api/ipam/ip-addresses/` | IP address assignments |
| `/api/dcim/sites/` | Sites/locations |

**Important:** Health-checked targets can be devices, VMs, OR services - check all three if you don't find something.

**When investigating issues:** Always check the `description` and `comments` fields first - they may explain expected behavior or provide context about the device.

## Common Queries

### Find a device/VM by name
```bash
# Search devices (physical)
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/dcim/devices/?name__ic=SEARCHTERM' | jq '.results[] | {name, status: .status.value, primary_ip: .primary_ip4.address, custom_fields}'"

# Search VMs/containers
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/virtualization/virtual-machines/?name__ic=SEARCHTERM' | jq '.results[] | {name, status: .status.value, primary_ip: .primary_ip4.address, custom_fields}'"
```

### List all devices with health checks enabled
```bash
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/virtualization/virtual-machines/?cf_check_enabled=true' | jq '.results[] | {name, check_type: .custom_fields.check_type, check_url: .custom_fields.check_url}'"
```

### Get device by ID
```bash
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/dcim/devices/ID/' | jq"
```

## Health Check Custom Fields

These custom fields control health monitoring:

| Field | Type | Purpose |
|-------|------|---------|
| `check_enabled` | bool | Whether to monitor this device |
| `check_type` | string | `http`, `ping`, `tcp`, `container` |
| `check_url` | string | URL or IP to check |
| `expected_status` | int | Expected HTTP status code |
| `check_timeout` | int | Timeout in seconds |
| `is_critical` | bool | Escalate immediately if down |
| `intermittent` | bool | Known to come and go |
| `expected_state` | string | `up`, `down`, `unknown` |
| `depends_on` | string | Parent device (skip if parent down) |

## Application Services Pattern

Use **Services** when multiple web applications run on the same VM/container. Services attach to a parent VM or device.

### When to Use Each Model

| Scenario | Model | Example |
|----------|-------|---------|
| Separate container | VM | Music Library, Sonarr, Radarr |
| Multiple apps in one container | Services on VM | SignalK webapps |
| Physical hardware | Device | Router, NAS, Raspberry Pi |
| App on physical hardware | Service on Device | SSH on Pi-hole |

### Services vs VMs Decision Tree

```
Is it a separate container/process?
├─ Yes → Create a VM
└─ No, multiple apps share one container
   └─ Create one VM for the container
      └─ Create Services attached to that VM for each app
```

### SignalK Webapps Example

SignalK servers host multiple webapps (Freeboard, Instrumentpanel, KIP, etc.) all running on the same container.

**Structure in NetBox:**
```
HomeSK (VM) - check_url: http://192.168.20.19:3000
├── Freeboard-SK (Service) - check_url: http://192.168.20.19:3000/@signalk/freeboard-sk/
├── Instrumentpanel (Service) - check_url: http://192.168.20.19:3000/@signalk/instrumentpanel/
├── KIP Instrument MFD (Service) - check_url: http://192.168.20.19:3000/@mxtommy/kip/
└── Vessel Positions (Service) - check_url: http://192.168.20.19:3000/@signalk/vesselpositions/
```

### Creating a Service

```bash
ssh doug@192.168.20.19 "curl -s -X POST \
  -H 'Authorization: Token $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    \"parent_object_type\": \"virtualization.virtualmachine\",
    \"parent_object_id\": VM_ID,
    \"name\": \"Service Name\",
    \"protocol\": \"tcp\",
    \"ports\": [80],
    \"description\": \"package-name - Description\",
    \"custom_fields\": {
      \"check_enabled\": true,
      \"check_type\": \"http\",
      \"check_url\": \"http://host:port/path/\"
    }
  }' 'http://localhost:8000/api/ipam/services/'"
```

### Listing Services on a VM

```bash
# Get services attached to a specific VM
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/ipam/services/?parent_object_id=VM_ID' | jq '.results[] | {name, check_url: .custom_fields.check_url}'"

# Get all services attached to VMs (not devices)
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/ipam/services/?parent_object_type=virtualization.virtualmachine'"
```

### Service Custom Fields

Services support the same health check custom fields as VMs:
- `check_enabled` - Whether to health check this service
- `check_type` - `http`, `https`, `tcp`
- `check_url` - Full URL to check
- `is_critical` - Send Telegram alerts if down
- `expected_state` - `up`, `down`, `maintenance`

### SignalK Webapp Discovery

health_check.py automatically compares NetBox services to actual SignalK webapps:
- **New webapp on server** → Creates discovery issue
- **Webapp in NetBox but missing from server** → Creates missing issue

This ensures NetBox stays in sync with reality.

## Hardware Specs Custom Fields

The `hardware_specs` program (Robot job `INFRA_HW_SPECS`, weekly Sunday 3 AM) SSHes into devices/VMs and populates these fields automatically. Supports Linux (Ubuntu, Debian, Synology, Raspberry Pi) and Windows (PowerShell over SSH).

| Field | Type | Purpose |
|-------|------|---------|
| `gather_hw_specs` | bool | Opt-in: enable hardware spec collection |
| `hw_cpu_model` | text | e.g. "Intel(R) Celeron(R) J4125 CPU @ 2.00GHz" |
| `hw_cpu_cores` | int | Core count |
| `hw_ram_mb` | int | Total RAM in MB |
| `hw_disk_summary` | text | e.g. "1.8T ST2000DM001-1ER164" |
| `hw_os_version` | text | e.g. "Ubuntu 24.04.3 LTS", "DSM 7.2 (build 72806)" |
| `hw_serial` | text | Serial number from BIOS (dmidecode) |
| `hw_product_model` | text | Product name (e.g. "DS1520+", "Dell XPS 8960") |
| `hw_last_collected` | text | ISO timestamp of last scan |
| `gpu_model` | text | Discrete GPU preferred, e.g. "NVIDIA GeForce RTX 4060" |
| `gpu_vram_mb` | int | GPU VRAM in MB (from nvidia-smi) |
| `gpu_cuda_version` | text | CUDA version (from nvidia-smi banner) |

Fields are grouped under "Hardware Specs" in the NetBox UI. GPU fields are populated via `lspci` + `nvidia-smi` on Linux, `Win32_VideoController` + `nvidia-smi` on Windows. Discrete GPUs are preferred over integrated Intel.

### Enabling on a device

Set `gather_hw_specs=true` and ensure `ssh_user` is set:

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"custom_fields":{"gather_hw_specs":true,"ssh_user":"doug"}}' \
  "http://192.168.20.19:8000/api/dcim/devices/DEVICE_ID/"
```

### Running manually

```bash
ssh doug@192.168.20.19 "docker exec dk400 python -c \"
from programs import hardware_specs
import asyncio, json
print(json.dumps(asyncio.run(hardware_specs.run()), indent=2, default=str))
\""
```

### OS support

Handles Ubuntu/Debian, Synology DSM, Raspberry Pi, and generic Linux. Falls back gracefully when commands aren't available (e.g. `lscpu` on Synology, `dmidecode` on Pi).

## Power Control Custom Fields

For devices whose power can be remotely controlled (via smart plugs, PDUs, etc.):

| Field | Type | Purpose |
|-------|------|---------|
| `power_controller` | string | Device that controls power (e.g., "Meross Plug 3", "Wattbox") |
| `power_outlet` | string | Which outlet/relay (e.g., "1", "outlet_a", "relay2") |
| `power_control_method` | string | How to control: `meross_api`, `wattbox_api`, `http_get`, `manual` |

**Usage for remediation:** When a device is down, check if it has a `power_controller`. If so, try power cycling via the specified method.

**Finding devices by controller:**
```bash
ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/dcim/devices/?cf_power_controller__ic=meross' | jq '.results[] | {name, power_controller: .custom_fields.power_controller, power_outlet: .custom_fields.power_outlet}'"
```

## Updating a Device

Use PATCH to update specific fields:

```bash
# Get the VM ID first
ID=$(ssh doug@192.168.20.19 "curl -s -H 'Authorization: Token $TOKEN' \
  'http://localhost:8000/api/virtualization/virtual-machines/?name__ic=DEVICENAME' | jq -r '.results[0].id'")

# Update custom field
ssh doug@192.168.20.19 "curl -s -X PATCH \
  -H 'Authorization: Token $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"custom_fields\": {\"check_enabled\": false}}' \
  'http://localhost:8000/api/virtualization/virtual-machines/$ID/'"
```

## Query Filters

Common filter suffixes:
- `?name=exact` - Exact match
- `?name__ic=partial` - Case-insensitive contains
- `?status=active` - Filter by status
- `?cf_FIELDNAME=value` - Filter by custom field

## Network Subnets

| Subnet | Purpose |
|--------|---------|
| 192.168.20.x | Main homelab network |
| 192.168.22.x | Boat network (Narwhal) |

## Boat Network (192.168.22.x)

**Expect the boat to be online.** It has redundant connectivity:
- Primary: Cellular connection
- Backup: Starlink

**Boat devices:**
| Device | IP | Purpose |
|--------|-----|---------|
| NarwhalCore Router | 192.168.22.1 | Boat gateway/router |
| iKomunicate | 192.168.22.11 | NMEA to SignalK bridge |
| Power Net | 192.168.22.14 | Power management SignalK server |
| Central SK | 192.168.22.15 | Central SignalK server |
| Nav Net | 192.168.22.16 | Navigation SignalK server |

## SignalK Servers

| Server | IP | Location | Webapps |
|--------|-----|----------|---------|
| HomeSK | 192.168.20.19:3000 | Home (docker-server) | 4 |
| Power Net | 192.168.22.14 | Boat | 7 |
| Nav Net | 192.168.22.16 | Boat | 14 |
| Central SK | 192.168.22.15 | Boat (planned) | - |

Each SignalK server's webapps are modeled as Services attached to the server VM. Query webapps from a SignalK server:

```bash
curl -s "http://SIGNALK_IP:PORT/skServer/webapps" | jq '.[].name'
```

**Diagnosing boat issues:**
1. First check if boat network is reachable: `ping 192.168.22.1` (the router)
2. If router is up but a device is down → device-specific issue
3. If router is down → network connectivity issue (cellular/Starlink)
4. Latency ~100-150ms is normal (cellular), don't flag as slow

**We want to measure boat network reliability** - don't ignore issues, investigate them. The health checks help track uptime and identify problems.

## Web UI

NetBox UI: http://192.168.20.19:8000

Login credentials in Bitwarden (use bitwarden skill).
