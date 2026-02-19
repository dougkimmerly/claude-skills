# Deployment Reference

## Two-Repo Architecture

```
SOURCE REPO (galley-meal-planner)          MACHINE REPO (homelab-docker-server)
──────────────────────────────             ────────────────────────────────────
/home/doug/dkSRC/apps/                     /opt/docker-server/galley/
  galley-meal-planner/                     ├── compose.yaml  ← build context → source
├── src/                                   ├── .env          ← secrets (gitignored)
├── public/                                ├── data/         ← database (gitignored)
├── Dockerfile                             └── credentials/  ← Google creds (gitignored)
└── package.json
```

**Rule:** CC-galley only modifies the source repo. The machine repo (homelab-docker-server) is managed by CC-homelab.

## Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY src/ ./src/
COPY public/ ./public/
EXPOSE 3122
CMD ["node", "src/app.js"]
```

- Alpine base for minimal image (~150MB)
- Production dependencies only
- No dev tools in production image

## Docker Compose (Production)

Located at `/opt/docker-server/galley/compose.yaml`:

```yaml
services:
  galley:
    build:
      context: /home/doug/dkSRC/apps/galley-meal-planner
      dockerfile: Dockerfile
    container_name: galley
    restart: unless-stopped
    ports:
      - "3122:3122"
    env_file: .env
    volumes:
      - ./data:/app/data
      - ./credentials:/app/credentials
      - ./scans:/app/scans
    networks:
      - homelab
```

## Environment Variables

### Required
| Variable | Description | Example |
|----------|-------------|---------|
| NODE_ENV | Environment | production |
| PORT | Server port | 3122 |
| PGHOST | PostgreSQL host | postgres-homelab |
| PGPORT | PostgreSQL port | 5432 |
| PGDATABASE | Database name | dk400 |
| PGUSER | Database user | galley |
| PGPASSWORD | Database password | (secret) |

### Optional (Google Sheets Sync)
| Variable | Description |
|----------|-------------|
| GOOGLE_APPLICATION_CREDENTIALS | Path to service account JSON |
| GOOGLE_SHEETS_ID | Default sheet ID |

## Deployment Workflow

```bash
# Step 1: Push source code (from dev machine)
cd /Users/doug/Programming/dkSRC/apps/galley-meal-planner
git add -A && git commit -m "description" && git push

# Step 2: SSH to docker server and pull
ssh doug@192.168.20.19
cd /home/doug/dkSRC/apps/galley-meal-planner
git pull

# Step 3: Rebuild container
cd /opt/docker-server/galley
docker compose up -d --build

# Step 4: Verify
docker logs galley --tail 20
curl http://localhost:3122/api/health
```

## Volume Mounts

| Container Path | Host Path | Purpose |
|---------------|-----------|---------|
| /app/data | /opt/docker-server/galley/data | Database files (legacy SQLite) |
| /app/credentials | /opt/docker-server/galley/credentials | Google service account JSON |
| /app/scans | /opt/docker-server/galley/scans | Uploaded recipe images |

## Networking

- **Internal**: `homelab` Docker network (access to postgres-homelab, other services)
- **External**: Port 3122 exposed on host
- **Remote**: Tailscale VPN (no public internet exposure)
- **URL**: `http://192.168.20.19:3122` (LAN) or via Tailscale hostname

## Troubleshooting

### Container won't start
```bash
docker logs galley --tail 50
# Check for missing env vars or DB connection issues
```

### Database connection refused
```bash
# Verify postgres-homelab is running
docker ps | grep postgres
# Check network connectivity
docker exec galley ping postgres-homelab
```

### Schema not found
```bash
# Connect to DB and verify schema exists
docker exec -it postgres-homelab psql -U galley -d dk400 -c "\\dn"
# Run schema if missing
docker exec -i postgres-homelab psql -U galley -d dk400 < src/db/schema-postgres.sql
```

### Rebuild from scratch
```bash
cd /opt/docker-server/galley
docker compose down
docker compose up -d --build --force-recreate
```

## Development Setup

```bash
# Local development (connects to remote PostgreSQL)
cp .env.example .env
# Edit .env with database credentials
npm install
npm run dev  # Starts on port 3000 with auto-reload

# Docker development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```
