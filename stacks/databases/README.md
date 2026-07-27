# 🗄️ Databases Stack (PostgreSQL + Redis + MariaDB + pgAdmin + Redis Commander)

This stack provides shared, multi-tenant database infrastructure for all Homelab services (Nextcloud, Gitea, Outline, Authentik, Grafana).

---

## 📦 Services Included

- **PostgreSQL (`16.4-alpine`)**: Primary relational database with healthcheck.
- **Redis (`7.4.0-alpine`)**: Shared cache and session queue.
- **MariaDB (`11.5.2`)**: MySQL-compatible secondary database.
- **pgAdmin 4 (`8.11`)**: Web management UI for PostgreSQL (`pgadmin.${DOMAIN}`).
- **Redis Commander (`v0.8.0`)**: Web management UI for Redis (`redis.${DOMAIN}`).

---

## ⚙️ Redis Database Allocation Table

- **DB 0**: Authentik
- **DB 1**: Outline
- **DB 2**: Gitea
- **DB 3**: Nextcloud
- **DB 4**: Grafana Sessions

---

## 🚀 Initialization & Backups

### 1. Initialize Multi-Tenant Databases & Users

```bash
# Creates PostgreSQL users and databases for all services idempotently
./scripts/init-databases.sh
```

### 2. Run Database Backups & Cleanup

```bash
# Performs pg_dumpall + Redis BGSAVE, archives to .tar.gz, and purges archives > 7 days
./scripts/backup-databases.sh /data/backups/databases
```

---

## 🔌 Connection String Examples

- **PostgreSQL**: `postgres://<service_user>:<password>@homelab-postgres:5432/<service_db>`
- **Redis**: `redis://:<REDIS_PASSWORD>@homelab-redis:6379/<db_number>`
