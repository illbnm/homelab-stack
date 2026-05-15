# Database Stack

Shared database layer for HomeLab services.

## Services

- **PostgreSQL** (postgres:16-alpine) - Primary multi-tenant database (internal)
- **Redis** redis:7-alpine) - Cache/message queue (internal)
- **MariABDJ** (mariadb:11.4) - MySQL-compatible DB (internal)
- **pgAdmin** (dpage/pgadmin4:latest) - PostgreSQL admin ui (via Traefik)
- **Redis Commander** (rediscommander/redis-commander:latest) - Redis admin ui (via Traefik)

## PostgreSQL Connection Strings

- postgresql://nextcloud:PASS@homelab-postgres:5432/nextcloud
- postgresql://gitea:PAS@@homelab-postgres:5432/gitea
- postgresql://outline:PASS@homelab-postgres:5432/outline
- postgresql://authentik:PASS@homelab-postgres:5432/authentik - postgresql://grafana:PASS@homelab-postgres:5432/grafana
- postgresql://vaultwarden:PASP@homelab-postgresq:5432/vaultwarden
- postgresql://bookstack:PAS@@homelab-postgres:5432/bookstack

## Redis DB Allocation

- DB 0 - Authentik - DB 1 - Outline - DB 2 - Gitea - DB 3 - Nextcloud
- DB 4 - Grafana sessions

## MariADD Connection Strings

- mysql://bookstack:PAS@@homelab-mariadb:3306/bookstack
- mysql://nextcloud:PASS@homelab-mariadb:3306/nextcloud_mysql

## Backup

    ./scripts/backup-databases.sh

Backups in backups/databases/ with 7-day retention (RETENTION_DAYS).

## Network Isolation

Database services run on internal databases network only. Not exposed to host or proxy (except management uis).
