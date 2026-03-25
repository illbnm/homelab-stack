# Backup Stack

Implements a 3-2-1 backup strategy for the homelab: 3 copies, 2 media types, 1 offsite.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | Encrypted cloud backup with Web UI |
| Restic REST Server | `restic/rest-server:0.13.0` | 8000 | Local backup repository |

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Start backup services
docker compose up -d

# 3. Configure Duplicati via Web UI
# https://duplicati.yourdomain.com
```

## Backup Script

### Usage

```bash
# Backup everything
./scripts/backup.sh --target all

# Backup only databases
./scripts/backup.sh --target databases

# Backup configurations
./scripts/backup.sh --target config

# Dry run (preview)
./scripts/backup.sh --target all --dry-run

# List available backups
./scripts/backup.sh --list

# Verify backup integrity
./scripts/backup.sh --verify

# Restore from backup
./scripts/backup.sh --restore YYYYMMDD_HHMMSS
```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BACKUP_TARGET` | No | `local` | Backup destination: local, s3, b2, sftp, r2 |
| `BACKUP_DIR` | No | `/var/backups/homelab` | Local backup directory |
| `KEEP_DAYS` | No | `7` | Days to keep backups |
| `S3_BUCKET` | If target=s3 | - | AWS S3 bucket name |
| `B2_BUCKET` | If target=b2 | - | Backblaze B2 bucket |
| `R2_BUCKET` | If target=r2 | - | Cloudflare R2 bucket |
| `SFTP_HOST` | If target=sftp | - | SFTP server hostname |

## Scheduled Backups

### Crontab

```bash
# Daily backup at 2:00 AM
0 2 * * * /path/to/scripts/backup.sh --target all >> /var/log/backup.log 2>&1

# Weekly full backup on Sunday
0 3 * * 0 /path/to/scripts/backup.sh --target all >> /var/log/backup.log 2>&1
```

## Duplicati Configuration

### Initial Setup

1. Access Web UI: `https://duplicati.${DOMAIN}`
2. Add backup configuration
3. Select source folders (mounted in container)
4. Configure encryption passphrase
5. Set schedule and retention

### Recommended Settings

| Setting | Value |
|---------|-------|
| Encryption | AES-256 |
| Retention | Keep 4 weekly, 12 monthly |
| Schedule | Weekly, Sunday 3:00 AM |
| File size | Split files > 50 MB |

## Restic REST Server

### Usage

```bash
# Initialize repository
export RESTIC_REPOSITORY=rest:http://restic.yourdomain.com/hostname
restic init

# Create backup
restic backup /path/to/data

# List snapshots
restic snapshots

# Restore
restic restore latest --target /restore/path
```

## Backup Targets

### Local

Default. Backups stored in `BACKUP_DIR`.

### S3 (AWS)

```bash
export BACKUP_TARGET=s3
export S3_BUCKET=your-bucket
```

### B2 (Backblaze)

```bash
export BACKUP_TARGET=b2
export B2_BUCKET=your-bucket
```

### SFTP

```bash
export BACKUP_TARGET=sftp
export SFTP_HOST=backup.example.com
export SFTP_USER=backup
```

### Cloudflare R2

```bash
export BACKUP_TARGET=r2
export R2_BUCKET=your-bucket
```

## Disaster Recovery

See [docs/disaster-recovery.md](../../docs/disaster-recovery.md) for detailed recovery procedures.

### Quick Recovery

```bash
# 1. List backups
./scripts/backup.sh --list

# 2. Restore specific backup
./scripts/backup.sh --restore YYYYMMDD_HHMMSS

# 3. Restore databases
gunzip -c postgres_*.sql.gz | docker exec -i homelab-postgres psql -U postgres
```

## Notifications

Backups send notifications via ntfy:
- ✅ Backup completed
- ⚠️ Backup failed
- ℹ️ Restore operation

Configure via `NTFY_URL` environment variable.

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Duplicati | 256 MB | 512 MB - 1 GB |
| Restic Server | 128 MB | 256 MB |
| **Total** | **384 MB** | **768 MB - 1.25 GB** |

## Troubleshooting

### Duplicati won't start

```bash
# Check logs
docker logs duplicati

# Common issues:
# - Permission denied: check PUID/PGID
# - Port conflict: check 8200 is free
```

### Backup fails

```bash
# Check disk space
df -h /var/backups

# Check permissions
ls -la /var/backups/homelab

# Run with verbose output
bash -x ./scripts/backup.sh --target all
```

### Restore fails

```bash
# Verify backup integrity
./scripts/backup.sh --verify

# Check available space
df -h

# Restore to alternate location
tar -tzf backup_file.tar.gz  # List contents
```

## Security

- **Encryption**: Duplicati uses AES-256 encryption
- **Access Control**: Web UIs protected by Traefik + HTTPS
- **Network Isolation**: Backup services on internal network
- **Principle of Least Privilege**: Read-only mounts for backup sources
