# Database Stack

Enterprise-grade database services for HomeLab infrastructure with PostgreSQL, Redis, and MariaDB.

## Services Overview

| Service | Version | Purpose | Access | Health Check |
|---------|---------|---------|---------|-------------|
| PostgreSQL | 16.4-alpine | Primary relational database | Internal only | `pg_isready` |
| Redis | 7.4.0-alpine | Caching & session store | Internal only | `redis-cli ping` |
| MariaDB | 11.5.2 | MySQL-compatible database | Internal only | `mysqladmin ping` |
| pgAdmin | 8.11 | PostgreSQL web interface | https://pgadmin.${DOMAIN} | HTTP 200 |
| Redis Commander | latest | Redis web interface | https://redis.${DOMAIN} | HTTP 200 |

## Network Architecture

- **Internal Network**: Core databases isolated from external access
- **Proxy Network**: Management UIs exposed via Traefik reverse proxy
- **Security**: Database containers not directly accessible from internet

## Database Initialization

All databases are automatically configured with application-specific users and databases:

### PostgreSQL Tenants
```sql
-- Automatically created by init scripts
nextcloud_db      -> nextcloud_user
gitea_db          -> gitea_user
outline_db        -> outline_user
authentik_db      -> authentik_user
grafana_db        -> grafana_user
```

### MariaDB Tenants
```sql
-- WordPress and legacy applications
wordpress_db      -> wordpress_user
invoiceninja_db   -> invoiceninja_user
```

## Redis Database Mapping

Redis instance uses multiple logical databases for service isolation:

```bash
# Database allocation per service
DB 0: General cache (default)
DB 1: User sessions (NextCloud, Authentik)
DB 2: Task queues (background jobs)
DB 3: Rate limiting & throttling
DB 4: Temporary data & locks
DB 5: Search indexes & cached queries
DB 6: Metrics & analytics buffers
DB 7: WebSocket connection states
DB 8: File upload progress tracking
DB 9: API response caching
DB 10: Email queue & templates
DB 11: Notification queues
DB 12: Reserved for testing
DB 13: Reserved for development
DB 14: Reserved for staging
DB 15: Reserved for admin tools
```

## Connection Strings

### PostgreSQL
```bash
# Internal container access
postgresql://username:password@postgres:5432/database_name

# Examples for common services
NEXTCLOUD_DB_URL="postgresql://nextcloud_user:${NEXTCLOUD_DB_PASS}@postgres:5432/nextcloud_db"
GITEA_DB_URL="postgresql://gitea_user:${GITEA_DB_PASS}@postgres:5432/gitea_db"
AUTHENTIK_DB_URL="postgresql://authentik_user:${AUTHENTIK_DB_PASS}@postgres:5432/authentik_db"
```

### Redis
```bash
# Standard connection
redis://redis:6379/0

# With authentication (if enabled)
redis://:${REDIS_PASSWORD}@redis:6379/0

# Service-specific database selection
CACHE_REDIS_URL="redis://redis:6379/0"
SESSION_REDIS_URL="redis://redis:6379/1"
QUEUE_REDIS_URL="redis://redis:6379/2"
```

### MariaDB
```bash
# Internal container access
mysql://username:password@mariadb:3306/database_name

# WordPress example
WORDPRESS_DB_URL="mysql://wordpress_user:${WORDPRESS_DB_PASS}@mariadb:3306/wordpress_db"
```

## Management Access

### pgAdmin
- **URL**: https://pgadmin.${DOMAIN}
- **Login**: admin@${DOMAIN}
- **Password**: Set in `PGADMIN_PASSWORD`
- **Server Setup**: Pre-configured for PostgreSQL instance

### Redis Commander
- **URL**: https://redis.${DOMAIN}
- **Authentication**: Basic auth if `REDIS_PASSWORD` is set
- **Features**: Database browser, key management, memory analysis

## Backup & Restore

### Automated Backups
```bash
# Run database backups
./scripts/backup-databases.sh

# Backup specific database
./scripts/backup-databases.sh --postgres nextcloud_db
./scripts/backup-databases.sh --redis --db 1
./scripts/backup-databases.sh --mariadb wordpress_db
```

### Manual Backup Commands
```bash
# PostgreSQL dump
docker exec postgres pg_dump -U postgres database_name > backup.sql

# Redis save
docker exec redis redis-cli BGSAVE
docker cp redis:/data/dump.rdb ./redis-backup.rdb

# MariaDB dump
docker exec mariadb mysqldump -u root -p database_name > backup.sql
```

### Restore Procedures
```bash
# PostgreSQL restore
cat backup.sql | docker exec -i postgres psql -U postgres -d database_name

# Redis restore
docker cp ./redis-backup.rdb redis:/data/dump.rdb
docker restart redis

# MariaDB restore
cat backup.sql | docker exec -i mariadb mysql -u root -p database_name
```

## Troubleshooting

### Container Health Issues

**PostgreSQL not starting:**
```bash
# Check logs
docker logs postgres

# Common issues:
# - Insufficient disk space in /var/lib/postgresql/data
# - Corrupted data files (check pg_ctl logs)
# - Port 5432 already in use
```

**Redis memory issues:**
```bash
# Check memory usage
docker exec redis redis-cli INFO memory

# Configure memory policies in docker-compose.yml:
# maxmemory: 512mb
# maxmemory-policy: allkeys-lru
```

### Connection Problems

**Application can't connect to database:**
```bash
# Verify network connectivity
docker exec app_container ping postgres
docker exec app_container telnet postgres 5432

# Check database exists
docker exec postgres psql -U postgres -l

# Verify user permissions
docker exec postgres psql -U postgres -c "\du"
```

### Performance Optimization

**PostgreSQL slow queries:**
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();

-- Check active connections
SELECT * FROM pg_stat_activity;
```

**Redis memory optimization:**
```bash
# Analyze memory usage by database
docker exec redis redis-cli --eval scripts/redis-memory-analysis.lua

# Monitor hit ratio
docker exec redis redis-cli INFO stats | grep keyspace
```

### Data Recovery

**Corrupted PostgreSQL data:**
```bash
# Stop all dependent services first
docker-compose -f stacks/*/docker-compose.yml stop

# Try recovery mode
docker exec postgres pg_resetwal /var/lib/postgresql/data

# If recovery fails, restore from backup
```

**Redis data loss:**
```bash
# Check if dump.rdb exists
docker exec redis ls -la /data/

# Restore from most recent backup
docker cp backups/redis/dump.rdb redis:/data/
docker restart redis
```

## Monitoring & Alerts

Database health is monitored through:
- Container health checks (every 30s)
- Prometheus metrics export (if monitoring stack enabled)
- Log aggregation via centralized logging
- Backup job success/failure notifications

For performance monitoring, enable the monitoring stack and access Grafana dashboards for database metrics.
