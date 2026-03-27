# Disaster Recovery Guide

Complete recovery procedures for HomeLab Stack.

## Recovery Time Objectives (RTO)

| Scenario | RTO | Priority |
|----------|-----|----------|
| Single service failure | < 30 min | High |
| Stack-level failure | < 2 hours | High |
| Complete server failure | < 4 hours | Medium |
| Full disaster (site loss) | < 24 hours | Low |

## Recovery Priority Order

When recovering from a complete disaster, restore services in this order:

1. **Base Infrastructure** — Traefik, Portainer, Watchtower
2. **Database Layer** — PostgreSQL, Redis, MariaDB
3. **SSO** — Authentik
4. **Storage** — Nextcloud, MinIO
5. **Productivity** — Gitea, Outline, BookStack
6. **Media** — Jellyfin, Sonarr, Radarr
7. **Other services**

## Complete Server Recovery

### Prerequisites

- Fresh Ubuntu/Debian server with Docker installed
- Backup files accessible (local or cloud)
- This repository cloned to the new server

### Step 1: Restore Configuration

```bash
# Restore config directory
cd /opt/homelab-stack
sudo tar -xzf backups/configs_YYYYMMDD_HHMMSS.tar.gz

# Restore environment files
cp config/.env.example config/.env
vim config/.env  # Update with current values
```

### Step 2: Restore Docker Volumes

```bash
# List available backups
./scripts/backup.sh --list

# Restore specific volume
docker volume create <volume_name>
docker run --rm \
  -v <volume_name>:/data \
  -v /path/to/backup:/backup \
  alpine \
  tar -xzf /backup/vol_<volume_name>.tar.gz -C /data
```

### Step 3: Restore Databases

#### PostgreSQL

```bash
# Restore PostgreSQL
docker exec -i postgres psql -U postgres < backups/postgresql_all.sql
```

#### MariaDB

```bash
# Restore MariaDB
docker exec -i mariadb mysql -u root -p < backups/mysql_all.sql
```

#### Redis

```bash
# Stop Redis
docker compose stop redis

# Restore RDB file
docker run --rm \
  -v homelab_redis:/data \
  -v /path/to/backups:/backup \
  alpine \
  sh -c "cp /backup/dump.rdb /data/dump.rdb"

# Start Redis
docker compose start redis
```

### Step 4: Start Services

```bash
# Start base infrastructure
./scripts/stack-manager.sh up base

# Verify base services
docker compose -f stacks/base/docker-compose.yml ps

# Start database layer
./scripts/stack-manager.sh up databases

# Verify databases
docker compose -f stacks/databases/docker-compose.yml ps

# Continue with other stacks...
```

### Step 5: Verify Recovery

```bash
# Check all services
docker compose ps

# Run health checks
curl -f http://localhost:8096/health  # Jellyfin
curl -f http://localhost:5432/        # PostgreSQL
curl -f http://localhost:6379/         # Redis

# Verify data integrity
./scripts/backup.sh --verify
```

## Single Service Recovery

### Example: Restore Jellyfin

```bash
# Stop Jellyfin
docker compose -f stacks/media/docker-compose.yml stop jellyfin

# Restore volume
docker volume rm jellyfin-config 2>/dev/null || true
docker volume create jellyfin-config
docker run --rm \
  -v jellyfin-config:/data \
  -v /path/to/backups:/backup \
  alpine \
  tar -xzf /backup/vol_jellyfin-config.tar.gz -C /data

# Start Jellyfin
docker compose -f stacks/media/docker-compose.yml up -d jellyfin
```

## Backup Verification

Regularly verify backup integrity:

```bash
# Verify all backups
./scripts/backup.sh --verify

# Test restore to temporary location
./scripts/backup.sh --restore <backup_id> --test
```

## Pre-recovery Checklist

- [ ] Confirm backup files are accessible
- [ ] Verify backup file checksums
- [ ] Document current system state
- [ ] Notify users of maintenance window
- [ ] Allocate sufficient recovery time
- [ ] Prepare rollback plan

## Post-recovery Checklist

- [ ] All services healthy
- [ ] Data integrity verified
- [ ] User access restored
- [ ] Notifications working
- [ ] Monitoring alerts configured
- [ ] Backup schedule verified
