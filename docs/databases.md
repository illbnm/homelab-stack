# Databases Stack

Shared database infrastructure for HomeLab services using PostgreSQL, Redis, and MariaDB.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Databases Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ PostgreSQL │  │    Redis    │  │   MariaDB   │            │
│  │  :5432     │  │   :6379     │  │   :3306     │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                │                │                   │
│  ┌──────┴────────────────┴────────────────┴──────┐             │
│  │            Internal Network (homelab-internal) │            │
│  └────────────────────────────────────────────────┘             │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐             │
│         │                    │                    │             │
│  ┌──────┴──────┐    ┌───────┴───────┐    ┌───────┴───────┐    │
│  │   pgAdmin   │    │Redis Commander│    │  Other Stacks │    │
│  │  :5050      │    │    :8081      │    │               │    │
│  └─────────────┘    └───────────────┘    └───────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | postgres:16.4-alpine | 5432 | Main relational database |
| Redis | redis:7.4.0-alpine | 6379 | Cache and session storage |
| MariaDB | mariadb:11.5.2 | 3306 | MySQL-compatible database |
| pgAdmin | dpage/pgadmin4:8.11 | 5050 | PostgreSQL web UI |
| Redis Commander | rediscommander/redis-commander | 8081 | Redis web UI |

## Redis Database Allocation

Redis uses database numbers (0-15) to isolate different services:

| DB Number | Service | Purpose |
|-----------|---------|---------|
| 0 | Authentik | SSO session cache |
| 1 | Outline | Document cache |
| 2 | Gitea | Repository cache |
| 3 | Nextcloud | File metadata cache |
| 4 | Grafana | Session storage |

Connect with: `redis-cli -n <db_number>`

## PostgreSQL Databases

Automatically created on first start:

| Database | Owner | Purpose |
|----------|-------|---------|
| nextcloud | nextcloud | Nextcloud main database |
| gitea | gitea | Gitea Git repository metadata |
| outline | outline | Outline wiki database |
| authentik | authentik | Authentik SSO database |
| grafana | grafana | Grafana metrics storage |
| vaultwarden | vaultwarden | Vaultwarden password vault |
| bookstack | bookstack | BookStack documentation |

## Quick Start

1. Copy environment template:
```bash
cp .env.example .env
```

2. Edit `.env` and fill in required passwords:
```bash
# Generate secure passwords
openssl rand -base64 24  # Use for POSTGRES_PASSWORD
openssl rand -base64 24  # Use for REDIS_PASSWORD
openssl rand -base64 24  # Use for MARIADB_ROOT_PASSWORD

# Or use a password manager
```

3. Start the databases stack:
```bash
cd stacks/databases
docker-compose up -d
```

4. Verify services are running:
```bash
docker ps | grep homelab-
```

## Service Connection Strings

### PostgreSQL

```bash
# Connection from other stacks
host: homelab-postgres
port: 5432
database: <service-db-name>
username: <service-username>
password: ${SERVICE_DB_PASSWORD}

# Example: Gitea
host: homelab-postgres
port: 5432
database: gitea
username: gitea
password: ${GITEA_DB_PASSWORD}
```

### Redis

```bash
# Connection from other stacks
host: homelab-redis
port: 6379
password: ${REDIS_PASSWORD}
database: <db-number>  # 0-4

# Example: Authentik (DB 0)
host: homelab-redis
port: 6379
password: ${REDIS_PASSWORD}
database: 0
```

### MariaDB

```bash
# Connection from other stacks
host: homelab-mariadb
port: 3306
database: <service-db-name>
username: <service-username>
password: ${SERVICE_DB_PASSWORD}

# Example: BookStack
host: homelab-mariadb
port: 3306
database: bookstack
username: bookstack
password: ${BOOKSTACK_DB_PASSWORD}
```

## Management Interfaces

### pgAdmin

- URL: https://pgadmin.`$DOMAIN`
- Email: `${PGADMIN_EMAIL}`
- Password: `${PGADMIN_PASSWORD}`
- Server: `homelab-postgres:5432`

### Redis Commander

- URL: https://redis.`$DOMAIN`
- Username: `${REDISCommander_USER}`
- Password: `${REDISCommander_PASSWORD}`

## Backups

### Manual Backup

