# 🔄 Disaster Recovery Guide

> Complete disaster recovery procedures for the homelab-stack.

---

## Table of Contents

1. [Recovery Overview](#recovery-overview)
2. [Prerequisites](#prerequisites)
3. [Full Recovery Procedure](#full-recovery-procedure)
4. [Partial Recovery](#partial-recovery)
5. [Verification Checklist](#verification-checklist)
6. [RTO Estimates](#rto-estimates)
7. [Common Failure Scenarios](#common-failure-scenarios)

---

## Recovery Overview

### Recovery Order (Critical Path)

```
1. Base Infrastructure  → Traefik, Portainer, Networks
2. Databases            → PostgreSQL, MariaDB, Redis
3. SSO                  → Authentik (all services depend on it)
4. Storage              → MinIO, Nextcloud
5. Monitoring           → Grafana, Prometheus, Loki
6. Media                → Jellyfin, Sonarr, Radarr
7. Productivity         → Gitea, Outline
8. AI                   → Ollama, Open-WebUI
9. Notifications        → Gotify, ntfy
10. Network             → WireGuard, AdGuard
```

### What Gets Backed Up

| Category | Content | Frequency |
|----------|---------|-----------|
| Docker volumes | Per-stack volume data | Daily |
| Configs | `config/`, `stacks/`, `scripts/` | Daily |
| .env files | All environment variables | Daily |
| Databases | pg_dumpall, mysqldump, Redis RDB | Daily |
| Encryption | AES-256-CBC (optional) | On backup |

---

## Prerequisites

### New Host Requirements

- **OS**: Ubuntu 22.04+ / Debian 12+
- **Docker**: 24.0+
- **Docker Compose**: v2.20+
- **Disk**: Minimum 50GB free (more for media)
- **Network**: Public IP or domain with DNS
- **Backup access**: Access to backup storage (local/S3/B2/SFTP/R2)

### Quick Install (Ubuntu)

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Clone repo
git clone <your-repo> /opt/homelab-stack
cd /opt/homelab-stack

# Setup
cp .env.example config/.env
${EDITOR} config/.env   # Fill in all values
```

---

## Full Recovery Procedure

### Step 1: Restore Configs

```bash
# If you have a backup archive
BACKUP_ID="<backup_id>"
tar xzf /opt/homelab-backups/${BACKUP_ID}.tar.gz -C /opt/homelab-backups/
cp /opt/homelab-backups/${BACKUP_ID}/dot-env.bak /opt/homelab-stack/config/.env
tar xzf /opt/homelab-backups/${BACKUP_ID}/configs.tar.gz -C /opt/homelab-stack/
```

### Step 2: Create Networks

```bash
docker network create proxy
docker network create databases
docker network create monitoring
docker network create media
```

### Step 3: Start Base Stack

```bash
cd /opt/homelab-stack/stacks/base
docker compose up -d
```

**Verify**: `https://traefik.yourdomain.com` and `https://portainer.yourdomain.com` are accessible.

### Step 4: Start Databases

```bash
cd /opt/homelab-stack/stacks/databases
docker compose up -d
```

**Wait** until containers are healthy (~30s).

### Step 5: Restore Database Contents

```bash
BACKUP_DIR="/opt/homelab-backups/<backup_id>"

# PostgreSQL
docker exec -i homelab-postgres psql -U postgres < ${BACKUP_DIR}/pg_homelab-postgres_all.sql

# MariaDB
docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" < ${BACKUP_DIR}/mysql_homelab-mariadb_all.sql

# Redis
docker cp ${BACKUP_DIR}/redis_homelab-redis.rdb homelab-redis:/data/dump.rdb
docker restart homelab-redis
```

### Step 6: Restore Volumes & Start Remaining Stacks

For each stack, restore volumes then start:

```bash
# Restore a specific volume
VOLUME_NAME="<volume_name>"
docker volume create "$VOLUME_NAME"
docker run --rm \
  -v "${VOLUME_NAME}:/data" \
  -v "/opt/homelab-backups/<backup_id>:/backup:ro" \
  alpine:3.19 \
  tar xzf "/backup/vol_${VOLUME_NAME}.tar.gz" -C /data

# Start stacks in order
for stack in sso storage monitoring media productivity ai notifications network; do
  cd /opt/homelab-stack/stacks/$stack
  docker compose up -d
  echo "Started $stack, waiting..."
  sleep 15
done
```

---

## Partial Recovery

### Single Stack Recovery

```bash
# Example: restore only media stack
BACKUP_ID="<backup_id>"
cd /opt/homelab-stack
./scripts/backup.sh --restore "$BACKUP_ID"

# Then selectively restore volumes:
for vol in jellyfin-data sonarr-data radarr-data qbittorrent-data bazarr-data; do
  docker volume create "$vol" 2>/dev/null || true
  docker run --rm \
    -v "${vol}:/data" \
    -v "/opt/homelab-backups/${BACKUP_ID}:/backup:ro" \
    alpine:3.19 \
    tar xzf "/backup/vol_${vol}.tar.gz" -C /data
done

cd stacks/media && docker compose up -d
```

### Using backup.sh

```bash
# List available backups
./scripts/backup.sh --list

# Verify a backup
./scripts/backup.sh --verify <backup_id>

# Restore (restores configs + volumes + databases)
./scripts/backup.sh --restore <backup_id>

# Dry-run before backing up
./scripts/backup.sh --target media --dry-run

# Backup specific stack
./scripts/backup.sh --target media
```

---

## Verification Checklist

After recovery, verify each component:

- [ ] **Traefik**: Dashboard accessible, HTTPS working
- [ ] **Portainer**: Login works, all containers listed
- [ ] **Authentik**: SSO login works, applications listed
- [ ] **PostgreSQL**: `docker exec homelab-postgres psql -U postgres -c '\l'`
- [ ] **Redis**: `docker exec homelab-redis redis-cli ping` → `PONG`
- [ ] **MariaDB**: `docker exec homelab-mariadb mysql -u root -p -e 'SHOW DATABASES;'`
- [ ] **MinIO**: Console accessible, buckets present
- [ ] **Nextcloud**: Login works, files visible
- [ ] **Grafana**: Dashboard loads, data sources connected
- [ ] **Gitea**: Repos visible, push/pull works
- [ ] **Jellyfin**: Library loads, playback works
- [ ] **WireGuard**: VPN connection works
- [ ] **Notifications**: Test via `./scripts/notify.sh test "Test" "Recovery verified"`

---

## RTO Estimates

| Scenario | Target RTO | Typical Time |
|----------|-----------|-------------|
| Single container crash | 2 min | `docker compose restart <service>` |
| Single stack failure | 10 min | Restore volumes + `docker compose up -d` |
| Full host failure (with backup) | 1 hour | Fresh install + restore all |
| Full host failure (no backup) | 2-4 hours | Rebuild from .env.example + reconfigure |
| Database corruption | 15 min | Restore from SQL dump |
| Ransomware (encrypted backups) | N/A | Rebuild from scratch |

---

## Common Failure Scenarios

### 1. Docker Daemon Won't Start

```bash
journalctl -u docker --no-pager -n 50
# Common fixes:
sudo systemctl restart docker
# Check disk space:
df -h
# Clean if needed:
docker system prune -af
```

### 2. Volume Corruption

```bash
# Check which containers use a volume
docker ps -q | xargs docker inspect | grep -B5 "<volume_name>"

# Restore from backup
./scripts/backup.sh --restore <backup_id>
# Then manually restore the specific volume
```

### 3. Database Won't Start

```bash
# Check logs
docker logs homelab-postgres --tail 50

# Common: corrupted WAL
docker exec homelab-postgres pg_resetwal -f /var/lib/postgresql/data

# If unrecoverable, restore from SQL dump
```

### 4. Traefik / SSL Issues

```bash
# Check cert status
docker exec traefik ls /letsencrypt/
# Force renewal
docker exec traefik traefik certs renew
# If acme.json is corrupted, delete it and restart (certs will auto-renew)
```

### 5. Lost .env File

```bash
# Restore from backup
BACKUP_ID=$(ls /opt/homelab-backups/ | sort | tail -1)
cp /opt/homelab-backups/${BACKUP_ID}/dot-env.bak /opt/homelab-stack/config/.env

# Or rebuild from .env.example
cp .env.example config/.env
# Re-fill sensitive values from password manager
```

### 6. Disk Full

```bash
# Identify large consumers
docker system df
du -sh /opt/homelab-backups/* | sort -h
du -sh /opt/homelab/media/*

# Clean old backups
./scripts/backup.sh --target all  # This triggers cleanup

# Clean Docker
docker system prune -af --volumes  # ⚠️ Removes unused volumes!
```

---

## Emergency Contacts & Resources

- **Backup location**: Configured via `BACKUP_TARGET` in `.env`
- **Backup script**: `scripts/backup.sh`
- **Notification**: `scripts/notify.sh`
- **Repo**: `<your-git-repo>`

---

_Last updated: 2026-03-18_
