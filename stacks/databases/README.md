# Databases Stack

> Shared database layer - PostgreSQL, Redis, MariaDB + management UIs

## 💰 Bounty

**$100 USDT** - See [BOUNTY.md](../../BOUNTY.md)

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| PostgreSQL | `postgres:16.4-alpine` | Primary database |
| Redis | `redis:7.4.0-alpine` | Cache/Queue |
| MariaDB | `mariadb:11.5.2` | MySQL compatible |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL management |
| Redis Commander | `rediscommander/redis-commander:0.8.0` | Redis management |

## Prerequisites

1. **Docker & Docker Compose** installed
2. **Base Infrastructure** deployed (Traefik required for management UIs)

## Quick Start

### 1. Configure environment

```bash
cd stacks/databases
cp .env.example .env
# Edit .env with your settings
```

### 2. Create networks

```bash
docker network create internal
```

### 3. Start services

```bash
docker compose up -d
```

### 4. Verify services

```bash
docker compose ps
```

**Expected output:**
```
NAME            IMAGE                                    STATUS
postgres        postgres:16.4-alpine                    Up (healthy)
redis           redis:7.4.0-alpine                      Up (healthy)
mariadb         mariadb:11.5.2                          Up (healthy)
pgadmin         dpage/pgadmin4:8.11                    Up (healthy)
redis-commander rediscommander/redis-commander:0.8.0   Up (healthy)
```

### 5. Initialize databases

```bash
# The init script runs automatically on first start
# To re-run manually:
docker exec postgres psql -U postgres -f /docker-entrypoint-initdb.d/init.sh
```

### 6. Test database connections

```bash
# Test PostgreSQL
docker exec postgres psql -U nextcloud -d nextcloud -c "SELECT 1;"

# Test Redis
docker exec redis redis-cli -a your-redis-password PING

# Test MariaDB
docker exec mariadb mysql -u root -pyour-mariadb-password -e "SELECT 1;"
```

### 7. Test management UIs

```bash
# Test pgAdmin
curl -I https://pgadmin.yourdomain.com
# Expected: 200 OK

# Test Redis Commander
curl -I https://redis-commander.yourdomain.com
# Expected: 200 OK
```

## Access URLs

| Service | URL |
|---------|-----|
| pgAdmin | `https://pgadmin.yourdomain.com` |
| Redis Commander | `https://redis-commander.yourdomain.com` |

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `example.com` |
| `POSTGRES_ROOT_PASSWORD` | PostgreSQL root password | `xxxx` |
| `REDIS_PASSWORD` | Redis password | `xxxx` |
| `MARIADB_ROOT_PASSWORD` | MariaDB root password | `xxxx` |
| `PGADMIN_EMAIL` | pgAdmin login email | `admin@example.com` |
| `PGADMIN_PASSWORD` | pgAdmin password | `xxxx` |
| `NEXTCLOUD_DB_PASSWORD` | Nextcloud database password | `xxxx` |
| `GITEA_DB_PASSWORD` | Gitea database password | `xxxx` |
| `OUTLINE_DB_PASSWORD` | Outline database password | `xxxx` |
| `AUTHENTIK_DB_PASSWORD` | Authentik database password | `xxxx` |
| `GRAFANA_DB_PASSWORD` | Grafana database password | `xxxx` |

### Optional CN Images

```bash
# For China servers, uncomment in .env:
# POSTGRES_IMAGE=postgres:16.4-alpine
# REDIS_IMAGE=redis:7.4.0-alpine
# MARIADB_IMAGE=mariadb:11.5.2
# PGADMIN_IMAGE=dpage/pgadmin4:8.11
# REDIS_COMMANDER_IMAGE=rediscommander/redis-commander:0.8.0
```

## Database Connection Strings

### From Other Stacks

**PostgreSQL:**
```
postgresql://nextcloud:<password>@postgres:5432/nextcloud
postgresql://gitea:<password>@postgres:5432/gitea
postgresql://outline:<password>@postgres:5432/outline
postgresql://authentik:<password>@postgres:5432/authentik
postgresql://grafana:<password>@postgres:5432/grafana
```

**Redis:**
```
redis://:password@redis:6379/0   # DB 0 - Authentik
redis://:password@redis:6379/1   # DB 1 - Outline
redis://:password@redis:6379/2   # DB 2 - Gitea
redis://:password@redis:6379/3   # DB 3 - Nextcloud
redis://:password@redis:6379/4   # DB 4 - Grafana sessions
```

**MariaDB:**
```
mariadb://root:password@mariadb:3306/nextcloud
```

## Backup

### Manual Backup

```bash
# Run backup script
./scripts/backup-databases.sh
```

### Automated Backup (cron)

```bash
# Add to crontab (daily at 3am)
0 3 * * * cd /path/to/stacks/databases && ./scripts/backup-databases.sh
```

### Backup Files

Backups are saved to `./backups/` directory:
- `postgres_all_YYYYMMDD_HHMMSS.sql.gz`
- `mariadb_all_YYYYMMDD_HHMMSS.sql.gz`

## Network Architecture

```
┌─────────────────────────────────────────┐
│           proxy (external)              │
│   (Traefik access for mgmt UIs)        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│           internal network              │
│                                         │
│  ┌──────────┐    ┌──────────┐         │
│  │ postgres │    │   redis  │         │
│  │    :5432 │    │   :6379  │         │
│  └──────────┘    └──────────┘         │
│                                         │
│  ┌──────────┐    ┌──────────────┐     │
│  │ mariadb  │    │  pgadmin     │     │
│  │   :3306  │    │  (Traefik)  │     │
│  └──────────┘    └──────────────┘     │
│                      │                 │
│                 ┌──────────────┐      │
│                 │redis-commander│     │
│                 │  (Traefik)   │     │
│                 └──────────────┘      │
└────────────────────────────────────────┘
```

## Troubleshooting

### Check logs

```bash
docker logs postgres
docker logs redis
docker logs mariadb
docker logs pgadmin
docker logs redis-commander
```

### Common issues

1. **Database initialization fails**
   - Check POSTGRES_ROOT_PASSWORD is set
   - Check logs: `docker logs postgres`

2. **Other stacks can't connect**
   - Ensure both stacks use the same `internal` network
   - Use container name as hostname: `postgres`, `redis`, `mariadb`

3. **pgAdmin/Redis Commander not accessible**
   - Ensure `proxy` network exists
   - Check Traefik labels

4. **Backup script fails**
   - Ensure BACKUP_DIR is writable
   - Check disk space

## File Structure

```
stacks/databases/
├── docker-compose.yml    # Main compose file
├── .env.example         # Environment template
└── README.md            # This file

scripts/
├── init-databases.sh    # Database initialization (idempotent)
└── backup-databases.sh  # Backup script
```

## License

MIT
