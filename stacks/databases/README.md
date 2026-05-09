# Databases Stack — Shared PostgreSQL + Redis + MariaDB

Multi-tenant database layer for all HomeLab services. One PostgreSQL instance with per-service databases instead of per-service containers.

## Services

| Service | Image | Port | Access |
|---------|-------|------|--------|
| PostgreSQL | `postgres:16.4-alpine` | 5432 (internal) | internal network only |
| Redis | `redis:7.4.0-alpine` | 6379 (internal) | internal network only |
| MariaDB | `mariadb:11.5.2` | 3306 (internal) | internal network only |
| pgAdmin | `dpage/pgadmin4:8.11` | 80 | via Traefik + Authentik |
| Redis Commander | `rediscommander/redis-commander` | 8081 | via Traefik + Authentik |

## Redis DB Allocation

| DB | Service |
|----|---------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana sessions |

## Quick Start

```bash
cd stacks/databases
cp .env.example .env && nano .env
docker compose up -d
../../scripts/init-databases.sh
```

## Service Connection Strings

### PostgreSQL

```
# In service docker-compose environment:
POSTGRES_HOST=homelab-postgres
POSTGRES_PORT=5432
POSTGRES_USER=<service_user>
POSTGRES_PASSWORD=<service_password>
POSTGRES_DB=<service_db>

# Connection string:
postgresql://<user>:<pass>@homelab-postgres:5432/<db>
```

### Redis

```
# In service config:
REDIS_URL=redis://:<password>@homelab-redis:6379/<db_number>

# For Authentik:
AUTHENTIK_REDIS__HOST=homelab-redis
REDIS_URL=redis://:<password>@homelab-redis:6379/0
```

### MariaDB

```
mysql://root:<password>@homelab-mariadb:3306/<db>
```

## Network Design

Database containers are on the `databases` internal network — NOT exposed through Traefik (except pgAdmin/Redis Commander which require Authentik SSO).

```yaml
# Other services connect via:
networks:
  - databases  # internal DB access
  - proxy      # external access via Traefik
```

## Health Checks

All containers have strict health checks. Dependent services should use:

```yaml
depends_on:
  homelab-postgres:
    condition: service_healthy
```

## Backup

```bash
./scripts/backup-databases.sh
```

Backs up all PostgreSQL databases (`pg_dumpall`), Redis RDB, and MariaDB dumps to `./backups/databases/`.
