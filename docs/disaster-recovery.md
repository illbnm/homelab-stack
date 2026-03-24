# Disaster Recovery Guide

## Overview

This document covers backup strategy, restore procedures, and disaster recovery for the HomeLab Stack.

## Backup Strategy

### Automated Backups

The backup system consists of two scripts:

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `scripts/backup.sh` | Full backup (configs + volumes + databases) | Daily recommended |
| `scripts/backup-databases.sh` | Database-only backup | Every 6 hours recommended |

### What Gets Backed Up

1. **Docker Volumes** — All named volumes (app data, configs, uploads)
2. **Config Files** — `config/`, `stacks/`, `scripts/` directories
3. **Databases** — PostgreSQL (`pg_dumpall`), MariaDB (`mysqldump --all-databases`), Redis (RDB snapshot)

### Schedule Setup

```bash
# Add to crontab: crontab -e

# Full backup daily at 3:00 AM
0 3 * * * /opt/homelab-stack/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1

# Database backup every 6 hours
0 */6 * * * /opt/homelab-stack/scripts/backup-databases.sh >> /var/log/homelab-db-backup.log 2>&1
```

### Retention Policy

Default: 7 days. Configure via `BACKUP_RETENTION_DAYS` in `.env`.

## Restore Procedures

### Full Restore

```bash
# 1. List available backups
ls /opt/homelab-backups/

# 2. Restore from a specific backup
./scripts/restore.sh /opt/homelab-backups/20260324_030000

# 3. Restart all services
./scripts/stack-manager.sh restart-all
```

### Database-Only Restore

```bash
# PostgreSQL
gunzip < backups/databases/postgres_20260324_120000.sql.gz | \
  docker exec -i homelab-postgres psql -U postgres

# MariaDB
gunzip < backups/databases/mariadb_20260324_120000.sql.gz | \
  docker exec -i homelab-mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD"

# Redis
docker cp backups/databases/redis_20260324_120000.rdb homelab-redis:/data/dump.rdb
docker restart homelab-redis
```

## Disaster Scenarios

### Scenario 1: Container Won't Start

```bash
# Check logs
docker compose -f stacks/<stack>/docker-compose.yml logs <service>

# Check health
docker inspect --format='{{.State.Health.Status}}' <container>

# Remove and recreate
docker compose -f stacks/<stack>/docker-compose.yml rm -f <service>
docker compose -f stacks/<stack>/docker-compose.yml up -d <service>
```

### Scenario 2: Disk Full

```bash
# Check disk usage
df -h
docker system df

# Clean up
docker system prune -f
docker volume prune -f  # ⚠️ Destructive — check first!
```

### Scenario 3: Complete Server Loss

1. Provision new server with Docker
2. Clone repository
3. Copy `.env` file from backup
4. Restore from latest backup:
   ```bash
   ./scripts/restore.sh /path/to/backup_dir
   ```
5. Start stacks in order:
   ```bash
   ./install.sh
   ```

### Scenario 4: Database Corruption

```bash
# Stop affected stack
docker compose -f stacks/<stack>/docker-compose.yml down

# Restore database from backup
./scripts/restore.sh /path/to/backup_dir

# Start stack
docker compose -f stacks/<stack>/docker-compose.yml up -d
```

## Backup Verification

Regularly verify backups by doing test restores:

```bash
# 1. Create test environment
docker volume create test-restore

# 2. Restore to test volume
docker run --rm -v test-restore:/data -v /path/to/backup:/backup:ro alpine tar xzf /backup/vol_xxx.tar.gz -C /data

# 3. Verify data
docker run --rm -v test-restore:/data alpine ls -la /data

# 4. Cleanup
docker volume rm test-restore
```

## Off-Site Backup (Optional)

For critical data, sync backups to remote storage:

```bash
# Using rclone (install separately)
rclone sync /opt/homelab-backups remote:homelab-backups --max-age 30d

# Using rsync
rsync -avz /opt/homelab-backups/ user@remote:/backups/homelab/
```
