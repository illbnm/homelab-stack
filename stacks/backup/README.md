# Backup & Recovery Stack

3-2-1 backup strategy: 3 copies, 2 media types, 1 off-site. Duplicati for encrypted cloud backups + Restic for local snapshots + backup.sh for scripted automation.

## 3-2-1 Strategy

```
Copy 1 (Local):   /opt/homelab-backups/     ← Daily scripted backup
Copy 2 (Local):   Restic REST Server         ← Snapshots on different disk
Copy 3 (Off-site): MinIO / B2 / R2           ← Encrypted cloud sync
```

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | `https://backup.DOMAIN` | Encrypted cloud backup UI |
| Restic REST Server | `restic/rest-server:0.13.0` | (internal) | Local snapshot repository |

## Quick Start

```bash
# Start backup services
cd stacks/backup && docker compose up -d

# Run a full backup
../../scripts/backup.sh

# List existing backups
../../scripts/backup.sh --list

# Verify backup integrity
../../scripts/backup.sh --verify

# Restore latest backup
../../scripts/backup.sh --restore latest
```

## Backup Script Usage

```bash
# Full backup (all stacks)
./scripts/backup.sh

# Backup specific stacks
./scripts/backup.sh --target databases
./scripts/backup.sh --target media,storage

# Preview (dry-run)
./scripts/backup.sh --dry-run

# List backups
./scripts/backup.sh --list

# Restore
./scripts/backup.sh --restore 20260511_030000

# Verify integrity
./scripts/backup.sh --verify
```

## Backup Targets

Configure `BACKUP_TARGET` in `.env`:

| Target | What | Requirements |
|--------|------|-------------|
| `local` | Local disk only (default) | `BACKUP_DIR` set |
| `minio` / `s3` | MinIO/S3-compatible | `mc` configured |
| `b2` | Backblaze B2 | `B2_APPLICATION_KEY_ID` + `B2_APPLICATION_KEY` |
| `r2` | Cloudflare R2 | `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` |
| `sftp` | Remote SFTP | `SFTP_HOST`, `SFTP_USER`, `SFTP_KEY` |
| `restic` | Restic repository | `restic` binary + `RESTIC_REPOSITORY` |

## Automation

### Cron (daily at 2 AM)

```bash
# Add to crontab
0 2 * * * /opt/homelab-stack/scripts/backup.sh --target all
```

### Systemd Timer

```bash
# /etc/systemd/system/homelab-backup.service
[Unit]
Description=HomeLab Backup
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/homelab-stack/scripts/backup.sh
User=root

# /etc/systemd/system/homelab-backup.timer
[Unit]
Description=Daily HomeLab Backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

## Duplicati Setup

1. Open `https://backup.${DOMAIN}`
2. Add Backup → Configure
3. **Source:** `/source/config`, `/source/storage`, `/source/volumes`
4. **Destination:** `S3 Compatible` → MinIO endpoint `http://minio:9000`
5. **Schedule:** Daily at 3 AM
6. **Encryption:** AES-256 with passphrase

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BACKUP_DIR` | Yes | Local backup directory (default: /opt/homelab-backups) |
| `BACKUP_TARGET` | Yes | local, minio, b2, r2, sftp, restic |
| `BACKUP_RETENTION_DAYS` | No | Days to keep (default: 7) |
| `DUPLICATI_PASSWORD` | Yes | Duplicati web UI password |
| `RESTIC_PASSWORD` | Yes | Restic repository password |

## Disaster Recovery

Full recovery guide: [docs/disaster-recovery.md](../../docs/disaster-recovery.md)

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| backup.sh "Permission denied" | `chmod +x scripts/backup.sh` |
| Volume backup fails | Check volume exists: `docker volume ls` |
| PostgreSQL dump fails | Check `POSTGRES_ROOT_PASSWORD` in .env |
| Duplicati can't access sources | Check volume mounts are correct paths |