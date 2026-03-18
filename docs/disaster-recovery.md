# Backup & Disaster Recovery Runbook

This runbook covers backup automation, validation, and full recovery for HomeLab Stack.

## 1. Backup Strategy (3-2-1)

- 3 copies:
  - Production data in Docker volumes
  - Local backup copy in `BACKUP_DIR`
  - Off-site backup archive (S3/B2/SFTP, or S3-compatible MinIO/R2)
- 2 media types:
  - Local disk
  - Object storage or remote SFTP server
- 1 off-site copy:
  - Cloud endpoint or remote host

## 2. What Is Backed Up

- Docker named volumes (all stacks or a selected stack)
- Repository configs (`config`, `scripts`, `docs`, `stacks`, `.env.example`)
- Databases (if containers are running):
  - PostgreSQL (`pg_dumpall`)
  - MariaDB/MySQL (`mariadb-dump --all-databases`)
  - Redis (`dump.rdb`)
- Integrity manifest (`manifest.sha256`) for all backup files

## 3. Backup Commands

```bash
# Backup all stacks
./scripts/backup.sh --target all

# Backup a specific stack
./scripts/backup.sh --target media

# Preview only
./scripts/backup.sh --target all --dry-run

# List backups
./scripts/backup.sh --list

# Verify latest backup
./scripts/backup.sh --verify

# Verify a specific backup
./scripts/backup.sh --verify 20260318_020000

# Restore a specific backup
./scripts/backup.sh --target all --restore 20260318_020000
```

## 4. Backup Target Configuration

Set target and credentials in `.env`:

```bash
BACKUP_TARGET=local    # local | s3 | b2 | sftp
```

- `local`: keep backups on local disk only
- `s3`: AWS S3, MinIO, or Cloudflare R2 through `BACKUP_S3_ENDPOINT`
- `b2`: Backblaze B2 through S3-compatible endpoint
- `sftp`: SCP upload to remote host

Notes:

- Cloudflare R2 is configured via `BACKUP_TARGET=s3` and `BACKUP_S3_ENDPOINT`.
- MinIO is configured via `BACKUP_TARGET=s3` and `BACKUP_S3_ENDPOINT`.

## 5. Automated Daily Backups (2:00 AM)

### Option A: crontab

```bash
crontab -e
```

Add:

```cron
0 2 * * * cd /path/to/homelab-stack && ./scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

### Option B: systemd timer

Create `/etc/systemd/system/homelab-backup.service`:

```ini
[Unit]
Description=HomeLab backup job
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/path/to/homelab-stack
ExecStart=/path/to/homelab-stack/scripts/backup.sh --target all
```

Create `/etc/systemd/system/homelab-backup.timer`:

```ini
[Unit]
Description=Run HomeLab backup daily at 02:00

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer
systemctl list-timers | grep homelab-backup
```

## 6. Full Recovery Procedure (Fresh Host)

### 6.1 Prepare host

- Install Docker Engine and Docker Compose plugin
- Clone repository and configure `.env`
- Ensure backup source is reachable (local mount, S3/B2/SFTP)

### 6.2 Restore order

Use this order to minimize dependency failures:

1. Base (`base`)
2. Databases (`databases`)
3. SSO (`sso`)
4. Core shared services (`storage`, `monitoring`, `notifications`)
5. Remaining stacks (`media`, `network`, `productivity`, `ai`, `home-automation`, `dashboard`)

### 6.3 Restore data

```bash
# See backup IDs
./scripts/backup.sh --list

# Verify before restore
./scripts/backup.sh --verify <backup_id>

# Restore all
./scripts/backup.sh --target all --restore <backup_id>
```

### 6.4 Start stacks in order

```bash
./scripts/stack-manager.sh start base
./scripts/stack-manager.sh start databases
./scripts/stack-manager.sh start sso
./scripts/stack-manager.sh start storage
./scripts/stack-manager.sh start monitoring
./scripts/stack-manager.sh start notifications
./scripts/stack-manager.sh start media
./scripts/stack-manager.sh start network
./scripts/stack-manager.sh start productivity
./scripts/stack-manager.sh start ai
./scripts/stack-manager.sh start home-automation
./scripts/stack-manager.sh start dashboard
```

## 7. RTO / RPO Estimates

These are practical estimates for a small to medium homelab on SSD + 1 Gbps network.

- RPO: 24h (daily backup at 02:00)
- RTO:
  - Base + Databases + SSO: 20-35 minutes
  - Full platform (all stacks): 45-120 minutes (depends on data size and pull speed)

## 8. Recovery Validation Checklist

- Backup integrity check passes (`--verify`)
- All required containers are running and healthy (`docker compose ps` per stack)
- Key HTTP endpoints return success (`curl` 2xx/3xx)
- SSO login works for protected services
- PostgreSQL, Redis, and MariaDB accept connections
- Critical user data present (Nextcloud files, media library metadata, service configs)
- ntfy notification received after next backup run

## 9. Failure Handling

- If backup upload fails, backup still exists locally in `BACKUP_DIR`
- If remote is unavailable, rerun after connectivity is restored
- Keep at least one known-good backup ID pinned (exclude from retention policy manually)
