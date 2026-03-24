# Databases Stack — Shared PostgreSQL + Redis + MariaDB

**Bounty**: [#11](https://github.com/illbnm/homelab-stack/issues/11) · **$130 USDT**

Shared database layer for all homelab services. Runs PostgreSQL 16, Redis 7, MariaDB 11.4, pgAdmin 8, and Redis Commander.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Internal Network (databases)                        │
│                                                      │
│  ┌──────────┐  ┌───────┐  ┌─────────┐               │
│  │PostgreSQL│  │ Redis │  │ MariaDB │               │
│  └────┬─────┘  └──┬────┘  └────┬────┘               │
│       │            │            │                    │
│  ┌────┴────────────┴────────────┴────┐              │
│  │  pgAdmin :8080  │  Redis Cmd:8081 │              │
│  └───────────────────────────────────┘              │
└─────────────────────────────────────────────────────┘
         ↕ proxy network (Traefik SSL)
    pgadmin.${DOMAIN} / redis.${DOMAIN}
```

## Quick Start

```bash
cd stacks/databases
cp ../../.env.example .env
# Edit .env — set all _PASSWORD variables
docker compose up -d
```

## Services

| Service | Internal Port | Admin URL | Purpose |
|---------|--------------|-----------|---------|
| PostgreSQL | 5432 | https://pgadmin.${DOMAIN} | Primary relational DB |
| Redis | 6379 | https://redis.${DOMAIN} | Cache + sessions |
| MariaDB | 3306 | — | MySQL-compatible DB |
| pgAdmin | 80 | https://pgadmin.${DOMAIN} | PostgreSQL web UI |
| Redis Commander | 8081 | https://redis.${DOMAIN} | Redis web UI |

## Connection Strings

### PostgreSQL

```bash
# Connect to specific database
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@homelab-postgres:5432/nextcloud
postgresql://gitea:${GITEA_DB_PASSWORD}@homelab-postgres:5432/gitea
postgresql://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline
postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@homelab-postgres:5432/authentik
postgresql://grafana:${GRAFANA_DB_PASSWORD}@homelab-postgres:5432/grafana
postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@homelab-postgres:5432/vaultwarden
postgresql://bookstack:${BOOKSTACK_DB_PASSWORD}@homelab-postgres:5432/bookstack
```

### Redis (Multi-Database Allocation)

```bash
# Connect with database selector (?db=N)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/0   # Authentik
redis://:${REDIS_PASSWORD}@homelab-redis:6379/1   # Outline
redis://:${REDIS_PASSWORD}@homelab-redis:6379/2   # Gitea
redis://:${REDIS_PASSWORD}@homelab-redis:6379/3   # Nextcloud
redis://:${REDIS_PASSWORD}@homelab-redis:6379/4   # Grafana sessions
```

### MariaDB

```bash
mariadb://root:${MARIADB_ROOT_PASSWORD}@homelab-mariadb:3306/
```

## Database Initialization

Run on first deploy (automatic via `initdb/`), or manually:

```bash
./scripts/init-databases.sh [--postgres|--redis|--all]
```

The script is **idempotent** — safe to re-run.

## Backup

```bash
# Full backup (PostgreSQL + Redis + MariaDB)
./scripts/backup-databases.sh --all

# Individual backups
./scripts/backup-databases.sh --postgres
./scripts/backup-databases.sh --redis
./scripts/backup-databases.sh --mariadb

# Backups saved to backups/databases/
```

## Environment Variables

```bash
# .env
POSTGRES_PASSWORD=         # Master PostgreSQL password
REDIS_PASSWORD=            # Redis auth password
MARIADB_ROOT_PASSWORD=     # MariaDB root password
PGADMIN_EMAIL=             # pgAdmin login email
PGADMIN_PASSWORD=          # pgAdmin login password

# Per-service credentials
NEXTCLOUD_DB_PASSWORD=
GITEA_DB_PASSWORD=
OUTLINE_DB_PASSWORD=
AUTHENTIK_DB_PASSWORD=
GRAFANA_DB_PASSWORD=
VAULTWARDEN_DB_PASSWORD=
BOOKSTACK_DB_PASSWORD=
```

## Network Isolation

- Databases (`postgres`, `redis`, `mariadb`): **internal only** (`databases` network)
- pgAdmin, Redis Commander: `databases` + `proxy` networks → accessible via Traefik subdomain
- Database ports are **NOT exposed** to the host or public internet

## Health Checks

All services have health checks. Other stacks should depend on:

```yaml
services:
  my-service:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

## USDT Wallet

`edisonlv` (same as previous RustChain payments)
