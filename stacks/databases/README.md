# Databases Stack — Shared Multi-Tenant Database Layer

Centralized database layer for all HomeLab services. One PostgreSQL instance with per-service databases, shared Redis with DB number isolation, and optional MariaDB for MySQL-compatible workloads.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Database Layer                     │
│                                                             │
│  PostgreSQL (multi-tenant)    Redis (DB-isolated)   MariaDB │
│  ├── authentik                 DB 0 → Authentik              │
│  ├── gitea                     DB 1 → Outline                │
│  ├── outline                   DB 2 → Gitea                  │
│  ├── nextcloud                 DB 3 → Nextcloud              │
│  └── grafana                   DB 4 → Grafana sessions       │
│                                                             │
│  Management UIs:                                             │
│  pgAdmin (https://pgadmin.DOMAIN)                            │
│  Redis Commander (https://redis.DOMAIN)                      │
└─────────────────────────────────────────────────────────────┘
```

**Network:** All database containers are on the `databases` internal network — NOT exposed to the host. Management UIs (pgAdmin, Redis Commander) are the only services on the `proxy` network.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| postgres | `postgres:16.4-alpine` | 5432 (internal) | Primary multi-tenant database |
| redis | `redis:7.4.0-alpine` | 6379 (internal) | Cache & session store |
| mariadb | `mariadb:11.5.2` | 3306 (internal) | MySQL-compatible (optional) |
| pgadmin | `dpage/pgadmin4:8.11` | 80 (internal) | PostgreSQL management UI |
| redis-commander | `rediscommander/redis-commander:latest` | 8081 (internal) | Redis management UI |

## Quick Start

```bash
# 1. Start the database layer (must be first!)
cd stacks/databases && docker compose up -d

# 2. Wait for PostgreSQL to be healthy
docker compose ps

# 3. Initialize per-service databases
../../scripts/init-databases.sh

# 4. Verify
docker compose logs postgres | grep "ready"
```

## Database Initialization

Run `scripts/init-databases.sh` to create all per-service databases:

```bash
./scripts/init-databases.sh
```

Output:
```
[OK] Created database: authentik
[OK] Created user: authentik
[OK] Granted privileges: authentik → authentik
[OK] Created database: gitea
[SKIP] User 'gitea' already exists
...
```

The script is **idempotent** — safe to run multiple times. Existing databases and users won't be modified.

## Redis DB Number Allocation

| DB | Service | Purpose |
|----|---------|---------|
| 0 | Authentik | Session cache & task queue |
| 1 | Outline | Real-time collaboration cache |
| 2 | Gitea | Session & queue |
| 3 | Nextcloud | File locking & session |
| 4 | Grafana | Dashboard sessions |

## Service Connection Strings

Configure each service to use the shared database:

| Service | DB Type | Host | Port | Database | User |
|---------|---------|------|------|----------|------|
| Authentik | PostgreSQL | `homelab-postgres` | 5432 | `authentik` | `authentik` |
| Gitea | PostgreSQL | `homelab-postgres` | 5432 | `gitea` | `gitea` |
| Outline | PostgreSQL | `homelab-postgres` | 5432 | `outline` | `outline` |
| Nextcloud | PostgreSQL | `homelab-postgres` | 5432 | `nextcloud` | `nextcloud` |
| Grafana | PostgreSQL | `homelab-postgres` | 5432 | `grafana` | `grafana` |

Redis connection: `redis://:PASSWORD@homelab-redis:6379/DB_NUMBER`

### docker-compose snippet for any service

```yaml
services:
  myservice:
    environment:
      - DB_HOST=homelab-postgres
      - DB_PORT=5432
      - DB_NAME=myservice
      - DB_USER=myservice
      - DB_PASSWORD=${MYSERVICE_DB_PASSWORD}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@homelab-redis:6379/5
    networks:
      - databases
      - proxy

networks:
  databases:
    external: true
    name: databases
  proxy:
    external: true
    name: proxy
```

## Backups

Daily backup with 7-day retention:

```bash
# Local backup
./scripts/backup-databases.sh

# Backup + upload to MinIO
./scripts/backup-databases.sh --upload-minio
```

Backups are stored in `./backups/` as `databases-YYYYMMDD-HHMMSS.tar.gz`.

### Automate with cron

```bash
# Daily at 3 AM
0 3 * * * /path/to/scripts/backup-databases.sh --upload-minio
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_USER` | Yes | PostgreSQL superuser (default: postgres) |
| `POSTGRES_ROOT_PASSWORD` | Yes | PostgreSQL superuser password |
| `REDIS_PASSWORD` | Yes | Redis password |
| `MARIADB_ROOT_PASSWORD` | No | MariaDB root password |
| `PGADMIN_EMAIL` | Yes | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | pgAdmin login password |
| `AUTHENTIK_DB_PASSWORD` | Yes | Authentik database user password |
| `GITEA_DB_PASSWORD` | Yes | Gitea database user password |
| `OUTLINE_DB_PASSWORD` | Yes | Outline database user password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | Nextcloud database user password |
| `GRAFANA_DB_PASSWORD` | No | Grafana database user password |

## Management UIs

| UI | URL | Default Login |
|----|-----|---------------|
| pgAdmin | `https://pgadmin.${DOMAIN}` | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| Redis Commander | `https://redis.${DOMAIN}` | Auto-connected |

### pgAdmin: Add Server

1. Login → Add New Server
2. Name: `HomeLab PostgreSQL`
3. Connection tab:
   - Host: `homelab-postgres`
   - Port: `5432`
   - Username: `postgres`
   - Password: `${POSTGRES_ROOT_PASSWORD}`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `init-databases.sh` fails | Ensure `POSTGRES_ROOT_PASSWORD` is set in `.env` |
| Services can't connect | Add `networks: databases` to service compose and use `homelab-postgres` hostname |
| pgAdmin can't add server | Use internal hostname `homelab-postgres`, not localhost |
| Redis connection refused | Check `REDIS_PASSWORD` matches in both databases and service configs |