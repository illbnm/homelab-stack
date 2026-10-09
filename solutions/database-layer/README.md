# Database Layer Stack

Shared database infrastructure for Nextcloud, Outline, Gitea, Authentik, and Grafana.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| PostgreSQL | `postgres:16.4-alpine` | Primary database (multi-tenant) |
| Redis | `redis:7.4.0-alpine` | Cache/queue |
| MariaDB | `mariadb:11.5.2` | MySQL compatible (optional for Nextcloud) |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL management UI |
| Redis Commander | `rediscommander/redis-commander:latest-sha` | Redis management UI |

## Features

- **Multi-tenant PostgreSQL**: Single instance with separate databases and users per service
- **Redis multi-database**: Isolated DB numbers per service (0-4)
- **Automated backups**: Daily compressed backups with 7-day retention
- **Health checks**: All databases have strict health checks
- **Network isolation**: Databases on internal network only (not exposed to Traefik except admin UIs)
- **Idempotent initialization**: Safe to run init script multiple times

## Prerequisites

1. **Base infrastructure stack** deployed (Traefik, Portainer, Watchtower)
2. **External `proxy` network** created: `docker network create proxy`
3. **DNS records** for admin UIs:
   - `pgadmin.example.com` → YOUR_SERVER_IP
   - `redis.example.com` → YOUR_SERVER_IP

## Setup Instructions

### 1. Configure Environment

```bash
cd stacks/databases

# Copy environment template
cp .env.example .env

# Edit with your passwords
nano .env
```

**Important:** Change all default passwords before deployment!

### 2. Initialize Databases

The initialization script runs automatically on first PostgreSQL startup. To run manually:

```bash
# Make script executable
chmod +x scripts/init-databases.sh

# Run initialization
docker compose exec postgres /docker-entrypoint-initdb.d/init-databases.sh
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Verify Deployment

```bash
# Check all containers
docker compose ps

# Test PostgreSQL connection
docker compose exec postgres psql -U postgres -c "\l"

# Test Redis connection
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Test MariaDB connection
docker compose exec mariadb mysql -u root -p$MARIADB_ROOT_PASSWORD -e "SHOW DATABASES;"
```

### 5. Access Admin UIs

- **pgAdmin**: https://pgadmin.example.com
- **Redis Commander**: https://redis.example.com

## Connection Strings

### PostgreSQL

```bash
# Nextcloud
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud

# Gitea
postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea

# Outline
postgresql://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline

# Authentik
postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik

# Grafana
postgresql://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana
```

### Redis

```bash
# Authentik (DB 0)
redis://:${REDIS_PASSWORD}@redis:6379/0

# Outline (DB 1)
redis://:${REDIS_PASSWORD}@redis:6379/1

# Gitea (DB 2)
redis://:${REDIS_PASSWORD}@redis:6379/2

# Nextcloud (DB 3)
redis://:${REDIS_PASSWORD}@redis:6379/3

# Grafana sessions (DB 4)
redis://:${REDIS_PASSWORD}@redis:6379/4
```

### MariaDB

```bash
# Generic connection
mysql://root:${MARIADB_ROOT_PASSWORD}@mariadb:3306/

# For Nextcloud (if using MariaDB instead of PostgreSQL)
mysql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@mariadb:3306/nextcloud
```

## Using in Other Stacks

### Example: Gitea Stack

```yaml
version: '3.8'

networks:
  proxy:
    external: true
  internal:
    external: true
    name: databases_internal  # Connect to databases internal network

services:
  gitea:
    image: gitea/gitea:latest
    networks:
      - proxy
      - internal
    environment:
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=postgres:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASSWORD}
      - GITEA__cache__ADAPTER=redis
      - GITEA__cache__HOST=redis://:${REDIS_PASSWORD}@redis:6379/2
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(`git.example.com`)"
      - "traefik.http.routers.gitea.entrypoints=websecure"
      - "traefik.http.routers.gitea.tls=true"
```

**Note:** The databases stack creates an `internal` network. Other stacks need to connect to it. You can either:
1. Make the internal network external: `docker network create databases_internal`
2. Or connect services directly to the databases internal network

## Backups

### Manual Backup

```bash
chmod +x scripts/backup-databases.sh
./scripts/backup-databases.sh
```

### Automated Backup (Cron)

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/stacks/databases/scripts/backup-databases.sh >> /var/log/db-backup.log 2>&1
```

### Restore PostgreSQL

```bash
# List backups
ls -lh /backups/

# Restore latest
gunzip -c /backups/databases_LATEST.tar.gz | docker exec -i postgres psql -U postgres

# Restore specific backup
gunzip -c /backups/postgres_20240101_120000.sql.gz | docker exec -i postgres psql -U postgres
```

### Restore Redis

```bash
# Stop Redis
docker compose stop redis

# Extract and copy backup
tar xzf /backups/redis_LATEST.rdb.gz -C /tmp
docker cp /tmp/dump.rdb redis:/data/dump.rdb

# Start Redis
docker compose start redis
```

## Network Architecture

```
┌─────────────────────────────────────────┐
│         proxy network (external)        │
│  ┌──────────┐      ┌───────────────┐   │
│  │ pgAdmin  │      │Redis Commander│   │
│  └──────────┘      └───────────────┘   │
└─────────────────────────────────────────┘
                    │
                    │ (admin UIs only)
                    │
┌─────────────────────────────────────────┐
│        internal network (isolated)      │
│  ┌──────────┐  ┌───────┐  ┌─────────┐ │
│  │PostgreSQL│  │ Redis │  │ MariaDB │ │
│  └──────────┘  └───────┘  └─────────┘ │
└─────────────────────────────────────────┘
                    ▲
                    │ (other stacks connect here)
                    │
         ┌──────────┴──────────┐
         │   Other Stacks      │
         │  (Gitea, Nextcloud) │
         └─────────────────────┘
```

## Health Checks

All databases have strict health checks:

```bash
# Check health status
docker compose ps

# Expected output:
# NAME             STATUS
# postgres         Up (healthy)
# redis            Up (healthy)
# mariadb          Up (healthy)
# pgadmin          Up (healthy)
# redis-commander  Up (healthy)
```

Other stacks should use `depends_on` with health conditions:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
```

## Troubleshooting

### PostgreSQL won't start

```bash
# Check logs
docker compose logs postgres

# Common issue: password not set
# Ensure POSTGRES_ROOT_PASSWORD is set in .env
```

### Cannot connect from other stack

```bash
# Verify network connectivity
docker network inspect databases_internal

# Ensure other stack is connected to the same network
docker compose -f ../other-stack/docker-compose.yml config | grep networks
```

### pgAdmin cannot connect to PostgreSQL

```bash
# In pgAdmin, use:
# Host: postgres
# Port: 5432
# Username: postgres (or service user like 'nextcloud')
# Password: (from .env)
```

### Redis authentication failed

```bash
# Test connection
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Should return: PONG
```

## Acceptance Criteria

- [x] `init-databases.sh` creates all databases and users
- [x] `init-databases.sh` is idempotent (safe to run multiple times)
- [x] pgAdmin accessible and can connect to PostgreSQL
- [x] Other stacks can connect via internal hostname
- [x] Databases not exposed to host ports (internal network only)
- [x] `backup-databases.sh` creates valid `.tar.gz` backups
- [x] README includes connection string examples

## License

MIT
