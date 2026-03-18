# Backup & Disaster Recovery Stack

> Automated backup solution with Duplicati and Restic REST Server

## Overview

This stack provides a complete backup and disaster recovery solution for your HomeLab:

- **Duplicati** — Encrypted cloud backup with web UI
- **Restic REST Server** — Local backup repository with deduplication

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Duplicati | 8200 | Encrypted cloud backup UI |
| Rest Server | 8000 | Local backup repository API |

## Quick Start

```bash
# Start the backup stack
docker compose -f stacks/backup/docker-compose.yml up -d

# Check services
docker compose -f stacks/backup/docker-compose.yml ps
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| TZ | UTC | Timezone |
| DOMAIN | — | Domain for Traefik |
| DATA_PATH | /opt/homelab | Path to data |
| BACKUP_TARGET | local | Backup target (local, s3, b2, sftp, r2) |
| NTFY_SERVER | https://ntfy.sh | ntfy server for notifications |
| NTFY_TOPIC | homelab-backups | ntfy topic |

### Backup Targets

Configure in `config/.env`:

```env
# Local backup
BACKUP_TARGET=local
BACKUP_DIR=/opt/homelab-backups

# MinIO/S3
BACKUP_TARGET=s3
S3_ENDPOINT=https://s3.example.com
S3_BUCKET=backups
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key

# Backblaze B2
BACKUP_TARGET=b2
B2_BUCKET=your-bucket
B2_KEY_ID=your-key-id
B2_KEY=your-key

# SFTP
BACKUP_TARGET=sftp
SFTP_HOST=backup.example.com
SFTP_USER=backup
SFTP_PATH=/backups/homelab

# Cloudflare R2
BACKUP_TARGET=r2
R2_ENDPOINT=https://your-account.r2.cloudflarestorage.com
R2_BUCKET=backups
R2_ACCESS_KEY=your-access-key
R2_SECRET_KEY=your-secret-key
```

## Backup Script

The `scripts/backup-new.sh` script provides:

```bash
# Show help
./scripts/backup-new.sh --help

# Dry run (show what would be backed up)
./scripts/backup-new.sh --target all --dry-run

# Backup specific stack
./scripts/backup-new.sh --target media

# Backup all stacks
./scripts/backup-new.sh --target all

# List available backups
./scripts/backup-new.sh --list

# Restore from backup
./scripts/backup-new.sh --restore 20240318_120000

# Verify backup integrity
./scripts/backup-new.sh --verify
```

## Scheduled Backups

Add to crontab:

```bash
# Daily backup at 2:00 AM
0 2 * * * /path/to/homelab-stack/scripts/backup-new.sh --target all >> /var/log/homelab-backup.log 2>&1
```

## Disaster Recovery

See [docs/disaster-recovery.md](../../docs/disaster-recovery.md) for:

- Recovery Time Objectives (RTO)
- Service recovery order
- Full recovery procedure
- Backup verification
- Troubleshooting

## Notifications

Backups notify via ntfy:

- Backup started
- Backup completed
- Backup failed

Configure ntfy:

```env
NTFY_SERVER=https://ntfy.sh
NTFY_TOPIC=homelab-backups
```

## Web UI Access

After starting the stack:

- **Duplicati UI**: https://duplicati.yourdomain.com
- **Restic API**: https://restic.yourdomain.com

## Security Notes

- Duplicati uses encryption for all backups
- Access is restricted via Traefik authentication
- Configure SSO for additional security

## Troubleshooting

### Duplicati won't start
- Check DATA_PATH exists
- Verify volume permissions
- Check Traefik configuration

### Backup fails
- Check disk space
- Verify backup target credentials
- Check logs: `docker compose logs duplicati`

### Restore fails
- Verify backup integrity first
- Ensure sufficient disk space
- Stop services before restore

## License

MIT License — See [LICENSE](../../LICENSE)

## Bounty

This stack was implemented as part of [Bounty #12](../../BOUNTY.md) ($150 USDT).
