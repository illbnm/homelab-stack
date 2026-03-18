# Database Layer

Centralized database services for the HomeLab stack. All databases run on the internal `databases` network — **no ports are exposed to the host**. Management UIs (pgAdmin, Redis Commander) are accessible via Traefik.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| PostgreSQL 16 | `postgres:16-alpine` | Primary relational DB |
| Redis 7 | `redis:7-alpine` | Caching & session storage |
| MariaDB 11.5 | `mariadb:11.5.2` | MySQL-compatible DB |
| pgAdmin 4 | `dpage/pgadmin4:8.11` | PostgreSQL web admin |
| Redis Commander | `rediscommander/redis-commander` | Redis web UI |

## Network Architecture

```
Host ──✕── (no exposed ports)
           │
    ┌──────┴──────┐
    │  databases   │  ← internal bridge (all DB services)
    │   network    │
    └──────┬──────┘
           │
    ┌──────┴──────┐
    │    proxy     │  ← external (Traefik)
    │   network    │
    └──────┬──────┘
           │
       Traefik → pgadmin.${DOMAIN}
                → redis.${DOMAIN}
```

## Redis Multi-Database Allocation

Redis DB index isolation prevents key collisions between services.

| DB | Service | Purpose |
|----|---------|---------|
| 0  | Authentik | Cache & sessions |
| 1  | Outline | Cache |
| 2  | Gitea | Cache & session store |
| 3  | Grafana | Session store |
| 4  | Nextcloud | Preview cache |
| 5  | Reserved | — |

Connection example: `redis://:${REDIS_PASSWORD}@redis:6379/0`

## Connection Strings

### PostgreSQL

```
# Nextcloud
postgres://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud?sslmode=disable

# Gitea
postgres://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea?sslmode=disable

# Outline
postgres://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline?sslmode=disable

# Authentik
postgres://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik?sslmode=disable

# Grafana
postgres://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana?sslmode=disable
```

### MariaDB

```
mariadb://root:${MARIADB_ROOT_PASSWORD}@mariadb:3306/database_name
```

### Redis

```
redis://:${REDIS_PASSWORD}@redis:6379/{db_index}
```

## Initialization

On first start, Docker entrypoint scripts auto-create databases and users:

1. **PostgreSQL** (`initdb/01-init-databases.sh`) — creates databases: nextcloud, gitea, outline, authentik, grafana, vaultwarden, bookstack. Scripts are idempotent (IF NOT EXISTS).
2. **MariaDB** (`initdb-mysql/01-init-databases.sql`) — creates databases: bookstack, nextcloud_mysql.

> ⚠️ Init scripts run **only on first container creation** (empty data volume). To re-initialize, remove the volume: `docker volume rm homelab-stack_postgres-data`.

## Backup

```bash
# All databases (default) — creates .tar.gz, keeps 7 days
./scripts/backup-databases.sh

# Specific target
./scripts/backup-databases.sh --target postgres
./scripts/backup-databases.sh --target redis
./scripts/backup-databases.sh --target mariadb
```

Backups are stored in `backups/databases/`. Each full backup produces a single `database-backup_YYYYMMDD_HHMMSS.tar.gz` containing `postgres.sql`, `redis.rdb`, and `mariadb.sql`.

Set up a cron job for automated daily backups:

```bash
# Run at 02:00 daily
0 2 * * * cd /opt/homelab-stack && ./scripts/backup-databases.sh >> /var/log/homelab-backup.log 2>&1
```

## Management UIs

### pgAdmin

- **URL**: `https://pgadmin.${DOMAIN}`
- **Login**: `${PGADMIN_EMAIL}` / `${PGADMIN_PASSWORD}`
- **Add server**: hostname = `postgres`, port = 5432, username = `${POSTGRES_ROOT_USER}`, password = `${POSTGRES_ROOT_PASSWORD}`

### Redis Commander

- **URL**: `https://redis.${DOMAIN}`
- **Auto-connects** to Redis with the configured password
- Select DB index from the dropdown (0–5)

## Configuration

All secrets are defined in `.env`. See `stacks/databases/.env.example` or the root `.env.example` for the `DATABASES` section.
