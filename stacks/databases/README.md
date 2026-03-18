# Databases Stack

Shared database layer for HomeLab services.

## Services

- PostgreSQL `postgres:16.4-alpine`
- Redis `redis:7.4.0-alpine`
- MariaDB `mariadb:11.5.2`
- pgAdmin `dpage/pgadmin4:8.11` (management UI)
- Redis Commander `rediscommander/redis-commander:0.8.0` (management UI)

## Start

```bash
./scripts/stack-manager.sh up databases
```

## Idempotent database bootstrap

```bash
./scripts/init-databases.sh
# safe to re-run
./scripts/init-databases.sh
```

This ensures tenant DB+users exist for:
- `nextcloud`
- `gitea`
- `outline`
- `authentik`
- `grafana`

## Redis DB allocation

- DB 0 — Authentik
- DB 1 — Outline
- DB 2 — Gitea
- DB 3 — Nextcloud
- DB 4 — Grafana sessions

## Connection string examples

### PostgreSQL

```text
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud
postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea
postgresql://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline
postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik
postgresql://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana
```

### Redis

```text
redis://:${REDIS_PASSWORD}@redis:6379/0  # Authentik
redis://:${REDIS_PASSWORD}@redis:6379/1  # Outline
redis://:${REDIS_PASSWORD}@redis:6379/2  # Gitea
redis://:${REDIS_PASSWORD}@redis:6379/3  # Nextcloud
redis://:${REDIS_PASSWORD}@redis:6379/4  # Grafana sessions
```

### MariaDB

```text
mysql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@mariadb:3306/nextcloud
```

## Backup

```bash
./scripts/backup-databases.sh
```

Behavior:
- Runs `pg_dumpall`
- Triggers Redis `BGSAVE` and captures `dump.rdb`
- Dumps all MariaDB databases
- Packs to `backups/databases/databases_<timestamp>.tar.gz`
- Keeps last 7 days (configurable by `BACKUP_RETENTION_DAYS`)
- Optional MinIO upload with `MINIO_UPLOAD_ENABLED=true`

## Network isolation

- Core DB containers (`postgres`, `redis`, `mariadb`) are attached to `internal` only.
- They are **not** exposed via Traefik.
- Management UIs (`pgadmin`, `redis-commander`) are attached to both `internal` + `proxy`.
