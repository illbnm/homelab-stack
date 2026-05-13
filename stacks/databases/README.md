# Database Stack

Shared database layer for all HomeLab services.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| PostgreSQL 16 | internal:5432 | Primary database (multi-tenant) |
| Redis 7 | internal:6379 | Cache/queue |
| MariaDB 11 | internal:3306 | MySQL-compatible (optional) |
| pgAdmin | `https://pgadmin.${DOMAIN}` | PostgreSQL management UI |
| Redis Commander | `https://redis.${DOMAIN}` | Redis management UI |

## Quick Start

```bash
cd stacks/databases
docker compose up -d
```

## Connection Strings

| Service | PostgreSQL Connection |
|---------|----------------------|
| Nextcloud | `postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud` |
| Gitea | `postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea` |
| Outline | `postgresql://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline` |
| Authentik | `postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik` |
| Grafana | `postgresql://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana` |

## Redis Database Allocation

| DB | Service |
|----|---------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana sessions |

Connection: `redis://:${REDIS_PASSWORD}@redis:6379/<db_number>`

## Network Isolation

Databases are on the `internal` network only. They are NOT exposed via Traefik.
Only management UIs (pgAdmin, Redis Commander) are on both `internal` and `proxy` networks.

## Backup

```bash
./scripts/backup-databases.sh
```

Produces `databases_YYYYMMDD_HHMMSS.tar.gz` with 7-day retention.
