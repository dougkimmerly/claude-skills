# Pi-hole Reference

## Infrastructure

| Item | Value |
|------|-------|
| Host | Synology NAS (192.168.20.16) |
| Container | `Pi-Hole` |
| Version | v6.x |
| Admin UI | http://192.168.20.16/admin |
| Docker path | `/volume1/docker/homelab-synology/pihole/` |

## Container Access

```bash
# Execute commands in container
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker exec Pi-Hole COMMAND"

# Examples
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker exec Pi-Hole pihole status"
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker exec Pi-Hole pihole -v"
```

## Config File Locations

### On Synology Host

```
/volume1/docker/homelab-synology/pihole/
├── pihole/           → mounted to /etc/pihole
│   ├── gravity.db    # Blocklists database
│   ├── pihole-FTL.db # Query database
│   └── custom.list   # Legacy (not used in v6)
└── dnsmasq.d/        → mounted to /etc/dnsmasq.d
    ├── custom.conf              # A records (address=)
    └── 05-pihole-custom-cname.conf  # CNAME records
```

### In Container

```
/etc/pihole/          # Pi-hole config
/etc/dnsmasq.d/       # DNS server config
```

## DNS Record Syntax

### A Record (address)

Maps domain directly to IP:

```
address=/domain.kbl55.com/192.168.20.XX
```

Use for:
- Services accessed directly by IP
- Services not behind NPM proxy

### CNAME Record

Aliases domain to another domain:

```
cname=service.kbl55.com,npm.kbl55.com
```

Use for:
- Services behind NPM proxy
- All `*.kbl55.com` domains that route through NPM

## Pi-hole Commands

```bash
# Status
pihole status

# Version
pihole -v

# Reload DNS (quick, may miss changes)
pihole reloaddns

# Reload lists only
pihole reloadlists

# Update gravity (blocklists)
pihole -g

# Query a domain
pihole -q domain.com

# Tail DNS log
pihole -t
```

## Adding Records

### Add A Record

```bash
ssh doug@192.168.20.16 "echo 'address=/SERVICE.kbl55.com/192.168.20.XX' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/custom.conf"
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
```

### Add CNAME Record

```bash
ssh doug@192.168.20.16 "echo 'cname=SERVICE.kbl55.com,npm.kbl55.com' | sudo tee -a /volume1/docker/homelab-synology/pihole/dnsmasq.d/05-pihole-custom-cname.conf"
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
```

## Removing Records

```bash
# Edit file to remove line
ssh doug@192.168.20.16 "sudo sed -i '/SERVICE.kbl55.com/d' /volume1/docker/homelab-synology/pihole/dnsmasq.d/custom.conf"
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
```

## Verification

```bash
# Query Pi-hole directly
nslookup domain.kbl55.com 192.168.20.16

# Check from server using Pi-hole
ssh doug@192.168.20.19 "nslookup domain.kbl55.com"
```

## Secondary Pi-hole

| Item | Value |
|------|-------|
| Host | Raspberry Pi (192.168.20.3) |
| Purpose | DNS failover |
| Version | v6.x (native install, not Docker) |
| Admin UI | http://192.168.20.3/admin |

### No Automatic Sync

**IMPORTANT:** Primary and secondary Pi-hole are NOT automatically synced. DNS records must be manually added to both for redundancy.

### Secondary Config Location

```
/etc/pihole/pihole.toml           # All config including DNS records
```

### Adding Records to Secondary (Pi-hole v6)

Edit the `[dns]` section's `hosts` array in pihole.toml:

```bash
# View current DNS hosts
ssh doug@192.168.20.3 "sudo grep -A20 'hosts = \[' /etc/pihole/pihole.toml | head -25"

# Add entry (manual edit required for toml array)
# Then restart:
ssh doug@192.168.20.3 "sudo systemctl restart pihole-FTL"
```

**Note:** Secondary uses pihole.toml `hosts` array, NOT custom.list or dnsmasq.d files.

### Sync Checklist

When adding DNS records, update BOTH:
1. Primary (Synology .16) - dnsmasq format
2. Secondary (Pi .3) - legacy format or create dnsmasq.d file

### Verify Both

```bash
# Check primary
nslookup domain.kbl55.com 192.168.20.16

# Check secondary
nslookup domain.kbl55.com 192.168.20.3
```

### Pi-hole v6 Configuration Notes

In Pi-hole v6, DNS records are configured in `/etc/pihole/pihole.toml`:

```toml
[dns]
  upstreams = ["8.8.8.8", "8.8.4.4"]  # REQUIRED - empty = REFUSED
  hosts = [
    "192.168.20.19 npm.kbl55.com",
    "192.168.20.19 docs.kbl55.com"
  ]
```

**IMPORTANT:** The `hosts = []` array appears TWICE in pihole.toml:
1. `[dns]` section (line ~129) - for DNS records
2. `[dhcp]` section (line ~670) - for DHCP static leases (different format)

Do NOT put DNS entries in the DHCP hosts array.

## Troubleshooting

### Record Added But Not Resolving

1. Check file syntax (no typos, correct format)
2. Restart container (not just reload)
3. Query Pi-hole directly to bypass caches

### Container Won't Start

Check logs:
```bash
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker logs Pi-Hole --tail 50"
```

### Database Locked

If FTL database is locked:
```bash
ssh doug@192.168.20.16 "sudo /usr/local/bin/docker restart Pi-Hole"
```
