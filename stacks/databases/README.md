# Database Layer

Shared multi-tenant database services for the homelab stack.

## Services

| Service | Version | Access | Purpose |
|---------|---------|--------|---------|
| PostgreSQL | 16.4-alpine | internal only | Primary database (multi-tenant) |
| Redis | 7.4.0-alpine | internal only | Cache / task queue |
| MariaDB | 11.5.2 | internal only | MySQL-compat (Nextcloud) |
| pgAdmin | 8.11 | pgadmin.yourdomain.com | DB management UI |

## Redis DB Allocation

| DB | Service |
|----|---------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana sessions |

## Setup

```bash
cp .env.example .env && nano .env

docker compose up -d

# Verify all healthy
docker compose ps
```

## Connection Strings (for other stacks)

```
PostgreSQL: postgresql://nextcloud:PASSWORD@postgres:5432/nextcloud
Redis:      redis://:REDIS_PASSWORD@redis:6379/0
MariaDB:    mysql://nextcloud:PASSWORD@mariadb:3306/nextcloud
```

## Backup

```bash
bash scripts/backup-databases.sh
# Archives saved to /backups/databases/
```

## Requires

- Base stack (proxy network for pgAdmin)
- Other stacks connect via `internal` network
