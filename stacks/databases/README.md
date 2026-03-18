# HomeLab Database Stack

Shared database layer for the HomeLab infrastructure. Provides PostgreSQL, Redis, and MariaDB as multi-tenant services — other stacks connect over the internal `databases` network instead of running their own database instances.

## Architecture

```
                        ┌─────────────────────────────────┐
                        │         proxy network           │
                        │   (Traefik routing — HTTPS)     │
                        └──────┬───────────────┬──────────┘
                               │               │
                         ┌─────┴─────┐   ┌─────┴──────────┐
                         │  pgAdmin  │   │ Redis Commander │
                         │  :80      │   │ :8081           │
                         └─────┬─────┘   └─────┬───────────┘
                               │               │
┌──────────────────────────────┼───────────────┼──────────────────┐
│                       databases network (internal)              │
│                              │               │                  │
│  ┌───────────────┐    ┌──────┴──────┐   ┌────┴────┐            │
│  │  PostgreSQL   │    │    Redis    │   │ MariaDB │            │
│  │  :5432        │    │    :6379    │   │ :3306   │            │
│  │  7 databases  │    │  16 DBs     │   │ 2 DBs   │            │
│  └───────────────┘    └─────────────┘   └─────────┘            │
│                                                                 │
│  Consumers: Nextcloud, Gitea, Outline, Authentik, Grafana,     │
│             Vaultwarden, BookStack                              │
└─────────────────────────────────────────────────────────────────┘
```

**Key design:** Database services live on the internal `databases` network only — they are never exposed to the internet via Traefik. Only the admin UIs (pgAdmin, Redis Commander) join the `proxy` network for HTTPS access.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | `postgres:16.4-alpine` | 5432 | Multi-tenant primary database |
| Redis | `redis:7.4.0-alpine` | 6379 | Shared cache and queue |
| MariaDB | `mariadb:11.5.2` | 3306 | MySQL-compatible (BookStack, Nextcloud alt) |
| pgAdmin | `dpage/pgadmin4:8.11` | 80 | PostgreSQL management UI |
| Redis Commander | `rediscommander/redis-commander:0.8.1` | 8081 | Redis management UI |

## Quick Start

```bash
# 1. Create the databases network (if not already created)
docker network create databases

# 2. Ensure proxy network exists (created by base stack)
docker network create proxy 2>/dev/null || true

# 3. Configure environment
cp .env.example .env
nano .env   # Set strong passwords for EVERY field

# 4. Start all services
docker compose up -d

# 5. Verify health
docker compose ps
# All containers should show "healthy" status
```

## Connection Strings

### PostgreSQL

Services connect via the internal hostname `homelab-postgres`:

```
# Generic format
postgresql://SERVICE:PASSWORD@homelab-postgres:5432/SERVICE

# Nextcloud
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@homelab-postgres:5432/nextcloud

# Gitea
postgresql://gitea:${GITEA_DB_PASSWORD}@homelab-postgres:5432/gitea

# Outline
postgresql://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline

# Authentik
postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@homelab-postgres:5432/authentik

# Grafana
postgresql://grafana:${GRAFANA_DB_PASSWORD}@homelab-postgres:5432/grafana

# Vaultwarden
postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@homelab-postgres:5432/vaultwarden

# BookStack (PostgreSQL option)
postgresql://bookstack:${BOOKSTACK_DB_PASSWORD}@homelab-postgres:5432/bookstack
```

### Redis

Redis uses numbered databases for isolation. Connect via `homelab-redis`:

```
# Generic format
redis://:${REDIS_PASSWORD}@homelab-redis:6379/DB_NUMBER

# DB Allocation:
#   DB 0 — Authentik
#   DB 1 — Outline
#   DB 2 — Gitea
#   DB 3 — Nextcloud
#   DB 4 — Grafana sessions
#   DB 5-15 — Available for future services
```

### MariaDB

Services using MySQL connect via `homelab-mariadb`:

```
# BookStack
mysql://bookstack:${BOOKSTACK_DB_PASSWORD}@homelab-mariadb:3306/bookstack

# Nextcloud (MySQL alternative — use either PostgreSQL OR MariaDB, not both)
mysql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@homelab-mariadb:3306/nextcloud
```

## Connecting from Other Stacks

In your service's `docker-compose.yml`, join the `databases` network and use `depends_on` with health checks:

```yaml
services:
  your-service:
    # ...
    networks:
      - databases
    depends_on:
      postgres:
        condition: service_healthy
    # NOTE: use the Compose service name (postgres), not the container_name
    # (homelab-postgres). For connection strings, use the container_name.

networks:
  databases:
    external: true
```

## Admin UIs

