# Backup & DR Stack

Complete backup and disaster recovery solution with Duplicati and Restic.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | Encrypted cloud backup UI |
| Restic REST Server | `restic/rest-server:0.13.0` | Local backup repository |

## Quick Start

```bash
# Copy environment template
cp stacks/backup/.env.example stacks/backup/.env

# Edit .env with your configuration
vim stacks/backup/.env

# Start the stack
docker compose -f stacks/backup/docker-compose.yml up -d

# Check status
docker compose -f stacks/backup/docker-compose.yml ps
```

## Access URLs

| Service | URL |
|---------|-----|
| Duplicati | `https://backup.${DOMAIN}` |
| Restic | `https://restic.${DOMAIN}` |

## Backup Targets

The stack supports multiple backup destinations:

### Local

```env
BACKUP_TARGET=local
BACKUP_DIR=/opt/homelab-backups
```

### S3/MinIO

```env
BACKUP_TARGET=s3
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET_NAME=homelab-backups
S3_ENDPOINT=https://minio.example.com
```

### Backblaze B2

```env
BACKUP_TARGET=b2
B2_ACCOUNT_ID=your_account_id
B2_ACCOUNT_KEY=your_account_key
B2_BUCKET_NAME=homelab-backups
```

### SFTP

```env
BACKUP_TARGET=sftp
SFTP_HOST=backup.example.com
SFTP_PORT=22
SFTP_USERNAME=backup_user
SFTP_PASSWORD=your_password
SFTP_PATH=/backup
```

### Cloudflare R2

```env
BACKUP_TARGET=r2
R2_ACCOUNT_ID=your_account_id
R2_ACCOUNT_KEY=your_account_key
R2_BUCKET_NAME=homelab-backups
R2_PUBLIC_URL=https://restic.example.com
```

## 3-2-1 Backup Strategy

This implementation follows the 3-2-1 backup strategy:

1. **3 copies** of data (original + 2 backups)
2. **2 different media types** (local volume + remote storage)
3. **1 offsite copy** (cloud/S3 backup)

## Scheduled Backups

Enable automatic daily backups:

```bash
# Add to crontab (run as root)
crontab -e

# Add this line for daily 2AM backup
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target all
```

Or use systemd timer:

```bash
sudo cp scripts/backup.timer /etc/systemd/system/
sudo cp scripts/backup.service /etc/systemd/system/
sudo systemctl enable --now backup.timer
```

## Disaster Recovery

See [docs/disaster-recovery.md](../docs/disaster-recovery.md) for complete recovery procedures.

### Quick Recovery Commands

```bash
# List available backups
./scripts/backup.sh --list

# Verify backup integrity
./scripts/backup.sh --verify

# Restore from backup
./scripts/backup.sh --restore <backup_id>
```

## Notifications

Configure ntfy for backup notifications:

```env
NTFY_URL=https://ntfy.example.com
NTFY_TOKEN=your_token
```

Backup success/failure will be sent to the configured ntfy topic.

## Health Checks

All services have health checks configured:

```bash
docker compose -f stacks/backup/docker-compose.yml ps
```

## Troubleshooting

### Duplicati web UI not accessible

Check that port 8200 is available:
```bash
docker compose logs duplicati
```

### Restic repository not responding

Verify authentication is configured:
```bash
docker compose logs restic-rest-server
```

### Backup failing

Check backup script logs:
```bash
./scripts/backup.sh --target all --dry-run
```
