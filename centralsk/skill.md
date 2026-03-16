# CentralSK - Boat Server Skill

CentralSK is the primary compute server for Distant Shores II. Ubuntu 24.04 LTS running Docker containers and native SignalK.

## Server

| Info | Value |
|------|-------|
| Ethernet IP | 192.168.22.15 (boat network) |
| WiFi IP | 192.168.22.18 (boat network, backup) |
| SSH | `ssh doug@192.168.22.15` |
| OS | Ubuntu 24.04 LTS |
| Hardware | XCY X63G fanless industrial mini PC |
| CPU | Intel i7-9750H (6C/12T), 32GB DDR4, 1TB NVMe |
| Power | DC 9V-36V input, ATX/AT switch for auto-power-on |
| Serial/GPIO | 6x DB9 COM (RS232/422/485), 14x GPIO |
| BIOS | AMI v5.13 (2022-11-09) |
| Status | **LIVE** on Distant Shores II |

---

## Architecture

```
CentralSK (.15 Ethernet / .18 WiFi)
│
├── NATIVE SERVICES (systemd)
│   └── SignalK Server v2.19.1 (Node v20.19.6)
│       ├── Port 3000 (API/WebSocket/Admin)
│       ├── Node-RED (plugin)
│       ├── iKonvert NavNet (/dev/ikonvert-nav) — 30 devices
│       └── iKonvert PowerNet (/dev/ikonvert-power) — 18 devices
│
├── DOCKER — /opt/centralsk/ (dougkimmerly/centralsk repo)
│   ├── NPM (80, 443, 81) — Reverse proxy
│   ├── PostgreSQL (5432) — dk400-postgres
│   ├── InfluxDB (8086) — Time-series
│   ├── Grafana (3001) — Dashboards
│   ├── Pi-hole (53, 8053) — DNS + ad blocking
│   ├── NetAlertX (20211) — Network discovery
│   ├── Homepage (3080) — Dashboard
│   ├── Portainer (9000) — Docker management
│   ├── Syncthing (8384) — File sync
│   └── Galley (3122) — Meal planning
│
├── DOCKER — /opt/dk400-boat/ (dougkimmerly/dk400-boat repo)
│   ├── dk400 (8400 API, 8500 Web) — Monitoring + 5250 terminal
│   ├── dk400-redis — Celery broker
│   └── dk400-flower (5555) — Celery monitor
│
├── DOCKER NETWORK
│   └── boat (external) — All services interconnected
│
└── DATA SOURCES
    ├── iKonvert Nav (USB, B400BI8S) — NavNet NMEA2000 (RAW mode 15, 230400 baud)
    ├── iKonvert Power (USB, B400BI8Z) — PowerNet NMEA2000 (RAW mode 15, 230400 baud)
    ├── Power Net Pi (.14) — Maretron MPower
    ├── Nav Net Pi (.16) — GPS, AIS, instruments
    └── Victron GX (.25) — Battery/MPPT
```

**Two NMEA2000 networks** exist because Maretron MPower devices are extremely noisy and overwhelm navigation equipment. CentralSK aggregates both via iKonvert USB gateways.

---

## Two Repos on Server

| Repo | GitHub | Server Path | Contains |
|------|--------|-------------|----------|
| centralsk | dougkimmerly/centralsk | /opt/centralsk/ | Infrastructure compose files (postgres, grafana, pihole, npm, etc.) |
| dk400-boat | dougkimmerly/dk400-boat | /opt/dk400-boat/ | dk400 monitoring deployment (engine + shared programs submodules) |

---

## Database

### PostgreSQL (dk400-postgres, port 5432)

| Schema | Purpose |
|--------|---------|
| qsys | Job schedules, health checks, job history, user profiles |
| fixer | Issues, actions, remediation log |
| netbox | Synced from house — read-only target data for health checks |

**User:** `dk400`
**Access:** `docker exec -it dk400-postgres psql -U dk400 dk400`

### InfluxDB (port 8086)

- **Bucket:** `signalk` — All SignalK time-series data
- **Source:** SignalK → signalk-to-influxdb2 plugin

---

## Common Commands

```bash
# SSH
ssh doug@192.168.22.15

# SignalK
sudo systemctl status signalk
sudo systemctl restart signalk
journalctl -u signalk -f

# Docker services
docker ps
cd /opt/centralsk && docker compose -f SERVICE/compose.yaml up -d
cd /opt/centralsk && docker compose -f SERVICE/compose.yaml logs -f --tail 50

# dk400
cd /opt/dk400-boat
docker compose logs dk400 -f --tail 50
curl http://localhost:8400/health

# Deploy centralsk updates
cd /opt/centralsk && git pull
cd SERVICE && docker compose up -d

# Deploy dk400-boat updates
cd /opt/dk400-boat && git pull --recurse-submodules && docker compose up -d --build

# Database
docker exec -it dk400-postgres psql -U dk400 dk400

# iKonvert devices
ls -la /dev/ikonvert* /dev/ttyUSB*

# SignalK API (with auth token)
SK_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2UiOiJjbGF1ZGUtY29kZSIsImlhdCI6MTc3MzY4MjE3Nn0.YIkHGp8nYZhqjyfOiymYG2vzBBor4KXptwrZja195ek"
curl -s -H "Authorization: Bearer $SK_TOKEN" http://localhost:3000/skServer/providers
curl -s -H "Authorization: Bearer $SK_TOKEN" http://localhost:3000/signalk/v1/api/vessels/self/
```

---

## iKonvert USB Gateways

| Property | NavNet | PowerNet |
|----------|--------|----------|
| Serial | B400BI8S | B400BI8Z |
| Symlink | /dev/ikonvert-nav | /dev/ikonvert-power |
| Mode | 15 (RAW) — all DIP switches ON | 15 (RAW) — all DIP switches ON |
| Baud | 230400 | 230400 |
| Firmware | v3.34 | v3.34 |
| Provider type | `ikonvert-canboatjs` via `providers/simple` | `ikonvert-canboatjs` via `providers/simple` |
| N2K devices | 30 (GPS, AIS, autopilot, MPPT, etc.) | 18 (CLMD16 breakers, CKM12 keypads) |

---

## Network

| IP | Device | Purpose |
|----|--------|---------|
| .1 | Peplink | Router, DHCP, backup DNS |
| .14 | Power Net Pi | NMEA2000 power network |
| .15 | CentralSK | Main server (Ethernet) |
| .18 | CentralSK | Main server (WiFi, backup) |
| .16 | Nav Net Pi | NMEA2000 nav network |
| .25 | Victron GX | Battery/MPPT |

- **Boat network:** 192.168.22.0/24 (LIVE)
- **House staging retired** (was 192.168.20.209)
- **VPN:** Peplink SpeedFusion (primary), Tailscale (backup)

---

## Clean URLs (NPM + Pi-hole)

| Service | URL |
|---------|-----|
| SignalK | http://signalk.kbl55.com |
| Grafana | http://grafana.kbl55.com |
| Galley | http://galley.kbl55.com |
| dk400 | http://dk400.kbl55.com |
| Pi-hole | http://pihole.kbl55.com |
| Portainer | http://portainer.kbl55.com |
| Homepage | http://homepage.kbl55.com |
| Syncthing | http://syncthing.kbl55.com |

---

## Related Skills

- `dk400/` — dk400 platform development
- `signalk-expert/` — SignalK plugin development, paths, APIs
- `proxy-dns/` — Pi-hole DNS and NPM reverse proxy management
- `galley-expert/` — Galley meal planner
