# Database Layer

Shared database services for all HomeLab stacks.

## What's Included

| Service | Version | Container Name | Purpose |
|---------|---------|----------------|---------|
| PostgreSQL | 16 | `homelab-postgres` | Primary relational database |
| Redis | 7 | `homelab-redis` | Cache & session store |
| MariaDB | 11.4 | `homelab-mariadb` | MySQL-compatible database |
| pgAdmin | 8.12 | `pgadmin` | PostgreSQL management UI |
| Redis Commander | latest | `redis-commander` | Redis management UI |

## Architecture

```
Other stacks ──→ databases network
                    │
                    ├── homelab-postgres:5432  (PostgreSQL)
                    ├── homelab-redis:6379     (Redis)
                    ├── homelab-mariadb:3306   (MariaDB)
                    ├── pgadmin.<DOMAIN>:443   (pgAdmin UI)
                    └── redis.<DOMAIN>:443     (Redis Commander UI)
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network for management UIs)

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

The `initdb/01-init-databases.sh` script creates these on first run (idempotent — safe to re-run):

| Service | DB User | Database |
|---------|---------|----------|
| Nextcloud | `nextcloud` | `nextcloud` |
| Gitea | `gitea` | `gitea` |
| Outline | `outline` | `outline` |
| Authentik | `authentik` | `authentik` |
| Grafana | `grafana` | `grafana` |
| Vaultwarden | `vaultwarden` | `vaultwarden` |
| BookStack | `bookstack` | `bookstack` |

## Connection Strings

```bash
# PostgreSQL
postgresql://nextcloud:<NEXTCLOUD_DB_PASSWORD>@homelab-postgres:5432/nextcloud
postgresql://gitea:<GITEA_DB_PASSWORD>@homelab-postgres:5432/gitea
postgresql://outline:<OUTLINE_DB_PASSWORD>@homelab-postgres:5432/outline
postgresql://authentik:<AUTHENTIK_DB_PASSWORD>@homelab-postgres:5432/authentik
postgresql://grafana:<GRAFANA_DB_PASSWORD>@homelab-postgres:5432/grafana

# Redis (per-service DB allocation)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/0  # Authentik
redis://:${REDIS_PASSWORD}@homelab-redis:6379/1  # Outline
redis://:${REDIS_PASSWORD}@homelab-redis:6379/2  # Gitea
redis://:${REDIS_PASSWORD}@homelab-redis:6379/3  # Nextcloud
redis://:${REDIS_PASSWORD}@homelab-redis:6379/4  # Grafana sessions

# MariaDB
mysql://bookstack:<BOOKSTACK_DB_PASSWORD>@homelab-mariadb:3306/bookstack
```

## Health Checks

```bash
docker compose ps
```