| UI | URL | Login |
|----|-----|-------|
| pgAdmin | `https://pgadmin.${DOMAIN}` | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| Redis Commander | `https://redis-ui.${DOMAIN}` | `REDIS_COMMANDER_USER` / `REDIS_COMMANDER_PASSWORD` |

pgAdmin is pre-configured with the HomeLab PostgreSQL server via `config/pgadmin-servers.json`. On first login, enter the `POSTGRES_ROOT_PASSWORD` when prompted to connect.

## Init Scripts

### PostgreSQL (`initdb/01-init-databases.sh`)

Runs automatically on first PostgreSQL container start. Creates 7 service databases:

| Database | User | Extensions |
|----------|------|------------|
| nextcloud | nextcloud | — |
| gitea | gitea | — |
| outline | outline | uuid-ossp |
| authentik | authentik | — |
| grafana | grafana | — |
| vaultwarden | vaultwarden | — |
| bookstack | bookstack | — |

**Idempotent:** Safe to run multiple times — uses `IF NOT EXISTS` guards, never drops existing data.

### MariaDB (`initdb-mysql/01-init-databases.sh`)

Shell wrapper that creates `bookstack` and `nextcloud` databases with utf8mb4 encoding via the `mariadb` client. Uses a `.sh` file (not `.sql`) so environment variables are expanded by the shell. Also idempotent.

## Backups

Run the backup script to create a compressed archive of all databases:

```bash
# Run manually
./scripts/backup-databases.sh

# Or schedule via cron (daily at 2 AM)
0 2 * * * cd /opt/homelab/stacks/databases && ./scripts/backup-databases.sh >> /var/log/homelab-backup.log 2>&1
```

The script:
- Dumps PostgreSQL via `pg_dumpall` (all databases in one SQL file)
- Triggers Redis `BGSAVE` and copies the RDB snapshot
- Dumps MariaDB via `mysqldump --all-databases`
- Compresses everything into `homelab-db-backup-YYYYMMDD-HHMMSS.tar.gz`
- Prunes backups older than 7 days (configurable via `BACKUP_RETENTION_DAYS`)

Default backup location: `/opt/homelab/backups/databases/`

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Base domain for Traefik routing |
| `POSTGRES_ROOT_USER` | No | PostgreSQL superuser (default: `postgres`) |
| `POSTGRES_ROOT_PASSWORD` | Yes | PostgreSQL superuser password |
| `REDIS_PASSWORD` | Yes | Redis authentication password |
| `MARIADB_ROOT_PASSWORD` | Yes | MariaDB root password |
| `PGADMIN_EMAIL` | Yes | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | pgAdmin login password |
| `REDIS_COMMANDER_USER` | No | Redis Commander HTTP user (default: `admin`) |
| `REDIS_COMMANDER_PASSWORD` | Yes | Redis Commander HTTP password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | Nextcloud database password |
| `GITEA_DB_PASSWORD` | Yes | Gitea database password |
| `OUTLINE_DB_PASSWORD` | Yes | Outline database password |
| `AUTHENTIK_DB_PASSWORD` | Yes | Authentik database password |
| `GRAFANA_DB_PASSWORD` | Yes | Grafana database password |
| `VAULTWARDEN_DB_PASSWORD` | Yes | Vaultwarden database password |
| `BOOKSTACK_DB_PASSWORD` | Yes | BookStack database password |

## Health Checks

All database containers have strict health checks:

| Service | Check | Interval | Retries |
|---------|-------|----------|---------|
| PostgreSQL | `pg_isready` | 10s | 5 |
| Redis | `redis-cli ping` | 10s | 5 |
| MariaDB | `healthcheck.sh --connect --innodb_initialized` | 10s | 5 |
| pgAdmin | `wget http://localhost/misc/ping` | 30s | 3 |
| Redis Commander | `wget http://localhost:8081/favicon.png` | 30s | 3 |

Other stacks should use `depends_on: condition: service_healthy` to wait for databases to be ready before starting.

## Troubleshooting

**PostgreSQL won't start:**
```bash
docker logs homelab-postgres
# Check for permission issues on the data volume
docker exec homelab-postgres ls -la /var/lib/postgresql/data/
```

**Init script didn't run:**
The init script only runs on first start (when the data directory is empty). To re-run:
```bash
docker compose down
docker volume rm databases_postgres-data  # WARNING: destroys all data
docker compose up -d
```

**Can't connect from another stack:**
1. Ensure the service joins the `databases` network
2. Use `homelab-postgres` (not `localhost`) as the hostname
3. Check that the database user/password matches what's in `.env`

**pgAdmin can't connect:**
On first login, pgAdmin will prompt for the server password. Enter `POSTGRES_ROOT_PASSWORD`.

**Redis Commander shows auth error:**
Verify `REDIS_PASSWORD` in `.env` matches what Redis was started with. If changed, restart Redis:
```bash
docker compose restart redis redis-commander
```
