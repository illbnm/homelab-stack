# Databases Stack

Shared database layer for all homelab services. Centralizes PostgreSQL, Redis, and MariaDB to avoid each service running its own database instance.

## Architecture

```
Other Stacks (Nextcloud, Gitea, Outline, Authentik, ...)
         │
         ▼
    databases network (internal)
         │
    ┌────┼────────────┬──────────────┐
    │    │             │              │
    ▼    ▼             ▼              ▼
PostgreSQL  Redis    MariaDB    (no external access)
 16.4       7.4.0    11.5.2
    │         │
    ▼         ▼
Traefik (proxy network — admin UIs only)
    │
    ├─► pgadmin.${DOMAIN}   → pgAdmin
    └─► redis.${DOMAIN}     → Redis Commander
```

## Services

| Service | Version | Network | Description |
|---------|---------|---------|-------------|
| PostgreSQL | 16.4-alpine | databases only | Primary relational database |
| Redis | 7.4.0-alpine | databases only | Cache & message queue |
| MariaDB | 11.5.2 | databases only | MySQL-compatible database |
| pgAdmin | 8.11 | databases + proxy | PostgreSQL web UI |
| Redis Commander | latest | databases + proxy | Redis web UI |

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
nano .env    # Set strong passwords!

# 2. Generate strong passwords
for var in POSTGRES_ROOT_PASSWORD REDIS_PASSWORD MARIADB_ROOT_PASSWORD; do
  echo "$var=$(openssl rand -base64 24)"
done

# 3. Start databases
docker compose up -d

# 4. Verify initialization
docker compose logs postgres | grep "init-postgres"

# 5. Check health
docker compose ps
```

## Multi-tenant PostgreSQL

The init script (`initdb/01-init-databases.sh`) automatically creates isolated databases and users for each service:

| Database | User | Used By |
|----------|------|---------|
| nextcloud | nextcloud | Nextcloud (Storage Stack) |
| gitea | gitea | Gitea (Productivity Stack) |
| outline | outline | Outline (Productivity Stack) |
| authentik | authentik | Authentik (SSO Stack) |
| grafana | grafana | Grafana (Observability Stack) |
| vaultwarden | vaultwarden | Vaultwarden (Productivity Stack) |
| bookstack | bookstack | BookStack (Productivity Stack) |

The init script is **idempotent** — safe to run multiple times without errors or data loss.

## Redis Database Allocation

Redis databases are isolated by number. Configure in each service's connection string:

| DB | Service | Connection String |
|----|---------|-------------------|
| 0 | Authentik | `redis://:PASSWORD@redis:6379/0` |
| 1 | Outline | `redis://:PASSWORD@redis:6379/1` |
| 2 | Gitea | `redis://:PASSWORD@redis:6379/2` |
| 3 | Nextcloud | `redis://:PASSWORD@redis:6379/3` |
| 4 | Grafana | `redis://:PASSWORD@redis:6379/4` |

## Connection Strings for Other Stacks

### PostgreSQL

```yaml
# In other stack's docker-compose.yml:
services:
  my-app:
    environment:
      DATABASE_URL: postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud
    networks:
      - databases
networks:
  databases:
    external: true
```

### Redis

```yaml
services:
  my-app:
    environment:
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
    networks:
      - databases
```

### MariaDB

```yaml
services:
  my-app:
    environment:
      DATABASE_URL: mysql://bookstack:${BOOKSTACK_DB_PASSWORD}@mariadb:3306/bookstack
    networks:
      - databases
```

## Network Isolation

Database containers are **NOT** exposed to the `proxy` network or host ports:

- `postgres`, `redis`, `mariadb` → `databases` network only
- `pgadmin`, `redis-commander` → `databases` + `proxy` (for Traefik web UI)
- No host port bindings = no direct external access

Other stacks connect by joining the `databases` network:

```yaml
networks:
  databases:
    external: true
```

## Backup & Restore

### Automated Backup

```bash
# Run backup (creates timestamped .tar.gz)
sudo bash scripts/backup-databases.sh

# Schedule daily backup via cron
echo "0 3 * * * cd /path/to/stacks/databases && bash scripts/backup-databases.sh" | sudo crontab -
```

The backup script:
- `pg_dumpall` — dumps all PostgreSQL databases
- `redis-cli BGSAVE` — triggers Redis persistence, copies dump.rdb
- `mysqldump` — dumps all MariaDB databases
- Compresses to `homelab-db-backup-YYYYMMDD_HHMMSS.tar.gz`
- Retains last 7 days (configurable via `RETAIN_DAYS`)
- Optional MinIO upload (`MINIO_ENABLED=true`)

### Manual Restore

```bash
# Extract backup
tar xzf homelab-db-backup-20260317_030000.tar.gz

# Restore PostgreSQL
cat postgres-all.sql | docker exec -i homelab-postgres psql -U postgres

# Restore Redis
docker cp redis-dump.rdb homelab-redis:/data/dump.rdb
docker compose restart redis

# Restore MariaDB
cat mariadb-all.sql | docker exec -i homelab-mariadb mysql -u root -p
```

## Troubleshooting

### Init Script Didn't Run

The Docker entrypoint only runs init scripts on **first start** (when the data directory is empty). To re-run:

```bash
# Option 1: Exec into container and run manually
docker exec -it homelab-postgres bash /docker-entrypoint-initdb.d/01-init-databases.sh

# Option 2: Reset data (WARNING: deletes all data!)
docker compose down -v
docker compose up -d
```

### Can't Connect from Another Stack

1. Verify the stack's docker-compose.yml declares the `databases` network as external
2. Check the container is on the `databases` network:
   ```bash
   docker network inspect databases | grep -A5 "my-app"
   ```
3. Test connectivity:
   ```bash
   docker exec my-app-container ping postgres
   ```

### pgAdmin Can't Connect

In pgAdmin, add a server with:
- Host: `postgres` (container name)
- Port: `5432`
- Username: `postgres`
- Password: your `POSTGRES_ROOT_PASSWORD`

### Redis Memory Full

Current limit: 512MB with `allkeys-lru` eviction. To increase:

```yaml
# In docker-compose.yml, modify redis command:
command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 1gb
```

---

Generated/reviewed with: claude-opus-4-6
