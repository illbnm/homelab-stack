# Backup & Disaster Recovery Stack

This stack provides a complete 3-2-1 backup solution: Duplicati for encrypted cloud backups and Restic REST Server for local backups.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Restic REST Server | `restic/rest-server:0.13.0` | 8000 (internal) | Local backup repository |
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | Encrypted cloud backup GUI |

## Quick Start

### 1. Configure Environment

```bash
cd stacks/backup
cp .env.example .env
nano .env
```

Required settings:
- `RESTIC_PASSWORD` — Strong password for repository encryption
- `BACKUP_TARGET` — Choose: `local`, `s3`, `b2`, `sftp`, `r2`
- Cloud credentials (if using cloud target)

### 2. Deploy Stack

```bash
docker compose up -d
```

### 3. Verify Services

```bash
docker compose ps
# Both services should show "healthy"
```

## Backup Script Usage

The main backup script is located at `scripts/backup.sh`:

```bash
# Backup all stacks
./scripts/backup.sh --target all

# Backup only media stack
./scripts/backup.sh --target media

# Dry run (show what would be backed up)
./scripts/backup.sh --target all --dry-run

# List all backups
./scripts/backup.sh --list

# Verify backup integrity
./scripts/backup.sh --verify

# Restore from backup
./scripts/backup.sh --restore <backup_id> --target /path/to/restore
```

## Scheduled Backups

Install systemd timer for daily backups at 2:00 AM:

```bash
sudo cp stacks/backup/systemd/backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable backup.timer
sudo systemctl start backup.timer
```

## Backup Targets

### Local (default)
- Stores backups in Restic REST Server
- Path: `/opt/homelab-backups`

### S3 / MinIO
Set in `.env`:
```bash
BACKUP_TARGET=s3
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET_NAME=your_bucket
S3_ENDPOINT=http://minio.example.com:9000  # For MinIO
```

### Backblaze B2
```bash
BACKUP_TARGET=b2
B2_ACCOUNT_ID=your_id
B2_ACCOUNT_KEY=your_key
B2_BUCKET_NAME=your_bucket
```

### Cloudflare R2
```bash
BACKUP_TARGET=r2
R2_ACCESS_KEY_ID=your_key
R2_SECRET_ACCESS_KEY=your_secret
R2_ENDPOINT=https://your-account.r2.cloudflarestorage.com
R2_BUCKET_NAME=your_bucket
```

### SFTP
```bash
BACKUP_TARGET=sftp
SFTP_USER=user
SFTP_PASSWORD=password
SFTP_HOST=backup.server.com
SFTP_PATH=/backups/homelab
```

## Notifications

Backup notifications are sent via ntfy:

```bash
NTFY_SERVER=https://ntfy.sh
NTFY_TOPIC=homelab-backups
```

Subscribe to notifications:
```bash
# Web: https://ntfy.sh/homelab-backups
# CLI: ntfy subscribe homelab-backups
```

## Duplicati Web UI

Access Duplicati for manual cloud backup configuration:
- URL: `https://duplicati.yourdomain.com`
- Port: 8200

Use Duplicati to configure additional cloud backup jobs with encryption.

## Disaster Recovery

See [docs/disaster-recovery.md](../../docs/disaster-recovery.md) for complete recovery procedures.

## 3-2-1 Strategy

This stack implements the 3-2-1 backup strategy:
- **3 copies**: Live data + Restic repo + Duplicati cloud
- **2 media types**: Local disk + Cloud storage
- **1 offsite**: Cloud backup (S3/B2/R2/SFTP)