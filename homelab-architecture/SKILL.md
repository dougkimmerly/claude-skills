---
name: homelab-architecture
description: Cross-cutting map of data flows between home (192.168.20.0/24) and boat (192.168.22.0/24) — what transports exist, where each kind of data lives, and the pre-flight queries to run before building any cross-site infrastructure. Use BEFORE proposing or implementing any cross-site sync, replication, mirror, backup, or routing change. Also use when answering "how does X work" / "where does Y land" questions about home↔boat data flows.
---

# Homelab Architecture (cross-site data flows)

This is the index for cross-site infrastructure between home and boat. **It is meant to be consulted before building anything, not after.** The most expensive failure mode is rediscovering what already exists.

## Pre-flight discipline

When asked to build, sync, replicate, mirror, back up, or route data between home and boat:

1. **Query state first** (state is authoritative; docs may be stale).
2. **For backup/replication work specifically: also read the canonical policy doc** at `infrastructure/homelab-runbooks/STRATEGY.md`. It defines the tier model, operating principles, and known gaps. Both tells you what already exists and what design rules apply. Skipping it has burned us more than once (built a redundant rsync mirror because Syncthing was already in place; later wiped 73 GB of audio because Tier 2 had no versioning — both were preventable by reading the doc first).

```bash
# What Syncthing folders are configured between hosts?
ssh doug@192.168.20.19 "docker exec syncthing wget -q -O- --header=\"X-API-Key: \$(docker exec syncthing sh -c 'grep -oE \"<apikey>[^<]+\" /var/syncthing/config/config.xml | sed s,\\<apikey\\>,,')\" http://localhost:8384/rest/config/folders" | jq '.[] | {id, path, type}'

# What postgres logical replication subscriptions exist?
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"SELECT subname, subenabled, subconninfo FROM pg_subscription;\""

# What Tailscale peers and current paths?
ssh doug@192.168.20.19 "tailscale status; tailscale ping -c 3 100.74.130.57"

# What router-level VPN/SpeedFusion tunnels?  
# Check Peplink InControl: https://mars.ic.peplink.com/  (account: dougkimmerly@gmail.com)
# Or the peplink-narwhal skill in homelab repo

# What scheduled jobs already touch cross-site data?
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U dk400 -d dk400 -c \"SELECT name, command, frequency FROM qsys._jobscde WHERE name LIKE '%BKP%' OR name LIKE '%BOAT%' OR name LIKE '%MIRROR%';\""
ssh doug@100.74.130.57 "docker exec dk400-postgres psql -U dk400 -d dk400 -c \"SELECT name, command, frequency FROM qsys._jobscde;\""
```

If a transport for the data class you're about to handle already exists, **use it or extend it** — do not build a parallel transport.

## Cross-site data classes and their canonical transports

| Data class | Source-of-truth | Transport | Lands at |
|---|---|---|---|
| **Boat-host file blobs** (signalk plugin configs, vhf transcripts, raw imaging documents/manuals, dk400-boat configs) | centralsk `/mnt/backup/unified/` | **Syncthing** folder `centralsk-backups` (sendonly on centralsk, receiveonly on home) | home `/home/doug/backups/centralsk/` → fans out to Synology Tier 2 + USB Tier 3 via additional Syncthing pairings |
| **Cruising DB rows** (cruising.* schemas: jobs, voyages, locations, etc.) | centralsk dk400-postgres | **Postgres logical replication** (subscriber=home, publisher=centralsk, subscription `cruising_sub`, 57 tables in state `r`) | home dk400-postgres in cruising.* schemas |
| **Imaging DB rows** (imaging.documents, imaging.document_chunks, etc.) | centralsk dk400-postgres | Postgres logical replication (similar pattern, `imaging_sub`) | home dk400-postgres imaging.* schemas |
| **NetBox rows (boat-site)** — home is the single authority (ADR 0013/0014) | **home** dk400-postgres `netbox` schema | **home-initiated push** (NOT replication): `NETBOX_BOAT` job → `netbox_boat_refresh` program upserts boat-site rows into the boat copy weekly. Direction note: boat→home postgres is CLOSED; home→boat works (192.168.22.15:5432). Role `netbox_sync` (SELECT/UPDATE on netbox). | boat dk400-postgres `netbox` schema (read locally by boat `backup_unified`/`health_check`) |
| **Galley shopping list / state** (bidirectional) | both ends | Syncthing `galley-sync` folder (sendreceive both sides) | varies by side |
| **Boat→home admin/SSH access** | — | Tailscale tailnet (centralsk 100.74.130.57 ↔ docker-server 100.121.19.37) when SpeedFusion VPN doesn't suffice | direct host-to-host |
| **Home→boat admin/SSH/HTTP** | — | TP-Link site-to-site VPN handles `192.168.20.x → 192.168.22.x` natively | works without Tailscale |
| **Boat→home for VLAN-routed traffic** (e.g. 192.168.20.x reachability from a boat client) | — | NarwhalCore `Manta Home` SSID / VLAN 24 (`192.168.24.0/24` HomeRelayNet) → SpeedFusion → home Peplink Relay | home network as if originating from `192.168.20.5` (NAT applied at relay) |

