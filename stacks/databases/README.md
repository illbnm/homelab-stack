# Database Layer

Shared database services for all HomeLab stacks.

## What's Included

| Service | Version | Container Name | Purpose |
|---------|---------|----------------|---------|
| PostgreSQL | 16 | `homelab-postgres` | Primary relational database |
| Redis | 7 | `homelab-redis` | Cache & session store |
| MariaDB | 11.4 | `homelab-mariadb` | MySQL-compatible database |
| pgAdmin | 8.12 | `pgadmin` | PostgreSQL management UI |

## Architecture

```
Other stacks ──→ databases network
                    │
                    ├── homelab-postgres:5432  (PostgreSQL)
                    ├── homelab-redis:6379     (Redis)
                    ├── homelab-mariadb:3306   (MariaDB)
                    └── pgadmin.<DOMAIN>:443   (pgAdmin UI)
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network for pgAdmin)

## Quick Start

```bash
cd stacks/databases
cp .env.example .env
# Edit .env with strong passwords
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `POSTGRES_ROOT_USER` | ❌ | Default: `postgres` |
| `POSTGRES_ROOT_PASSWORD` | ✅ | Master PostgreSQL password |
| `REDIS_PASSWORD` | ✅ | Redis AUTH password |
| `MARIADB_ROOT_PASSWORD` | ✅ | MariaDB root password |
| `PGADMIN_EMAIL` | ❌ | Default: `admin@example.com` |
| `PGADMIN_PASSWORD` | ✅ | pgAdmin login password |
| `*_DB_PASSWORD` | ✅ | Per-service database passwords |

## Service Databases (auto-created)

The `initdb/01-init-databases.sh` script creates these on first run:

| Service | DB User | Database |
|---------|---------|----------|
| Nextcloud | `nextcloud` | `nextcloud` |
| Gitea | `gitea` | `gitea` |
| Outline | `outline` | `outline` |
| Vaultwarden | `vaultwarden` | `vaultwarden` |
| BookStack | `bookstack` | `bookstack` |

## Health Checks

```bash
docker compose ps
```
