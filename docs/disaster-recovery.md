# Disaster Recovery Guide

Complete procedures for recovering HomeLab from backup on a fresh host.

## Strategy: 3-2-1

- **3** copies of data (local + remote + Docker volumes)
- **2** different media types (disk + cloud/SFTP)
- **1** offsite copy (S3/B2/SFTP/R2)

## Recovery Time Objectives

| Stack | RTO | Priority | Dependencies |
|-------|-----|----------|-------------|
| Base (Traefik, Portainer) | 5 min | 1 — First | Docker, networks |
| Databases (PG, Redis, MariaDB) | 10 min | 2 — Critical | Base stack |
| SSO (Authentik) | 10 min | 3 — Auth | Databases |
| Storage (Nextcloud, MinIO) | 15 min | 4 | Databases, SSO |
| Productivity (Gitea, Vaultwarden) | 10 min | 5 | Databases, SSO |
| Monitoring (Prometheus, Grafana) | 10 min | 6 | Databases |
| Media (Jellyfin, *arr) | 15 min | 7 | Storage |
| AI (Ollama, Open WebUI) | 10 min | 8 | None (standalone) |
| Notifications (ntfy, Gotify) | 5 min | 9 | Base |
| Home Automation (HA, Node-RED) | 10 min | 10 | Databases |
| **Total RTO** | **~60 min** | | |

## Prerequisites

Fresh host with:
- Ubuntu 22.04+ / Debian 12+
- Docker Engine 24+ and Compose v2
- 4GB+ RAM, 50GB+ storage
- Network access to backup source (S3/B2/SFTP)

## Full Recovery Procedure

### Phase 0: Prepare Host

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker

# Clone repo
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab
cd /opt/homelab

# Install dependencies
sudo apt-get update && sudo apt-get install -y jq curl openssl gzip
```

### Phase 1: Retrieve Backup

```bash
# Set backup config
export BACKUP_TARGET=s3          # or b2, sftp, local
export S3_ENDPOINT=https://...
export S3_BUCKET=homelab-backups
export S3_ACCESS_KEY=...
export S3_SECRET_KEY=...

# List available backups
./scripts/backup.sh --list

# Download and verify
./scripts/backup.sh --restore 20260318_020000
# If encrypted, set BACKUP_ENCRYPTION_KEY first
```

### Phase 2: Restore Base Stack (Priority 1)

```bash
# Create required networks
docker network create proxy
docker network create databases

# Restore configs (already done by --restore)
# Start base stack
docker compose -f stacks/base/docker-compose.yml up -d

# Verify
docker compose -f stacks/base/docker-compose.yml ps
curl -sf http://localhost:8080/api/rawdata  # Traefik API
curl -sf http://localhost:9443              # Portainer
```

### Phase 3: Restore Databases (Priority 2)

```bash
# Start database containers
docker compose -f stacks/databases/docker-compose.yml up -d

# Wait for healthy
for i in $(seq 1 60); do
  health=$(docker inspect --format='{{.State.Health.Status}}' homelab-postgres 2>/dev/null)
  [ "$health" = "healthy" ] && break
  sleep 1
done

# Restore PostgreSQL (already loaded by --restore, but manual if needed)
gunzip -c /opt/homelab-backups/BACKUP_ID/postgresql_all.sql.gz | \
  docker exec -i homelab-postgres psql -U postgres

# Restore MariaDB
gunzip -c /opt/homelab-backups/BACKUP_ID/mariadb_all.sql.gz | \
  docker exec -i homelab-mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD"

# Restore Redis
docker cp /opt/homelab-backups/BACKUP_ID/redis_dump.rdb homelab-redis:/data/dump.rdb
docker restart homelab-redis

# Verify
docker exec homelab-postgres pg_isready -U postgres
docker exec homelab-redis redis-cli PING
docker exec homelab-mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES"
```

### Phase 4: Restore SSO (Priority 3)

```bash
docker compose -f stacks/sso/docker-compose.yml up -d

# Verify Authentik
curl -sf http://localhost:9000/api/v3/root/config/ | jq .version_current
```

### Phase 5: Restore Remaining Stacks

```bash
# Storage
docker compose -f stacks/storage/docker-compose.yml up -d

# Productivity
docker compose -f stacks/productivity/docker-compose.yml up -d

# Monitoring
docker compose -f stacks/monitoring/docker-compose.yml up -d

# Media
docker compose -f stacks/media/docker-compose.yml up -d

# AI
docker compose -f stacks/ai/docker-compose.yml up -d

