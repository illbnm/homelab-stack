# Backup & Recovery Stack — 3-2-1 Strategy

Implements a complete backup and disaster recovery solution using Duplicati + Restic.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | `https://backup.${DOMAIN}` |
| Restic REST Server | `restic/rest-server:0.13.0` | 8000 | `https://restic.${DOMAIN}` |

## 3-2-1 Backup Strategy

- **3 copies**: Live data + Restic local + Duplicati cloud
- **2 media**: Local disk + cloud (S3/B2/R2/SFTP)
- **1 offsite**: Cloud backup via Duplicati

## Quick Start

```bash
cp .env.example .env
nano .env  # Configure backup target, passwords, ntfy
docker compose up -d
```

## Backup Script

```bash
# Full backup
./scripts/backup.sh --target all

# Specific stack
./scripts/backup.sh --target media

# Dry run (preview)
./scripts/backup.sh --target all --dry-run

# List backups
./scripts/backup.sh --list

# Restore
./scripts/backup.sh --restore <snapshot-id> --target media

# Verify integrity
./scripts/backup.sh --verify
```

## Backup Targets

| Target | Config | Description |
|--------|--------|-------------|
| local | `BACKUP_TARGET=local` | Restic REST server on local disk |
| s3 | `BACKUP_TARGET=s3` | S3-compatible (MinIO/AWS) |
| b2 | `BACKUP_TARGET=b2` | Backblaze B2 |
| r2 | `BACKUP_TARGET=r2` | Cloudflare R2 |
| sftp | `BACKUP_TARGET=sftp` | Remote SFTP server |

## Scheduled Backups

Install cron jobs:
```bash
crontab stacks/backup/backup-cron
```

- Daily full backup at 2:00 AM
- Weekly integrity verification at 4:00 AM Sundays
- Weekly backup listing at 5:00 AM Sundays

## Retention Policy

| Period | Copies Kept |
|--------|-------------|
| Daily | 7 |
| Weekly | 4 |
| Monthly | 6 |
| Yearly | 1 |

## Notifications

Backup results (success/failure) are sent via ntfy:
```bash
# Configure in .env:
NTFY_URL=https://ntfy.sh
NTFY_TOPIC=homelab-backups
```

## Disaster Recovery

See `docs/disaster-recovery.md` for:
- Full recovery procedure (fresh host)
- Recovery order (Base → DB → SSO → remaining)
- RTO estimates (~2.5 hours total)
- Verification checklist