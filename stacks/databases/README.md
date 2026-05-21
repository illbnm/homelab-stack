# Database Stack

Shared database layer for HomeLab Stack. Provides PostgreSQL, Redis, and MariaDB instances used by multiple stacks, plus web-based admin tools.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| PostgreSQL | 16-alpine | Internal only | Shared relational database (Gitea, Outline, Vaultwarden, etc.) |
| Redis | 7-alpine | Internal only | Cache & session store (Outline, SSO, etc.) |
| MariaDB | 11.4 | Internal only | MySQL-compatible database (Nextcloud, BookStack) |
| pgAdmin 4 | 8.11 | `pgadmin.<DOMAIN>` | PostgreSQL web management UI |
| Redis Commander | latest | `redis.<DOMAIN>` | Redis web management UI |

## Architecture

```
Other Stacks (Gitea, Nextcloud, Outline...)
    │
    │ connect via 'databases' network
    ▼
┌─────────────────────────────────────────┐
│  [databases] internal Docker network     │
│                                          │
│  PostgreSQL:5432  ──► pgadmin.<DOMAIN>   │
│  Redis:6379      ──► redis.<DOMAIN>      │
│  MariaDB:3306                           │
└─────────────────────────────────────────┘
         │
    [proxy] ← Traefik reverse proxy
```

Database services are **not exposed to the internet** — only admin tools are accessible via Traefik with SSO protection.

## Quick Start

```bash
# From repo root
cp .env.example .env
# Edit .env — set all database passwords

# Start base stack first
cd stacks/base && docker compose up -d

# Start databases
cd ../databases
ln -sf ../../.env .env
docker compose up -d

# Verify all services are healthy
docker compose ps
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_ROOT_USER` | No | `postgres` | PostgreSQL superuser |
| `POSTGRES_ROOT_PASSWORD` | Yes | — | PostgreSQL superuser password |
| `REDIS_PASSWORD` | Yes | — | Redis authentication password |
| `MARIADB_ROOT_PASSWORD` | Yes | — | MariaDB root password |
| `PGADMIN_EMAIL` | No | `admin@homelab.local` | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | — | pgAdmin login password |
| `DOMAIN` | Yes | — | Base domain for admin tools |
| `TZ` | No | `Asia/Shanghai` | Timezone |

### Per-Service Database Passwords

The init scripts (`initdb/01-init-databases.sh`) create individual databases and users for each service. Set these in `.env`:

| Variable | Database | Used By |
|----------|----------|---------|
| `NEXTCLOUD_DB_PASSWORD` | `nextcloud` | Nextcloud |
| `GITEA_DB_PASSWORD` | `gitea` | Gitea |
| `OUTLINE_DB_PASSWORD` | `outline` | Outline wiki |
| `VAULTWARDEN_DB_PASSWORD` | `vaultwarden` | Vaultwarden (optional, can use SQLite) |
| `BOOKSTACK_DB_PASSWORD` | `bookstack` | BookStack |

### Connect from Other Stacks

Other stacks connect to databases via the `databases` network. Example for a service needing PostgreSQL:

```yaml
services:
  myapp:
    environment:
      DATABASE_URL: postgres://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea
    networks:
      - databases
      - proxy

networks:
  databases:
    external: true
  proxy:
    external: true
```

## Admin Tools

### pgAdmin (PostgreSQL UI)

1. Visit `https://pgadmin.<DOMAIN>`
2. Login with `PGADMIN_EMAIL` / `PGADMIN_PASSWORD`
3. Add server: Host=`postgres`, Port=`5432`, User=`postgres`, Password=`POSTGRES_ROOT_PASSWORD`

### Redis Commander

1. Visit `https://redis.<DOMAIN>`
2. Pre-configured to connect to Redis with password from `.env`

## Database Maintenance

### Backup

```bash
# PostgreSQL — all databases
docker exec homelab-postgres pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# Single database
docker exec homelab-postgres pg_dump -U postgres gitea > gitea_backup.sql

# MariaDB
docker exec homelab-mariadb mariadb-dump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > mysql_backup.sql

# Redis
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
docker cp homelab-redis:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb
```

### Restore

```bash
# PostgreSQL
cat backup.sql | docker exec -i homelab-postgres psql -U postgres

# MariaDB
cat mysql_backup.sql | docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}"
```

### Resize Redis Memory

Edit `.env` or modify the command in `docker-compose.yml`:

```yaml
command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
```

## SSO Integration

pgAdmin and Redis Commander are protected by Authentik ForwardAuth via Traefik middleware. To enable:

1. Deploy the SSO stack (`stacks/sso/`)
2. The `authentik-forwardauth@docker` middleware is applied via labels

## CN Network Adaptation

All images are on Docker Hub (no ghcr.io dependency). If `CN_MODE=true`:

```bash
./scripts/cn-pull.sh  # Pull through CN mirrors
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| PostgreSQL won't start | Check `postgres-data` volume permissions; remove and retry |
| Redis `NOAUTH` error | Verify `REDIS_PASSWORD` matches across all stacks |
| MariaDB init fails | Check `initdb-mysql/` scripts for syntax errors |
| pgAdmin can't connect | Ensure pgAdmin is on `databases` network; host=`postgres` (not localhost) |
| Slow first start | Init scripts run on first launch only; subsequent starts are fast |
| Connection refused from other stack | Add `databases` external network to the other stack's compose file |
