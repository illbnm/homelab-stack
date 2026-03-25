# Databases Stack

Shared database layer for all homelab services. Provides PostgreSQL, Redis, and MariaDB databases with management interfaces.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | `postgres:16.4-alpine` | 5432 (internal) | Primary multi-tenant database |
| Redis | `redis:7.4.0-alpine` | 6379 (internal) | Cache and message queue |
| MariaDB | `mariadb:11.5.2` | 3306 (internal) | MySQL-compatible database |
| pgAdmin | `dpage/pgadmin4:8.11` | 80 (via Traefik) | PostgreSQL management UI |
| Redis Commander | `rediscommander/redis-commander:latest` | 8081 (via Traefik) | Redis management UI |

## Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env
nano .env

# 2. Start the stack
docker compose up -d

# 3. Initialize databases for services
../../scripts/init-databases.sh
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_PASSWORD` | Yes | PostgreSQL superuser password |
| `REDIS_PASSWORD` | Yes | Redis authentication password |
| `MARIADB_ROOT_PASSWORD` | Yes | MariaDB root password |
| `PGADMIN_EMAIL` | Yes | pgAdmin login email |
| `PGADMIN_PASSWORD` | Yes | pgAdmin login password |
| `DOMAIN` | Yes | Your domain for admin interfaces |

### Per-Service Database Passwords

Set these to auto-create databases during initialization:

- `NEXTCLOUD_DB_PASSWORD`
- `GITEA_DB_PASSWORD`
- `OUTLINE_DB_PASSWORD`
- `AUTHENTIK_DB_PASSWORD`
- `GRAFANA_DB_PASSWORD`
- `BOOKSTACK_DB_PASSWORD`

## Database Distribution

### PostgreSQL Databases

| Database | User | Purpose |
|----------|------|---------|
| `nextcloud` | `nextcloud` | Nextcloud data |
| `gitea` | `gitea` | Gitea repositories |
| `outline` | `outline` | Outline wiki |
| `authentik` | `authentik` | Authentik SSO |
| `grafana` | `grafana` | Grafana dashboards |

### MariaDB Databases

| Database | User | Purpose |
|----------|------|---------|
| `nextcloud` | `nextcloud` | Nextcloud (MySQL mode) |
| `bookstack` | `bookstack` | BookStack documentation |

### Redis Database Allocation

| DB Index | Service |
|----------|---------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana sessions |

## Connection Strings

### PostgreSQL

```bash
# Format
postgresql://<user>:<password>@postgres:5432/<database>

# Examples
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud
postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea
```

### Redis

```bash
# Format
redis://:${REDIS_PASSWORD}@redis:6379/<db_index>

# Examples
redis://:${REDIS_PASSWORD}@redis:6379/0  # Authentik
redis://:${REDIS_PASSWORD}@redis:6379/1  # Outline
redis://:${REDIS_PASSWORD}@redis:6379/2  # Gitea
```

### MariaDB

```bash
# Format
mysql://<user>:<password>@mariadb:3306/<database>

# Examples
mysql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@mariadb:3306/nextcloud
mysql://bookstack:${BOOKSTACK_DB_PASSWORD}@mariadb:3306/bookstack
```

## Scripts

### init-databases.sh

Initialize databases for all services. **Idempotent** - safe to run multiple times.

```bash
# Initialize all databases
./scripts/init-databases.sh

# Initialize only PostgreSQL
./scripts/init-databases.sh --postgres

# Initialize only MariaDB
./scripts/init-databases.sh --mariadb
```

### backup-databases.sh

Backup all databases to compressed archive.

```bash
# Basic backup
./scripts/backup-databases.sh

# Custom retention
./scripts/backup-databases.sh --keep 14

# Upload to S3 (requires AWS CLI or MinIO client)
BACKUP_TARGET=s3 S3_BUCKET=my-bucket ./scripts/backup-databases.sh
```

Output:
- `${BACKUP_DIR}/databases_YYYYMMDD_HHMMSS.tar.gz`

Contains:
- `postgres_YYYYMMDD_HHMMSS.sql.gz` - pg_dumpall output
- `redis_YYYYMMDD_HHMMSS.rdb.gz` - Redis RDB snapshot
- `mariadb_YYYYMMDD_HHMMSS.sql.gz` - mysqldump output

## Health Checks

All containers include health checks:

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View health check logs
docker inspect --format='{{json .State.Health}}' homelab-postgres | jq
```

