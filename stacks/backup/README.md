# Backup Stack

3-2-1 backup strategy for HomeLab: 3 copies, 2 media types, 1 offsite.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | Encrypted cloud backup with web UI |
| Restic REST Server | `restic/rest-server:0.13.0` | 8000 | Local backup repository |

## Quick Start

```bash
# Create networks
docker network create proxy 2>/dev/null || true
docker network create backup 2>/dev/null || true

# Start
docker compose up -d

# Verify
docker compose ps
curl -sf http://localhost:8200/  # Duplicati UI
```

## Backup Script

```bash
# Full backup (all stacks)
./scripts/backup.sh --target all

# Single stack
./scripts/backup.sh --target databases

# Preview what would be backed up
./scripts/backup.sh --target all --dry-run

# Encrypted backup
export BACKUP_ENCRYPTION_KEY="your-passphrase"
./scripts/backup.sh --target all --encrypt

# List / verify / restore
./scripts/backup.sh --list
./scripts/backup.sh --verify
./scripts/backup.sh --restore 20260318_020000
```

## Storage Backends

Set `BACKUP_TARGET` in `.env`:

| Backend | Value | Requirements |
|---------|-------|-------------|
| Local | `local` | Default — `/opt/homelab-backups` |
| S3 / MinIO | `s3` | `awscli` or `mc`, S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY |
| Backblaze B2 | `b2` | `b2` CLI, B2_ACCOUNT_ID, B2_APP_KEY, B2_BUCKET |
| SFTP | `sftp` | SSH key, SFTP_HOST, SFTP_USER, SFTP_PATH |
| Cloudflare R2 | `r2` | `awscli`, S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY |

## Scheduling

See `config/` for cron and systemd timer files. Recommended: systemd timer.

```bash
sudo cp config/homelab-backup.service /etc/systemd/system/
sudo cp config/homelab-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer
```

## Disaster Recovery

See [docs/disaster-recovery.md](../../docs/disaster-recovery.md) for full recovery procedures.