```bash
# Backup all databases
./scripts/backup-databases.sh --all

# Backup specific database
./scripts/backup-databases.sh --postgres
./scripts/backup-databases.sh --redis
./scripts/backup-databases.sh --mariadb
```

### Automated Backup with Cron

```bash
# Add to crontab (daily at 2 AM)
0 2 * * * cd /path/to/homelab-stack && ./scripts/backup-databases.sh --all >> /var/log/homelab-backup.log 2>&1
```

### Backup Files Location

Backups are stored in `backups/databases/`:
- `postgres_YYYYMMDD_HHMMSS.sql.gz`
- `redis_YYYYMMDD_HHMMSS.rdb`
- `mariadb_YYYYMMDD_HHMMSS.sql.gz`

**Retention**: 7 days (automatic cleanup)

### Upload to MinIO (Optional)

```bash
# Configure MinIO in .env
MINIO_ENDPOINT=minio.yourdomain.com:9000
MINIO_ACCESS_KEY=your-access-key
MINIO_SECRET_KEY=your-secret-key
MINIO_BUCKET=homelab-backups

# Upload latest backups
./scripts/backup-databases.sh --upload
```

## Health Checks

All database containers have health checks configured:

```bash
# Check health status
docker inspect homelab-postgres --format='{{.State.Health.Status}}'
docker inspect homelab-redis --format='{{.State.Health.Status}}'
docker inspect homelab-mariadb --format='{{.State.Health.Status}}'
```

## Network Isolation

Databases are isolated in the `homelab-internal` network:

- **Not exposed** to the outside (no host ports)
- **Not in** proxy network (except management UIs)
- **Accessible** to other stacks via Docker DNS

Services can connect using:
```yaml
# In other stack docker-compose.yml
services:
  myservice:
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DB_HOST=homelab-postgres
    networks:
      - default
      - homelab-internal
```

## Troubleshooting

### Reset a Database

If a service database is corrupted, you can reset it:

```bash
# Connect to PostgreSQL
docker exec -it homelab-postgres psql -U postgres

# Drop and recreate database
DROP DATABASE nextcloud;
CREATE DATABASE nextcloud OWNER nextcloud;
```

### Check Database Size

```bash
# PostgreSQL
docker exec homelab-postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database WHERE datistemplate = false;"

# MariaDB
docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;"
```

### View Redis Keys

```bash
# List all keys
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" KEYS "*"

# Select specific database
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" -n 1 KEYS "*"
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_USER` | No | PostgreSQL admin user (default: postgres) |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL root password |
| `REDIS_PASSWORD` | Yes | Redis server password |
| `MARIADB_ROOT_PASSWORD` | Yes | MariaDB root password |
| `PGADMIN_EMAIL` | Yes | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | pgAdmin login password |
| `REDISCommander_USER` | No | Redis Commander username |
| `REDISCommander_PASSWORD` | Yes | Redis Commander password |
| `GITEA_DB_PASSWORD` | No | Gitea database password |
| `NEXTCLOUD_DB_PASSWORD` | No | Nextcloud database password |
| `OUTLINE_DB_PASSWORD` | No | Outline database password |
| `AUTHENTIK_DB_PASSWORD` | No | Authentik database password |
| `GRAFANA_DB_PASSWORD` | No | Grafana database password |
| `VAULTWARDEN_DB_PASSWORD` | No | Vaultwarden database password |
| `BOOKSTACK_DB_PASSWORD` | No | BookStack database password |
| `BACKUP_DIR` | No | Backup directory path |
| `MINIO_*` | No | MinIO backup configuration |

## Adding New Services

To add a new service database:

1. Add password to `.env`:
```bash
NEW_SERVICE_DB_PASSWORD=your-secure-password
```

2. Update `stacks/databases/initdb/01-init-databases.sh`:
```bash
create_user "newservice" "${NEW_SERVICE_DB_PASSWORD}"
create_database "newservice" "newservice"
```

3. Add to your service's `docker-compose.yml`:
```yaml
environment:
  - DB_HOST=homelab-postgres
  - DB_PASSWORD=${NEW_SERVICE_DB_PASSWORD}
networks:
  - homelab-internal
```

## Security Notes

- All database passwords should be strong random strings (32+ characters)
- Management UIs (pgAdmin, Redis Commander) are exposed via Traefik - ensure strong passwords
- Databases are not exposed to host network for security
- Use internal Docker network for service-to-service communication