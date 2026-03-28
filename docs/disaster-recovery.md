# Disaster Recovery (DR) Guide

> **Bounty #12** — Backup & DR | $150 USDT  
> Homelab Backup System: `scripts/backup.sh` | Notification: `scripts/notify.sh`

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Backup Strategy](#backup-strategy)
3. [Restore Procedures](#restore-procedures)
4. [Service Restore Order](#service-restore-order)
5. [RTO / RPO Estimates](#rto--rpo-estimates)
6. [Verification Checklist](#verification-checklist)
7. [Common Scenarios](#common-scenarios)

---

## Architecture Overview

### Backup Targets

| Target | Backend Config Env | Description |
|--------|-------------------|-------------|
| `local` | `BACKUP_DIR` | NFS mount or fast local disk |
| `s3` / MinIO | `S3_*` | S3-compatible store (MinIO on-prem or cloud) |
| `b2` | `B2_*` | Backblaze B2 |
| `sftp` | `SFTP_*` | Remote SFTP server |
| `restic` | `RESTIC_REST_*` | [Restic REST Server](https://github.com/restic/rest-server) |

### What Gets Backed Up

| Category | Target Type | Contents |
|----------|-------------|----------|
| **Configs** | `all` | `config/`, `stacks/`, `scripts/`, `homelab.md` |
| **Volumes** | `all` | All Docker named volumes (excludes anonymous) |
| **Databases** | `all` | PostgreSQL, MariaDB, Redis (SQL dumps + RDB) |
| **Media** | `media` | `$MEDIA_ROOT` ( Plex/jellyfin data, downloads ) |

---

## Backup Strategy

### Running a Backup

```bash
# Full backup (configs + volumes + DB + media → default local)
./scripts/backup.sh --target all

# Target-specific
./scripts/backup.sh --target database
./scripts/backup.sh --target media

# Push to specific backend
BACKUP_TARGET=s3 ./scripts/backup.sh --target all
./scripts/backup.sh --target all --dest b2

# Dry run
./scripts/backup.sh --target all --dry-run

# List available backups
./scripts/backup.sh --list --dest s3

# Verify backup integrity
./scripts/backup.sh --verify --backup-id 20260323_120000
./scripts/backup.sh --verify --dest restic --backup-id latest
```

### Schedule Recommendation

Add to crontab (`crontab -e`):

```cron
# Daily full backup at 02:00 AM
0 2 * * * BACKUP_TARGET=local /opt/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1

# Hourly DB backup
15 * * * * /opt/homelab-stack/scripts/backup.sh --target database --dest s3 >> /var/log/homelab-db-backup.log 2>&1

# Weekly media backup (Sundays)
0 3 * * 0 /opt/homelab-stack/scripts/backup.sh --target media --dest b2 >> /var/log/homelab-media-backup.log 2>&1
```

### Retention

- **Local/S3/B2/SFTP**: `BACKUP_RETENTION_DAYS=7` (default 7 days, tune for your storage)
- **Restic**: `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`

### Environment Variables

Add to `config/.env`:

```bash
# Backup destination (local | s3 | b2 | sftp | restic)
BACKUP_TARGET=local

# Local
BACKUP_DIR=/opt/homelab-backups
BACKUP_RETENTION_DAYS=7

# S3 / MinIO
S3_BUCKET=homelab-backups
S3_ENDPOINT=https://s3.yourdomain.com
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
S3_PREFIX=backups

# Backblaze B2
B2_ACCOUNT_ID=your-account-id
B2_ACCOUNT_KEY=your-account-key
B2_BUCKET=homelab-backups
B2_PREFIX=backups

# SFTP
SFTP_HOST=backup.yourdomain.com
SFTP_PORT=22
SFTP_USER=backup
SFTP_KEY=/root/.ssh/backup_key
SFTP_REMOTE_PATH=/backups

# Restic REST Server
RESTIC_REST_URL=http://localhost:8080
RESTIC_REST_PASSWORD=changeme

# ntfy notifications
NTFY_URL=http://ntfy.yourdomain.com
NTFY_TOPIC=homelab-backups
NTFY_AUTH=username:apitoken
```

---

## Restore Procedures

### Full System Restore (New Host)

#### Prerequisites on New Host

1. Install Docker & Docker Compose
2. Clone the repository:
   ```bash
   git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
   cd /opt/homelab-stack
   ```
3. Copy and configure environment:
   ```bash
   cp .env.example config/.env
   # edit config/.env with your values
   ```
4. Install dependencies:
   ```bash
   ./scripts/check-deps.sh
   ```
5. Restore configs from backup:
   ```bash
   ./scripts/backup.sh --restore --target all --backup-id <id> --dest <backend>
   ```

#### Step-by-Step Restore Order

```
1. BASE          → docker network create, base volumes
2. DATABASES      → postgres, mariadb, redis
3. SSO            → authentik (required by many apps)
4. STORAGE        → MinIO, filebrowser
5. NOTIFICATIONS  → ntfy, apprise (so you get alerts)
6. PRODUCTIVITY   → outline, gitea, vaultwarden
7. MEDIA          → plex/jellyfin, sonarr/radarr (if media stack)
8. MONITORING     → grafana, prometheus
9. NETWORK        → wireguard, cloudflared
```

#### Restore Databases

```bash
# Stop services first
cd /opt/homelab-stack/stacks/databases
docker compose down

# Restore from backup
./scripts/backup.sh --restore --target database --backup-id 20260323_020000 --dest local

# Restart
docker compose up -d
```

#### Restore a Docker Volume

```bash
# Identify the volume name
docker volume ls | grep myapp

# Restore from backup archive
BACKUP_ID=20260323_020000
BACKUP_DIR=/opt/homelab-backups
STAGING=$BACKUP_DIR/$BACKUP_ID/volumes

docker run --rm \
  -v myapp_data:/data \
  -v $STAGING:/backup:ro \
  alpine:3.19 \
  sh -c "rm -rf /data/* && tar xzf /backup/vol_myapp_data.tar.gz -C /data"
```

#### Restore Media Files

```bash
./scripts/backup.sh --restore --target media --backup-id <id> --dest local
# or
rsync -av /opt/homelab-backups/<id>/media/ /opt/homelab/media/
```

#### Restore Configs Only

```bash
BACKUP_ID=20260323_020000
tar xzf /opt/homelab-backups/$BACKUP_ID/configs.tar.gz -C /opt/homelab-stack/
```

---

## Service Restore Order

### Dependency Graph

```
Base networks/volumes
       │
       ▼
  ┌─────────┐    ┌───────────┐
  │ DATABASES│    │   SSO     │
  │postgres  │    │ authentik │
  │mariadb   │    └─────┬─────┘
  │redis     │          │
  └────┬────┘          │
       │               │
       ▼               ▼
  ┌─────────────────────────┐
  │     STORAGE / MinIO     │
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │   NOTIFICATIONS (ntfy)  │
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │   PRODUCTIVITY APPS     │
  │  (gitea, outline, etc)  │
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │        MEDIA            │
  │  (plex, sonarr, radarr) │
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │     MONITORING          │
  │  (grafana, prometheus)  │
  └─────────────────────────┘
```

### Restore Each Layer

```bash
# 1. Base
cd /opt/homelab-stack/stacks/base && docker compose up -d

# 2. Databases
cd /opt/homelab-stack/stacks/databases && docker compose up -d
sleep 10  # wait for postgres

# 3. SSO
cd /opt/homelab-stack/stacks/sso && docker compose up -d
sleep 15  # authentik takes time

# 4. Storage
cd /opt/homelab-stack/stacks/storage && docker compose up -d

# 5. Notifications
cd /opt/homelab-stack/stacks/notifications && docker compose up -d

# 6. Productivity
cd /opt/homelab-stack/stacks/productivity && docker compose up -d

# 7. Media
cd /opt/homelab-stack/stacks/media && docker compose up -d

# 8. Monitoring
cd /opt/homelab-stack/stacks/monitoring && docker compose up -d
```

---

## RTO / RPO Estimates

| Service | RTO (approx) | RPO | Notes |
|---------|-------------|-----|-------|
| Base (networks) | 2–5 min | — | Always needed first |
| PostgreSQL (small DB < 10GB) | 5–15 min | 1–24h | pg_dump restore time |
| MariaDB (small DB < 10GB) | 5–15 min | 1–24h | mysqldump restore |
| Redis | 1–3 min | 1–24h | RDB file copy |
| Authentik (SSO) | 5–10 min | 1–24h | Config + secret restore |
| MinIO / Object storage | 10–30 min | 1–24h | Depends on data size |
| Nextcloud | 10–20 min | 1–24h | Config + volume restore |
| Plex/Media | 20–60 min | 1–24h | Large volume; use rsync |
| Grafana | 5–10 min | 1–24h | SQLite/Postgres dump |
| **Full Homelab (typical)** | **30–120 min** | **~4h** | With scripts + good network |

**Ways to reduce RTO:**
- Keep a cold spare VM with Docker pre-installed
- Use ZFS `zfs send/receive` for volume-level incremental replication
- Use restic with `--read-concurrency 4` for faster restores
- Pre-stage the most recent backup on local disk

---

## Verification Checklist

Run after every restore:

```bash
# ── System ────────────────────────────────────────────────────────────────────
docker ps                                  # all containers running?
docker network ls                          # base networks exist?
docker volume ls                            # all named volumes present?

# ── Databases ─────────────────────────────────────────────────────────────────
docker exec homelab-postgres pg_isready -U postgres   # returns "accepting connections"
docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping  # returns PONG

# Check DB sizes vs backup
docker exec homelab-postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"

# ── Auth / SSO ────────────────────────────────────────────────────────────────
curl -sf https://auth.yourdomain.com/ping             # should return 200
curl -sf https://auth.yourdomain.com/outpost.goog... # should return SAML metadata

# ── Storage ────────────────────────────────────────────────────────────────────
curl -sf http://localhost:9000/minio/health/live      # MinIO health
mc alias set local http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
mc ls local/homelab-backups/

# ── Notifications ──────────────────────────────────────────────────────────────
curl -sf http://ntfy.yourdomain.com/v1/health           # returns healthy
./scripts/notify.sh success "DR test — notifications working"

# ── Core Apps ──────────────────────────────────────────────────────────────────
curl -sf https://nextcloud.yourdomain.com/status.php   # "installed": true
curl -sf https://grafana.yourdomain.com/api/health     # "ok": true

# ── Backup Verification ───────────────────────────────────────────────────────
./scripts/backup.sh --verify --dest local --backup-id <id>   # all tars + SQL intact
./scripts/backup.sh --verify --dest restic                     # restic check

# ── Media ─────────────────────────────────────────────────────────────────────
du -sh /opt/homelab/media                                  # size matches expectations
ls /opt/homelab/media/                                     # directories present
```

---

## Common Scenarios

### Scenario 1: Single Volume Loss

```bash
# Identify failed volume
docker volume ls
docker inspect <container> | grep -A5 Mounts

# Stop container
docker compose -f stacks/<stack>/docker-compose.yml stop <service>

# Restore from latest backup
BACKUP_ID=$(ls /opt/homelab-backups/ | sort | tail -1)
STAGING=/opt/homelab-backups/$BACKUP_ID/volumes

docker run --rm \
  -v <volume_name>:/data \
  -v $STAGING:/backup:ro \
  alpine:3.19 \
  sh -c "rm -rf /data/* && tar xzf /backup/vol_<volume_name>.tar.gz -C /data"

# Restart
docker compose -f stacks/<stack>/docker-compose.yml start <service>
```

### Scenario 2: Database Corruption

```bash
# Stop the service using the DB
docker compose -f stacks/<stack>/docker-compose.yml stop <app>

# Drop and recreate DB (DANGER: destroys data — only if corruption is severe)
docker exec homelab-postgres psql -U postgres -c "DROP DATABASE IF EXISTS <dbname>; CREATE DATABASE <dbname>;"

# Restore from backup
docker exec homelab-postgres psql -U postgres < /opt/homelab-backups/<id>/databases/postgresql_all.sql

# Restart
docker compose -f stacks/<stack>/docker-compose.yml start <app>
```

### Scenario 3: Full Hardware Failure

1. Provision new host (or restore from snapshot)
2. Install Docker, clone repo, restore `.env`
3. Run full restore: `backup.sh --restore --target all --backup-id <latest> --dest <backend>`
4. Bring up stacks in order (see [Restore Each Layer](#restore-each-layer))
5. Run [Verification Checklist](#verification-checklist)
6. Update DNS if IP changed

### Scenario 4: Accidental Deletion

```bash
# Use backup.sh --list to find the right backup ID
./scripts/backup.sh --list --dest local

# Restore
./scripts/backup.sh --restore --target all --backup-id 20260323_020000 --dest local
```

---

## Restic REST Server Setup

The Restic REST Server provides a lightweight REST API for restic backups.

### Add to `stacks/storage/docker-compose.yml`

```yaml
  restic-rest:
    image: restic/rest-server:0.13
    container_name: restic-rest
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - ${STORAGE_ROOT:-/data/storage}/restic:/data
    environment:
      - RESTIC_PASSWORD_FILE=/secrets/restic_pw
      - OPTIONS=--verbose --prometheus
    entrypoint: /bin/sh -c 'echo "$$RESTIC_PASSWORD" > /secrets/restic_pw && /entrypoint.sh'
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - "traefik.http.routers.restic-rest.rule=Host(`restic.${DOMAIN}`)"
      - traefik.http.routers.restic-rest.entrypoints=websecure
      - traefik.http.routers.restic-rest.tls=true
      - "traefik.http.services.restic-rest.loadbalancer.server.port=8080"
    healthcheck:
      test: [CMD-SHELL, "wget -qO- http://localhost:8080 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
```

### Configure backup.sh for restic

```bash
# In config/.env
BACKUP_TARGET=restic
RESTIC_REST_URL=http://restic.yourdomain.com
RESTIC_REST_PASSWORD=your-restic-password
```

### Init restic repo (one-time)

```bash
docker run --rm \
  -e RESTIC_PASSWORD=your-restic-password \
  restic/restic:0.17 \
  --repo rest:http://restic.yourdomain.com/ \
  init
```

### Verify restic repo

```bash
./scripts/backup.sh --verify --dest restic --backup-id latest
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `./scripts/backup.sh --target all` | Full backup to default (local) |
| `./scripts/backup.sh --target database --dest s3` | DB backup to S3 |
| `./scripts/backup.sh --list` | List available backups |
| `./scripts/backup.sh --verify --backup-id <id>` | Verify backup integrity |
| `./scripts/backup.sh --restore --target all --backup-id <id>` | Full restore |
| `./scripts/notify.sh success "message"` | Send test notification |