# Notifications
docker compose -f stacks/notifications/docker-compose.yml up -d

# Home Automation
docker compose -f stacks/home-automation/docker-compose.yml up -d
```

### Phase 6: Start Backup Stack

```bash
docker compose -f stacks/backup/docker-compose.yml up -d

# Set up scheduled backups
sudo cp stacks/backup/config/homelab-backup.service /etc/systemd/system/
sudo cp stacks/backup/config/homelab-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer
```

## Verification Checklist

After completing recovery, verify each item:

- [ ] **Traefik** — Dashboard accessible, SSL certificates valid
- [ ] **Portainer** — Web UI accessible, all stacks visible
- [ ] **PostgreSQL** — All databases present (`\l` shows nextcloud, gitea, outline, etc.)
- [ ] **Redis** — PING returns PONG, data keys present
- [ ] **MariaDB** — All databases present (`SHOW DATABASES`)
- [ ] **Authentik** — Login works, OIDC providers configured
- [ ] **Nextcloud** — Login works, files present
- [ ] **MinIO** — Buckets exist, files accessible
- [ ] **Gitea** — Repositories present, login works
- [ ] **Vaultwarden** — Vault accessible, entries present
- [ ] **Grafana** — Dashboards loaded, data sources connected
- [ ] **Prometheus** — Targets UP, metrics flowing
- [ ] **Media services** — Libraries present, downloads resume
- [ ] **Backup timer** — `systemctl status homelab-backup.timer` shows active

## Backup Configuration Reference

### Environment Variables

```bash
# Storage backend
BACKUP_TARGET=local          # local | s3 | b2 | sftp | r2

# Local
BACKUP_DIR=/opt/homelab-backups
BACKUP_RETENTION_DAYS=7

# Encryption (optional)
BACKUP_ENCRYPTION_KEY=your-secret-passphrase

# S3 / MinIO / R2
S3_ENDPOINT=https://s3.amazonaws.com
S3_BUCKET=homelab-backups
S3_ACCESS_KEY=AKIA...
S3_SECRET_KEY=secret...

# Backblaze B2
B2_ACCOUNT_ID=your-account-id
B2_APP_KEY=your-app-key
B2_BUCKET=homelab-backups

# SFTP
SFTP_HOST=backup.example.com
SFTP_USER=backup
SFTP_PATH=/backups/homelab
SFTP_KEY=/root/.ssh/backup_key

# Notifications
NTFY_URL=https://ntfy.sh/homelab-backup
GOTIFY_URL=https://gotify.example.com
GOTIFY_TOKEN=your-token
```

### Scheduled Backup

**Option A: crontab**
```bash
sudo cp stacks/backup/config/backup.cron /etc/cron.d/homelab-backup
```

**Option B: systemd timer** (recommended)
```bash
sudo cp stacks/backup/config/homelab-backup.service /etc/systemd/system/
sudo cp stacks/backup/config/homelab-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer

# Check timer status
systemctl list-timers homelab-backup.timer
```

### Manual Operations

```bash
# Full backup
./scripts/backup.sh --target all

# Single stack backup
./scripts/backup.sh --target databases

# Dry run (preview)
./scripts/backup.sh --target all --dry-run

# Encrypted backup
./scripts/backup.sh --target all --encrypt

# List backups
./scripts/backup.sh --list

# Verify latest backup
./scripts/backup.sh --verify

# Verify specific backup
./scripts/backup.sh --verify 20260318_020000

# Restore
./scripts/backup.sh --restore 20260318_020000
```

## Troubleshooting

### Backup fails with "Permission denied"
```bash
# Ensure backup dir is writable
sudo mkdir -p /opt/homelab-backups
sudo chown $(whoami) /opt/homelab-backups
```

### S3 upload fails
```bash
# Test S3 connectivity
aws s3 ls s3://$S3_BUCKET --endpoint-url $S3_ENDPOINT

# Check credentials
echo $S3_ACCESS_KEY | head -c 4
```

### Encrypted restore fails
```bash
# Verify key matches
export BACKUP_ENCRYPTION_KEY=your-key
openssl enc -aes-256-cbc -d -salt -pbkdf2 -in file.enc -out /dev/null -pass pass:$BACKUP_ENCRYPTION_KEY
```

### Database restore has warnings
PostgreSQL restore may show warnings like "role already exists" — this is normal and safe. The data is still restored correctly.

### Timer not running
```bash
systemctl status homelab-backup.timer
journalctl -u homelab-backup.service --since today
```
