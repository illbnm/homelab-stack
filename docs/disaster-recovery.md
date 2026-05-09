# Disaster Recovery Guide

Complete recovery procedure for HomeLab Stack on a fresh host.

## Recovery Time Objective (RTO)

| Phase | Component | Estimated Time |
|-------|-----------|---------------|
| 1 | Base Infrastructure (Traefik, Portainer) | 5 min |
| 2 | Databases (PostgreSQL, Redis, MariaDB) | 10 min |
| 3 | SSO (Authentik) | 15 min |
| 4 | All other stacks | 15 min |
| **Total** | | **~45 min** |

## Prerequisites

- Fresh Ubuntu 22.04+ or Debian 12+ host
- Docker + Docker Compose installed
- Backup files accessible (local, S3, B2, or R2)
- Domain DNS configured

## Recovery Procedure

### Step 0: Prepare Host

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Clone repo (or restore from backup)
git clone https://github.com/YOUR_USER/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack

# Restore .env
cp /path/to/backup/configs/.env .env
```

### Step 1: Base Infrastructure

```bash
cd stacks/base
docker compose up -d
# Wait for Traefik + Portainer to be healthy
docker compose ps
```

### Step 2: Databases

```bash
# If using shared databases stack:
docker compose -f stacks/databases/docker-compose.yml up -d
# Wait for health checks
```

### Step 3: Restore Volumes & Databases

```bash
# If backup is local:
./scripts/backup.sh --restore LATEST_BACKUP_ID

# If backup is on S3:
aws s3 sync s3://homelab-backups/LATEST/ /opt/homelab-backups/LATEST/
./scripts/backup.sh --restore LATEST

# Verify restoration
./scripts/backup.sh --verify
```

### Step 4: SSO (Authentik)

```bash
cd stacks/sso
docker compose up -d
# Wait for Authentik to be healthy (~60s)
docker compose ps
# Verify: curl https://auth.DOMAIN/-/health/ready/
```

### Step 5: Remaining Stacks

Start stacks in this order (dependencies resolved):

```bash
# Start all remaining stacks
for stack in monitoring media storage productivity ai home-automation notifications; do
  cd stacks/$stack
  docker compose up -d
  cd ../..
done
```

Or use the stack manager:

```bash
./scripts/stack-manager.sh start all
```

### Step 6: Verification Checklist

- [ ] Traefik Dashboard accessible
- [ ] Authentik login works
- [ ] Grafana shows data
- [ ] Nextcloud files accessible
- [ ] Gitea repositories present
- [ ] Jellyfin media library intact
- [ ] Notifications test: `./scripts/notify.sh test "DR Test" "Recovery complete"`
- [ ] All containers healthy: `docker compose ps | grep -v healthy`

## Backup Schedule

### Cron (simple)

```bash
# /etc/cron.d/homelab-backup
0 2 * * * root /opt/homelab-stack/scripts/backup.sh --target all
```

### Systemd Timer (recommended)

```ini
# /etc/systemd/system/homelab-backup.service
[Unit]
Description=HomeLab Weekly Backup
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/homelab-stack/scripts/backup.sh --target all
User=root
```

```ini
# /etc/systemd/system/homelab-backup.timer
[Unit]
Description=HomeLab Weekly Backup Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now homelab-backup.timer
```

## Backup Target Configuration

### Local

```bash
BACKUP_TARGET=local
BACKUP_DIR=/mnt/external-drive/homelab-backups
```

### S3/MinIO

```bash
BACKUP_TARGET=s3
S3_ENDPOINT=https://s3.amazonaws.com
S3_BUCKET=homelab-backups
S3_ACCESS_KEY=AKIA...
S3_SECRET_KEY=...
```

### Backblaze B2

```bash
BACKUP_TARGET=b2
B2_APPLICATION_KEY_ID=...
B2_APPLICATION_KEY=...
B2_BUCKET=homelab-backups
```

### Cloudflare R2

```bash
BACKUP_TARGET=r2
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
R2_BUCKET=homelab-backups
```
