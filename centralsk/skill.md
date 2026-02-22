# CentralSK - Boat Server Skill

CentralSK is the primary compute server for Distant Shores II. Ubuntu 24.04 LTS running Docker containers and native SignalK.

## Server

| Info | Value |
|------|-------|
| Staging IP | 192.168.20.209 (house network) |
| Production IP | 192.168.22.15 (boat Ethernet) |
| SSH | `ssh doug@192.168.20.209` (staging) |
| OS | Ubuntu 24.04 LTS |

---

## Architecture

```
CentralSK (.15 boat / .209 staging)
│
├── NATIVE SERVICES (systemd)
│   └── SignalK Server v2.19.1
│       ├── Port 3000 (API/WebSocket/Admin)
│       ├── Node-RED (plugin)
│       ├── iKonvert NavNet (/dev/ikonvert-nav)
│       └── iKonvert PowerNet (/dev/ikonvert-power)
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
└── DATA SOURCES (boat network)
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
ssh doug@192.168.20.209  # staging
ssh doug@192.168.22.15   # production

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
```

---

## Network

| IP | Device | Purpose |
|----|--------|---------|
| .1 | Peplink | Router, DHCP, backup DNS |
| .14 | Power Net Pi | NMEA2000 power network |
| .15 | CentralSK | Main server |
| .16 | Nav Net Pi | NMEA2000 nav network |
| .25 | Victron GX | Battery/MPPT |

- **House staging:** 192.168.20.0/24
- **Boat production:** 192.168.22.0/24
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
