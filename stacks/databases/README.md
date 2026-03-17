# 🗄️ Database Layer — Shared Instance Stack

> PostgreSQL + Redis + MariaDB shared database layer for all HomeLab services.

## Overview

This stack provides a centralized database layer to avoid each service running its own database instance. All services share the same PostgreSQL, Redis, and MariaDB instances with proper isolation through separate databases and users.

| Service | Image | Purpose | Port (internal) |
|---------|-------|---------|-----------------|
| PostgreSQL | `postgres:16.4-alpine` | Primary relational database (multi-tenant) | 5432 |
| Redis | `redis:7.4.0-alpine` | Cache / session store / queue | 6379 |
| MariaDB | `mariadb:11.5.2` | MySQL-compatible database (Nextcloud optional) | 3306 |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL management UI | 80 (via Traefik) |
| Redis Commander | `rediscommander/redis-commander:latest-sha` | Redis management UI | 8081 (via Traefik) |

## Quick Start

```bash
# 1. Create required Docker networks (if not already created)
docker network create internal 2>/dev/null || true
docker network create proxy 2>/dev/null || true

# 2. Copy and configure environment variables
cp stacks/databases/.env.example .env
# Edit .env with your passwords

# 3. Start the databases stack
docker compose -f stacks/databases/docker-compose.yml --env-file .env up -d

# 4. Verify all services are healthy
docker compose -f stacks/databases/docker-compose.yml ps
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    "proxy" network                           │
│    ┌──────────┐    ┌──────────────────┐                     │
│    │ pgAdmin  │    │ Redis Commander  │                     │
│    └─────┬────┘    └────────┬─────────┘                     │
└──────────┼──────────────────┼───────────────────────────────┘
           │                  │
┌──────────┼──────────────────┼───────────────────────────────┐
│          │     "internal" network                            │
│    ┌─────┴────┐    ┌───────┴──┐    ┌─────────┐              │
│    │PostgreSQL│    │  Redis   │    │ MariaDB │              │
│    │  :5432   │    │  :6379   │    │  :3306  │              │
│    └──────────┘    └──────────┘    └─────────┘              │
│         │               │               │                    │
│    ┌────┴────┐    ┌─────┴─────┐   ┌─────┴─────┐            │
│    │nextcloud│    │DB 0: Auth │   │ nextcloud │            │
│    │gitea    │    │DB 1: Outl.│   └───────────┘            │
│    │outline  │    │DB 2: Gitea│                              │
│    │authentik│    │DB 3: Next.│                              │
│    │grafana  │    │DB 4: Graf.│                              │
│    └─────────┘    └───────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

> **Network Isolation**: Database services are only on the `internal` network. They are **not** exposed to the host or to Traefik. Only management UIs (pgAdmin, Redis Commander) join the `proxy` network for web access.

## Connection Strings

### PostgreSQL

Each service gets its own database and user. Use these connection strings in your service configuration:

| Service | Connection String |
|---------|-------------------|
| Nextcloud | `postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud` |
| Gitea | `postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea` |
| Outline | `postgresql://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline` |
| Authentik | `postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik` |
| Grafana | `postgresql://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana` |