## Network Architecture

```
┌─────────────────────────────────────────────────────┐
│                    proxy network                     │
│  (Traefik - external)                               │
│                                                     │
│  ┌──────────┐        ┌──────────────────┐          │
│  │ pgAdmin  │        │ Redis Commander  │          │
│  │  :80     │        │     :8081        │          │
│  └────┬─────┘        └────────┬─────────┘          │
└───────┼──────────────────────┼─────────────────────┘
        │                      │
┌───────┼──────────────────────┼─────────────────────┐
│       │    databases network │                     │
│       │                      │                     │
│  ┌────▼────┐  ┌────────┐  ┌──▼─────────┐          │
│  │PostgreSQL│  │ Redis  │  │  MariaDB   │          │
│  │  :5432  │  │ :6379  │  │   :3306    │          │
│  └─────────┘  └────────┘  └────────────┘          │
│       ^          ^    ^                            │
│       │          │    │                            │
│       └──────────┴────┴── Other services connect   │
└─────────────────────────────────────────────────────┘
```

**Key points:**
- Database containers are NOT exposed to the proxy network
- Only admin UIs (pgAdmin, Redis Commander) are publicly accessible
- Other stacks connect via `databases` network only

## Integration with Other Stacks

### Connecting from Other Services

Add to your service's `docker-compose.yml`:

```yaml
services:
  myapp:
    # ...
    networks:
      - databases
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://myuser:mypass@postgres:5432/mydb
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0

networks:
  databases:
    external: true
```

### Example: Nextcloud

```yaml
services:
  nextcloud:
    image: nextcloud:29.0.7-fpm-alpine
    networks:
      - databases
      - proxy
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: ${NEXTCLOUD_DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

## Troubleshooting

### PostgreSQL won't start

```bash
# Check logs
docker logs homelab-postgres

# Common issues:
# - Permission errors: ensure data volume is writable
# - Password issues: check .env file
```

### Cannot connect to database

```bash
# Test PostgreSQL connection
docker exec homelab-postgres psql -U postgres -c "SELECT 1"

# Test Redis connection
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping

# Test MariaDB connection
docker exec homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"
```

### Reset databases (WARNING: destroys all data)

```bash
# Stop containers
docker compose down

# Remove volumes
docker volume rm homelab-stack_postgres-data
docker volume rm homelab-stack_redis-data
docker volume rm homelab-stack_mariadb-data

# Start fresh
docker compose up -d
./scripts/init-databases.sh
```

## Backup & Recovery

### Scheduled Backups

Add to crontab:

```bash
# Daily backup at 2:00 AM
0 2 * * * /path/to/homelab-stack/scripts/backup-databases.sh >> /var/log/db-backup.log 2>&1
```

### Restore from Backup

```bash
# Extract archive
tar -xzf databases_YYYYMMDD_HHMMSS.tar.gz

# Restore PostgreSQL
gunzip -c postgres_*.sql.gz | docker exec -i homelab-postgres psql -U postgres

# Restore Redis
gunzip -c redis_*.rdb.gz | docker exec -i homelab-redis redis-cli -x RESTORE

# Restore MariaDB
gunzip -c mariadb_*.sql.gz | docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}"
```

## Security Considerations

1. **Strong passwords**: Use at least 32-character random passwords
2. **Network isolation**: Databases not exposed to internet
3. **Admin interfaces**: Protected by Traefik + HTTPS
4. **Encryption in transit**: Use TLS for external connections
5. **Regular backups**: Test restore procedures

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| PostgreSQL | 256 MB | 512 MB - 1 GB |
| Redis | 128 MB | 256 MB |
| MariaDB | 256 MB | 512 MB - 1 GB |
| pgAdmin | 128 MB | 256 MB |
| Redis Commander | 64 MB | 128 MB |
| **Total** | **832 MB** | **1.5 - 2 GB** |

## License

MIT
