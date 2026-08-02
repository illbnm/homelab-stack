# Shared Databases Stack

This stack provides shared, multi-tenant databases to conserve resources in the homelab environment. Instead of each service running its own isolated PostgreSQL or Redis container, they all share these instances securely.

## Included Services

- **PostgreSQL 16**: Primary relational database. Multi-tenant.
- **Redis 7**: Caching and task queues. Multi-tenant via logical database indexes (`?db=N`).
- **MariaDB 11.4**: Optional MySQL-compatible DB (useful for Nextcloud legacy setups).
- **pgAdmin**: Web UI for managing PostgreSQL.
- **Redis Commander**: Web UI for managing Redis.

## Configuration

1. Copy `.env.example` to `.env` and fill in secure passwords.
2. The initialization script (`initdb/01-init-databases.sh`) automatically creates databases and users. It is fully **idempotent**, meaning you can restart the stack without errors.

## Connection Strings

Other stacks in this homelab should connect to these databases using their internal hostnames (the container names on the `databases` docker network).

### PostgreSQL

* **Nextcloud**: `postgres://nextcloud:YOUR_NEXTCLOUD_PASSWORD@homelab-postgres:5432/nextcloud`
* **Gitea**: `postgres://gitea:YOUR_GITEA_PASSWORD@homelab-postgres:5432/gitea`
* **Outline**: `postgres://outline:YOUR_OUTLINE_PASSWORD@homelab-postgres:5432/outline`
* **Authentik**: `postgres://authentik:YOUR_AUTHENTIK_PASSWORD@homelab-postgres:5432/authentik`
* **Grafana**: `postgres://grafana:YOUR_GRAFANA_PASSWORD@homelab-postgres:5432/grafana`

### Redis (Logical DB isolation)

Redis separates data using numeric database indexes (0-15). By convention in this homelab:

* **DB 0 (Authentik)**: `redis://:YOUR_REDIS_PASSWORD@homelab-redis:6379/0`
* **DB 1 (Outline)**: `redis://:YOUR_REDIS_PASSWORD@homelab-redis:6379/1`
* **DB 2 (Gitea)**: `redis://:YOUR_REDIS_PASSWORD@homelab-redis:6379/2`
* **DB 3 (Nextcloud)**: `redis://:YOUR_REDIS_PASSWORD@homelab-redis:6379/3`
* **DB 4 (Grafana)**: `redis://:YOUR_REDIS_PASSWORD@homelab-redis:6379/4`

### MariaDB

* **Host**: `homelab-mariadb`
* **Port**: `3306`

## Management Interfaces

The databases themselves are **NOT exposed** to the host. They are safely enclosed within the `databases` internal network. You can access them via the management web UIs which are routed via Traefik on the `proxy` network:

- **pgAdmin**: `https://pgadmin.yourdomain.com` (Login with `PGADMIN_EMAIL` and `PGADMIN_PASSWORD`).
- **Redis Commander**: `https://redis.yourdomain.com` (Login with Redis password).

## Backups

Use the root script `scripts/backup-databases.sh` to generate compressed `.tar.gz` archives of PostgreSQL, Redis, and MariaDB. The script retains backups for 7 days.