**Important asymmetries:**
- The home-side **Peplink SF Connect Relay (`192.168.20.5`)** is **inbound-only** (per its hardware mode). It cannot initiate outbound SpeedFusion tunnels. So home-initiated traffic to boat VLANs other than `192.168.22.x` (which TP-Link VPN handles) will not return — boat-initiated push is the supported direction for those VLANs.
- The boat→home file mirror therefore runs as a **boat-side push** (Syncthing centralsk-backups, sendonly direction). Don't write a home-side pull program — it cannot work for the Manta Home VLAN.

## Bandwidth ceilings and traps

- **Cross-site transports share Starlink upload at the boat** (≈ 15 Mbps measured). All paths converge on the same WAN underneath.
- **Single-stream TCP/SSH at ~210 ms RTT (boat→Toronto FusionHub→home) caps near 1-2 Mbps** due to TCP receive-window BDP. For bulk transfers, parallelize: per-source rsyncs, multi-connection Syncthing, or postgres replication's per-table parallel sync workers.
- **Tailscale path selection traps** are documented in `~/.claude/skills/tailscale/SKILL.md` (failure modes 1-6). Don't repeat. Both sides should run `tailscale-route-fix.service` to keep Tailscale on the public path, not the LAN-VPN path.
- **DERP relays are throttled by Tailscale to ~1-2 Mbps.** If `tailscale ping` reports `via DERP(...)`, you're on the slow fallback. Direct UDP path is ~3-5× faster but requires NAT cooperation (see tailscale skill failure mode 6).

## Service inventory (which existing skills cover what)

When a question concerns a specific subsystem, load the topical skill rather than re-deriving:

| Subsystem | Skill | Notes |
|---|---|---|
| Boat router, SpeedFusion, FusionHub, Manta wifi SSIDs, NarwhalCore VLAN map, FleetOne sat | `homelab-peplink-narwhal` | Most authoritative on boat networking |
| Boat host services list (centralsk machine inventory, Syncthing/SignalK/Docker port map) | `homelab-centralsk` | |
| Home docker host (192.168.20.19) services, Syncthing folder map | `homelab-docker-server` | |
| Synology NAS (Tier 2/3 backups, arrstack) | `homelab-synology` | |
| Boat LAN device DHCP table, SignalK, Victron, Maretron | `homelab-boat-network` | |
| TP-Link router (192.168.20.1) | `homelab-houserouter` | |
| DNS / NPM proxy at home | `homelab-proxy-dns` | |
| Control4 home automation | `homelab-c4` | |
| dk400 scheduler (Robot, Celery, programs/) | `homelab-dk400` AND `robot` | dk400 universal skill complements |
| NetBox source-of-truth queries | `netbox` | universal |
| Postgres logical replication setup/troubleshooting | `postgres-replication` | universal |
| Tailscale path/NAT diagnosis | `tailscale` | universal |
| Bitwarden credential access | `bitwarden` | universal |

## Authoritative policy docs (live in git, not skills)

These are NOT skills — they're committed policy documents. Read them before designing in their domain. Skills are diagnostic-first; these are decision-first.

| Domain | Doc | When to read |
|---|---|---|
| **Backup & resilience strategy** (3-tier model, operating principles, known gaps) | `infrastructure/homelab-runbooks/STRATEGY.md` | Before any backup, replication, or mirror work — at home OR boat |
| Stored Boat (8-month unattended period plan) | `infrastructure/fixer/docs/runbooks/stored-boat-plan.md` | When Doug says "Stored Boat" or working on storage-mode resilience |
| Boat disaster recovery (recovery procedures by data class) | `infrastructure/fixer/docs/runbooks/boat-disaster-recovery.md` | When restoring from any tier or planning a DR test |
| TP-Link UDP 41641 port-forward (Tailscale-direct fix) | `infrastructure/fixer/docs/runbooks/tplink-tailscale-portforward.md` | When working on Tailscale path issues |
| Architectural decisions | `infrastructure/fixer/docs/decisions/0001..NN-*.md` | When the "why" matters, not just current state |

## When to update this skill

Update this skill when **any cross-site transport changes**: a new Syncthing folder is added, a postgres subscription appears, a VPN profile is created, a VLAN egress changes. The query commands above should always return current truth; if reality has drifted from this document, the document is wrong, not reality. Update both this index AND the relevant topical skill (don't just edit one).

When you find that yet again you're about to build something that already exists, that's a signal that some fact wasn't surfaced clearly enough in this index. Add it.