**Docker Compose example** (in another stack's compose file):

```yaml
services:
  gitea:
    environment:
      GITEA__database__DB_TYPE: postgres
      GITEA__database__HOST: postgres:5432
      GITEA__database__NAME: gitea
      GITEA__database__USER: gitea
      GITEA__database__PASSWD: ${GITEA_DB_PASSWORD}
    networks:
      - internal
    depends_on:
      postgres:
        condition: service_healthy
```

### Redis

Redis uses database numbers (`?db=N`) for service isolation:

| DB | Service | Connection String |
|----|---------|-------------------|
| 0 | Authentik | `redis://:${REDIS_PASSWORD}@redis:6379/0` |
| 1 | Outline | `redis://:${REDIS_PASSWORD}@redis:6379/1` |
| 2 | Gitea | `redis://:${REDIS_PASSWORD}@redis:6379/2` |
| 3 | Nextcloud | `redis://:${REDIS_PASSWORD}@redis:6379/3` |
| 4 | Grafana sessions | `redis://:${REDIS_PASSWORD}@redis:6379/4` |

**Docker Compose example**:

```yaml
services:
  authentik:
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_REDIS__PORT: 6379
      AUTHENTIK_REDIS__PASSWORD: ${REDIS_PASSWORD}
      AUTHENTIK_REDIS__DB: 0
    networks:
      - internal
```

### MariaDB

For services that require MySQL compatibility (e.g., Nextcloud):

| Service | Connection String |
|---------|-------------------|
| Nextcloud | `mysql://nextcloud:${NEXTCLOUD_MARIADB_PASSWORD}@mariadb:3306/nextcloud` |

**Docker Compose example**:

```yaml
services:
  nextcloud:
    environment:
      MYSQL_HOST: mariadb
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: ${NEXTCLOUD_MARIADB_PASSWORD}
    networks:
      - internal
```

## Management UIs

### pgAdmin

- **URL**: `https://pgadmin.${DOMAIN}`
- **Login**: Use `PGADMIN_EMAIL` and `PGADMIN_PASSWORD` from `.env`
- The HomeLab PostgreSQL server is pre-configured — just enter the `POSTGRES_ROOT_PASSWORD` when prompted.

### Redis Commander

- **URL**: `https://redis.${DOMAIN}`
- **Login**: Uses `REDIS_COMMANDER_USER` / `REDIS_COMMANDER_PASSWORD` from `.env`

## Multi-Tenant Initialization

The `scripts/init-databases.sh` script runs automatically on first PostgreSQL start via Docker's `docker-entrypoint-initdb.d` mechanism. It creates:

- **5 PostgreSQL databases**: `nextcloud`, `gitea`, `outline`, `authentik`, `grafana`
- **5 PostgreSQL users**: One per database with the same name
- Each user has full privileges only on their own database

The script is **idempotent** — running it again will not destroy data or throw errors. It will update passwords if they have changed.

### Manual Re-initialization

If you need to re-run the init script after the first boot:

```bash
docker exec -i homelab-postgres bash /docker-entrypoint-initdb.d/10-init-databases.sh
```

## Backup & Restore

### Creating Backups

```bash
# Run the backup script
./stacks/databases/scripts/backup-databases.sh
```

The script will:
1. Run `pg_dumpall` for all PostgreSQL databases
2. Run `mysqldump --all-databases` for MariaDB
3. Trigger `redis-cli BGSAVE` and copy the dump file
4. Compress everything into a timestamped `.tar.gz`
5. Remove backups older than `BACKUP_RETENTION_DAYS` (default: 7)
6. Optionally upload to MinIO if configured

### Automated Backups (Cron)

Add to your crontab for daily backups at 2 AM:

```bash
# Edit crontab
crontab -e

# Add this line
0 2 * * * /path/to/homelab-stack/stacks/databases/scripts/backup-databases.sh >> /var/log/homelab-backup.log 2>&1
```

### Restoring from Backup

```bash
# Extract the backup
tar -xzf databases_backup_YYYYMMDD_HHMMSS.tar.gz -C /tmp/restore/

# Restore PostgreSQL
docker exec -i homelab-postgres psql -U postgres < /tmp/restore/postgresql_all.sql

# Restore MariaDB
docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" < /tmp/restore/mariadb_all.sql

# Restore Redis (stop Redis first, replace dump, restart)
docker stop homelab-redis
docker cp /tmp/restore/redis_dump.rdb homelab-redis:/data/dump.rdb
docker start homelab-redis
```

## Health Checks

All services have strict health checks configured. Other stacks should use `depends_on` with `condition: service_healthy`:

```yaml
# In your service's docker-compose.yml
services:
  your-app:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

### Checking Health Status

```bash
# Check all services
docker compose -f stacks/databases/docker-compose.yml ps

# Expected output: all services should show "healthy"
# NAME                STATUS
# homelab-postgres    Up (healthy)
# homelab-redis       Up (healthy)
# homelab-mariadb     Up (healthy)
# homelab-pgadmin     Up (healthy)
# homelab-redis-commander  Up (healthy)
```

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | `localhost` | Domain for Traefik routing |
| `POSTGRES_ROOT_PASSWORD` | Yes | — | PostgreSQL superuser password |
| `REDIS_PASSWORD` | Yes | — | Redis AUTH password |
| `MARIADB_ROOT_PASSWORD` | Yes | — | MariaDB root password |
| `PGADMIN_EMAIL` | Yes | — | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | — | pgAdmin login password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | — | Nextcloud PostgreSQL password |
| `GITEA_DB_PASSWORD` | Yes | — | Gitea PostgreSQL password |
| `OUTLINE_DB_PASSWORD` | Yes | — | Outline PostgreSQL password |
| `AUTHENTIK_DB_PASSWORD` | Yes | — | Authentik PostgreSQL password |
| `GRAFANA_DB_PASSWORD` | Yes | — | Grafana PostgreSQL password |
| `NEXTCLOUD_MARIADB_PASSWORD` | Yes | — | Nextcloud MariaDB password |
| `REDIS_COMMANDER_USER` | No | `admin` | Redis Commander HTTP auth user |
| `REDIS_COMMANDER_PASSWORD` | No | `REDIS_PASSWORD` | Redis Commander HTTP auth password |
| `BACKUP_RETENTION_DAYS` | No | `7` | Days to keep old backups |
| `BACKUP_DIR` | No | `/opt/homelab/backups/databases` | Backup output directory |

## Troubleshooting

### PostgreSQL won't start

```bash
# Check logs
docker logs homelab-postgres

# Common fix: reset data volume
docker volume rm homelab_postgres_data
docker compose -f stacks/databases/docker-compose.yml up -d postgres
```

### Redis connection refused

```bash
# Verify Redis is healthy
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
# Should return: PONG
```

### MariaDB "Access denied"

```bash
# Check MariaDB logs
docker logs homelab-mariadb

# Verify connection
docker exec -it homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW DATABASES;"
```

### pgAdmin can't connect to PostgreSQL

1. Ensure both containers are on the `internal` network
2. In pgAdmin, use hostname `postgres` (not `localhost`)
3. Enter the `POSTGRES_ROOT_PASSWORD` when prompted

### Services can't reach databases

Ensure your service's compose file includes:

```yaml
networks:
  - internal

# And the network is defined as external:
networks:
  internal:
    external: true
    name: internal
```

## File Structure

```
stacks/databases/
├── docker-compose.yml          # Main compose file
├── .env.example                # Environment variable template
├── README.md                   # This file
├── config/
│   └── pgadmin/
│       └── servers.json        # Pre-configured pgAdmin server list
└── scripts/
    ├── init-databases.sh       # PostgreSQL multi-tenant init (idempotent)
    ├── init-mariadb.sh         # MariaDB multi-tenant init (idempotent)
    └── backup-databases.sh     # Backup all databases
```
