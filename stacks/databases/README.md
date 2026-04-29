# Databases Stack

Shared database layer for all HomeLab services. **Deploy before any other stack** that needs a database.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| PostgreSQL | 16 | *(internal)* | Multi-tenant primary database |
| Redis | 7 | *(internal)* | Cache / queue / session store |
| MariaDB | 11.4 | *(internal)* | MySQL-compatible database |
| pgAdmin | 8.11 | `pgadmin.<DOMAIN>` | PostgreSQL management UI |
| Redis Commander | latest | `redis-cmd.<DOMAIN>` | Redis management UI |

## Architecture

```
[databases network] ← internal network — all stacks connect here
    │
    ├── homelab-postgres:5432  ← PostgreSQL (multi-tenant)
    │   ├── nextcloud (db)
    │   ├── gitea (db)
    │   ├── outline (db + uuid-ossp)
    │   ├── vaultwarden (db)
    │   ├── authentik (db)
    │   └── grafana (db)
    │
    ├── homelab-redis:6379  ← Redis (multi-database isolation)
    │   ├── db0 — Authentik
    │   ├── db1 — Outline
    │   ├── db2 — Gitea
    │   ├── db3 — Nextcloud
    │   └── db4 — Grafana
    │
    ├── homelab-mariadb:3306  ← MariaDB
    │   ├── bookstack (db)
    │   └── nextcloud_mysql (optional fallback)
    │
    [proxy network] ← management UIs only
    ├──► pgadmin.<DOMAIN>     → pgAdmin
    └──► redis-cmd.<DOMAIN>   → Redis Commander
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- Docker Compose v2.20+

## Quick Start

```bash
cd stacks/databases
cp .env.example .env
vim .env  # Fill in ALL passwords

# Symlink shared .env (or use local)
# ln -sf ../../.env .env

docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_PASSWORD` | ✅ | PostgreSQL superuser password |
| `REDIS_PASSWORD` | ✅ | Redis authentication password |
| `MARIADB_ROOT_PASSWORD` | ✅ | MariaDB root password |
| `NEXTCLOUD_DB_PASSWORD` | ✅ | Password for Nextcloud PostgreSQL user |
| `GITEA_DB_PASSWORD` | ✅ | Password for Gitea PostgreSQL user |
| `OUTLINE_DB_PASSWORD` | ✅ | Password for Outline PostgreSQL user |
| `VAULTWARDEN_DB_PASSWORD` | ✅ | Password for Vaultwarden PostgreSQL user |
| `AUTHENTIK_DB_PASSWORD` | ✅ | Password for Authentik PostgreSQL user |
| `GRAFANA_DB_PASSWORD` | ✅ | Password for Grafana PostgreSQL user |
| `BOOKSTACK_DB_PASSWORD` | ✅ | Password for BookStack MariaDB user |
| `PGADMIN_EMAIL` | ✅ | pgAdmin login email |
| `PGADMIN_PASSWORD` | ✅ | pgAdmin login password |

### Redis Database Allocation

| DB# | Service | Connection String |
|-----|---------|-------------------|
| 0 | Authentik | `redis://:<pwd>@homelab-redis:6379/0` |
| 1 | Outline | `redis://:<pwd>@homelab-redis:6379?db=1` |
| 2 | Gitea | `redis://:<pwd>@homelab-redis:6379/2` |
| 3 | Nextcloud | `redis://:<pwd>@homelab-redis:6379/3` |
| 4 | Grafana | `redis://:<pwd>@homelab-redis:6379/4` |

## Post-Deploy Setup

### 1. pgAdmin — Connect to PostgreSQL

1. Open `https://pgadmin.<DOMAIN>`
2. Login with `PGADMIN_EMAIL` / `PGADMIN_PASSWORD`
3. **Add New Server**:
   - Name: `HomeLab PostgreSQL`
   - Host: `homelab-postgres`
   - Port: `5432`
   - Username: `postgres`
   - Password: `POSTGRES_ROOT_PASSWORD`

### 2. Redis Commander

1. Open `https://redis-cmd.<DOMAIN>`
2. Auto-connected to `homelab-redis:6379` (password from env)
3. Browse databases 0-4

### 3. Verify Database Initialization

```bash
# Check PostgreSQL databases
docker exec homelab-postgres psql -U postgres -c '\l'

# Check Redis
docker exec homelab-redis redis-cli -a <password> INFO keyspace

# Check MariaDB databases
docker exec homelab-mariadb mariadb -u root -p<password> -e 'SHOW DATABASES;'
```

## Backup

```bash
# Manual backup
./backup-databases.sh --output ./backups --keep 7

# Backup with MinIO upload
./backup-databases.sh --output ./backups --keep 7 --minio minio/backups

# Cron (daily at 2:00 AM)
# Add to crontab: 0 2 * * * cd /path/to/stacks/databases && ./backup-databases.sh
```

### Backup Contents

| File | Contents |
|------|----------|
| `postgresql_all.sql.gz` | All PostgreSQL databases (pg_dumpall) |
| `redis_dump.rdb.gz` | Redis RDB snapshot |
| `mariadb_all.sql.gz` | All MariaDB databases (mariadb-dump) |

## Connection String Reference

For other stacks to connect:

| Service | Type | Connection |
|---------|------|------------|
| Nextcloud | PostgreSQL | `postgres://nextcloud:<pwd>@homelab-postgres:5432/nextcloud` |
| Gitea | PostgreSQL | `postgres://gitea:<pwd>@homelab-postgres:5432/gitea` |
| Outline | PostgreSQL | `postgres://outline:<pwd>@homelab-postgres:5432/outline` |
| Vaultwarden | PostgreSQL | `postgresql://vaultwarden:<pwd>@homelab-postgres:5432/vaultwarden` |
| Authentik | PostgreSQL | `postgres://authentik:<pwd>@homelab-postgres:5432/authentik` |
| Grafana | PostgreSQL | `postgres://grafana:<pwd>@homelab-postgres:5432/grafana` |
| BookStack | MariaDB | `mysql://bookstack:<pwd>@homelab-mariadb:3306/bookstack` |
| Outline | Redis | `redis://:<pwd>@homelab-redis:6379?db=1` |

## Network Isolation

- **Database containers** (PostgreSQL, Redis, MariaDB) are on `databases` network only — **NOT** exposed to the internet
- **Management UIs** (pgAdmin, Redis Commander) are on both `databases` and `proxy` networks — accessible via Traefik
- No database ports are published to the host — services connect via Docker network

## Troubleshooting

### "Connection refused" from other stacks
- Verify `databases` network exists: `docker network inspect databases`
- Ensure both stacks are on the `databases` network
- Use container hostname: `homelab-postgres`, `homelab-redis`, `homelab-mariadb`

### pgAdmin can't connect to PostgreSQL
- Use hostname `homelab-postgres` (not `localhost`)
- Port: `5432`
- Both containers must be on the `databases` network

### Init script didn't create databases
- Init scripts only run on **first** container start
- To re-run: stop container, delete `postgres-data` volume, restart
- Or run manually: `docker exec homelab-postgres psql -U postgres -f /docker-entrypoint-initdb.d/01-init-databases.sh`

### Redis: "NOAUTH Authentication required"
- Ensure `REDIS_PASSWORD` matches in all stack `.env` files
- Test: `docker exec homelab-redis redis-cli -a <password> ping`
