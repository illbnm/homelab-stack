# Database Stack

Shared database layer for HomeLab services. Provides PostgreSQL, Redis, and MariaDB instances that can be used by multiple services.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| PostgreSQL | 5432 | Primary relational database (multi-tenant) |
| Redis | 6379 | Cache, sessions, queues |
| MariaDB | 3306 | MySQL-compatible database |
| pgAdmin | 80 | PostgreSQL web management UI |
| Redis Commander | 8081 | Redis web management UI |

## Quick Start

1. Copy environment file:
```bash
cp .env.example .env
```

2. Generate strong passwords for all `CHANGE_ME` values:
```bash
# Generate random passwords
openssl rand -base64 32
```

3. Start the stack:
```bash
docker compose up -d
```

4. Access management UIs:
   - pgAdmin: https://pgadmin.yourdomain.com
   - Redis Commander: https://redis.yourdomain.com

## Connection Strings

### PostgreSQL

Services can connect to PostgreSQL using:

```
Host: homelab-postgres
Port: 5432
Database: <service_name>
User: <service_name>
Password: <from .env>
```

Example connection strings:

**Nextcloud:**
```
POSTGRES_HOST=homelab-postgres
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
```

**Gitea:**
```
GITEA__database__DB_TYPE=postgres
GITEA__database__HOST=homelab-postgres:5432
GITEA__database__NAME=gitea
GITEA__database__USER=gitea
GITEA__database__PASSWD=${GITEA_DB_PASSWORD}
```

**Outline:**
```
DATABASE_URL=postgres://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline
```

**Authentik:**
```
AUTHENTIK_POSTGRESQL__HOST=homelab-postgres
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=${AUTHENTIK_DB_PASSWORD}
```

**Grafana:**
```
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST=homelab-postgres:5432
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=grafana
GF_DATABASE_PASSWORD=${GRAFANA_DB_PASSWORD}
```

### Redis

Redis is configured with password authentication. Services connect using:

```
Host: homelab-redis
Port: 6379
Password: ${REDIS_PASSWORD}
```

**Redis Database Assignments:**

To isolate services, each uses a different Redis database number:

| DB # | Service | Connection String |
|------|---------|-------------------|
| 0 | Authentik | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/0` |
| 1 | Outline | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/1` |
| 2 | Gitea | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/2` |
| 3 | Nextcloud | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/3` |
| 4 | Grafana sessions | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/4` |

Example configuration:

**Authentik:**
```
AUTHENTIK_REDIS__HOST=homelab-redis
AUTHENTIK_REDIS__PASSWORD=${REDIS_PASSWORD}
AUTHENTIK_REDIS__DB=0
```

**Outline:**
```
REDIS_URL=redis://:${REDIS_PASSWORD}@homelab-redis:6379/1
```

**Gitea:**
```
GITEA__cache__ENABLED=true
GITEA__cache__ADAPTER=redis
GITEA__cache__HOST=network=tcp,addr=homelab-redis:6379,password=${REDIS_PASSWORD},db=2
```

### MariaDB

For services requiring MySQL compatibility:

```
Host: homelab-mariadb
Port: 3306
User: root
Password: ${MARIADB_ROOT_PASSWORD}
```

## Initialization

The `initdb/01-init-databases.sh` script runs automatically on first start and creates:

- Separate database + user for each service
- Required extensions (e.g., uuid-ossp for Outline)

**The script is idempotent** - safe to run multiple times without errors.

To manually re-run initialization:
```bash
docker exec homelab-postgres /docker-entrypoint-initdb.d/01-init-databases.sh
```

## Backup

Automated backups are handled by `../../scripts/backup-databases.sh`:

```bash
# Backup all databases
./scripts/backup-databases.sh --all

# Backup specific database
./scripts/backup-databases.sh --postgres
./scripts/backup-databases.sh --redis
./scripts/backup-databases.sh --mariadb
```

Backups are stored in `backups/databases/` with 7-day retention.

## Network Isolation

- Database services (PostgreSQL, Redis, MariaDB) are on the `databases` network only
- Management UIs (pgAdmin, Redis Commander) are on both `databases` and `proxy` networks
- Databases are **not** exposed to the host - only accessible internally via Docker networks

## Health Checks

All database services have health checks configured. Other stacks can wait for healthy databases:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
```

## Security Notes

1. Change all default passwords in `.env`
2. Use strong, unique passwords for each service database
3. Databases are not exposed externally - access only via internal Docker network
4. Management UIs are protected by Traefik with TLS

## Troubleshooting

**Check PostgreSQL logs:**
```bash
docker logs homelab-postgres
```

**Verify databases created:**
```bash
docker exec -it homelab-postgres psql -U postgres -c "\l"
```

**Test Redis connection:**
```bash
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

**Reset everything (WARNING: deletes all data):**
```bash
docker compose down -v
docker compose up -d
```
