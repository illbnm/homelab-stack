# 🗄️ Shared Database Layer (PostgreSQL, Redis, MariaDB)

> Multi-tenant, resource-efficient shared database layer for HomeLab Stack.

## 📦 Services

| Service | Image | Internal Port | Description |
|---|---|---|---|
| **PostgreSQL** | `postgres:16.4-alpine` | 5432 | Primary multi-tenant relational DB |
| **Redis** | `redis:7.4.0-alpine` | 6379 | In-memory key-value cache & queue |
| **MariaDB** | `mariadb:11.5.2` | 3306 | MySQL-compatible storage |
| **pgAdmin** | `dpage/pgadmin4:8.11` | 80 | Web UI for PostgreSQL administration |
| **Redis Commander** | `rediscommander/redis-commander:latest-sha` | 8081 | Web UI for Redis inspection |

## 🔑 Multi-Tenant PostgreSQL Provisioning
Databases and users are provisioned idempotently via `scripts/init-databases.sh`:
- `nextcloud`
- `gitea`
- `outline`
- `authentik`
- `grafana`

## 🗃️ Redis Database Allocation Map
- **DB 0:** Authentik session store
- **DB 1:** Outline document caching
- **DB 2:** Gitea job queue
- **DB 3:** Nextcloud memory caching
- **DB 4:** Grafana sessions

## 💾 Backups
Automated via `scripts/backup-databases.sh` with 7-day retention.
