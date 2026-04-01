# Backup Stack

> Duplicati + Restic REST Server — 3-2-1 Backup Strategy

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| **Duplicati** | `lscr.io/linuxserver/duplicati:2.0.11` | `backup.${DOMAIN}` | Encrypted cloud backup with deduplication (Web UI) |
| **Restic REST Server** | `restic/rest-server:0.13.0` | `restic.${DOMAIN}` | Self-hosted REST API for restic backup client |

## Quick Start

```bash
# Copy environment config
cp .env.example stacks/backup/.env
# Edit stacks/backup/.env with your values

# Start backup stack
cd stacks/backup
docker compose up -d

# Initialize Restic repository (one-time)
export RESTIC_PASSWORD="your-strong-password"
docker run --rm \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  -v $(pwd)/data/restic:/data \
  restic/restic:0.17 \
  --repo /data init
```

## 3-2-1 Backup Strategy

```
Source Data
    ├── Duplicati ──────────────────→ Cloud (S3/B2/R2/GCS)
    │   (AES-256 encrypted, deduplicated)
    │
    └── scripts/backup.sh ──→ Restic REST Server ──→ MinIO/S3 (offsite)
        (incremental, deduplicated)
```

## Duplicati Setup

1. Open `https://backup.${DOMAIN}`
2. Add a new backup job:
   - **Source**: `/opt/homelab` (or specific paths)
   - **Destination**: S3/MinIO/B2/SFTP (configure in destination)
   - **Encryption**: AES-256 (enabled by default)
   - **Schedule**: Daily at 02:00
3. Duplicati handles deduplication — even small changes only store diffs

## Restic REST Server

Used by `scripts/backup.sh` as a backup backend:

```bash
# In config/.env
BACKUP_TARGET=restic
RESTIC_REST_URL=http://restic.${DOMAIN}
RESTIC_REST_PASSWORD=your-restic-password
```

## Backup Script

The main backup script at `scripts/backup.sh` supports:

```bash
# Full backup (configs + volumes + DB + media)
./scripts/backup.sh --target all

# Specific targets
./scripts/backup.sh --target database
./scripts/backup.sh --target media

# Different backends
./scripts/backup.sh --target all --dest s3
./scripts/backup.sh --target all --dest b2
./scripts/backup.sh --target all --dest local

# Dry run
./scripts/backup.sh --target all --dry-run

# List backups
./scripts/backup.sh --list

# Verify backup
./scripts/backup.sh --verify --backup-id 20260328_020000

# Restore
./scripts/backup.sh --restore --target all --backup-id 20260328_020000
```

## Scheduled Backups

Add to crontab (`crontab -e`):

```cron
# Daily full backup at 02:00 AM
0 2 * * * BACKUP_TARGET=local /opt/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1

# Hourly DB backup
15 * * * * /opt/homelab-stack/scripts/backup.sh --target database --dest s3 >> /var/log/homelab-db-backup.log 2>&1
```

## Health Checks

```bash
# Check Duplicati
curl -sf http://localhost:8200/

# Check Restic REST Server
curl -sf http://localhost:8080/

# Check Docker containers
docker ps | grep -E "duplicati|restic-rest"
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_DIR` | `/opt/homelab-backups` | Base backup directory |
| `BACKUP_RETENTION_DAYS` | `7` | Days to keep local backups |
| `BACKUP_TARGET` | `local` | Default backup backend |
| `RESTIC_REST_PASSWORD` | _(required)_ | Password for Restic repository |
| `S3_BUCKET` | `homelab-backups` | S3/MinIO bucket name |
| `B2_BUCKET` | `homelab-backups` | Backblaze B2 bucket name |
