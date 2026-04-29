# Backup & Disaster Recovery Stack

3-2-1 backup strategy: 3 copies, 2 media types, 1 offsite.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Duplicati | 2.0.8 | `backup.<DOMAIN>` | Encrypted cloud backup with Web UI |
| Restic REST Server | 0.13.0 | `restic.<DOMAIN>` | Local backup repository (append-only) |

## Architecture

```
[Data Sources]
    │
    ├── Docker volumes ──► backup.sh ──► .tar.gz archives
    ├── PostgreSQL/MariaDB ──► backup.sh ──► .sql.gz dumps
    ├── Config files ──► backup.sh ──► configs.tar.gz
    │
    ▼
[Duplicati] ──encrypt──► Cloud storage (S3, B2, SFTP, etc.)
    │
[Restic REST] ──encrypt──► Local Restic repository (append-only)
    │
[ntfy notification] ◄── backup success/failure
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- Databases stack running (for database dumps)

## Quick Start

```bash
cd stacks/backup
cp .env.example .env
vim .env  # Set DUPLICATI_PASSWORD, RESTIC_PASSWORD, BACKUP_TARGET

docker compose up -d

# Run a manual backup
../scripts/backup-v2.sh --target all
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DUPLICATI_PASSWORD` | ✅ | Duplicati Web UI password |
| `RESTIC_PASSWORD` | ✅ | Encryption key for Restic repository |
| `BACKUP_SOURCE` | ✅ | Directory to back up (default: `/opt/homelab`) |
| `BACKUP_TARGET` | ✅ | `local`, `s3`, `b2`, or `sftp` |
| `BACKUP_RETENTION_DAYS` | — | Days to keep local backups (default: 7) |

### Backup Targets

| Target | Required Variables |
|--------|--------------------|
| `local` | `BACKUP_LOCAL_DIR` |
| `s3` | `BACKUP_S3_ENDPOINT`, `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY` |
| `b2` | `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, `B2_BUCKET` |
| `sftp` | `SFTP_HOST`, `SFTP_USER`, `SFTP_PATH` |

## backup.sh Usage

```bash
# Full backup (all stacks + databases + configs)
./scripts/backup-v2.sh --target all

# Specific stack only
./scripts/backup-v2.sh --target media
./scripts/backup-v2.sh --target databases

# Dry run (show what would be backed up)
./scripts/backup-v2.sh --target all --dry-run

# List available backups
./scripts/backup-v2.sh --list

# Verify latest backup integrity
./scripts/backup-v2.sh --verify

# Restore from a specific backup
./scripts/backup-v2.sh --restore 20240101_020000

# Send notification on completion
./scripts/backup-v2.sh --target all --notify
```

## Scheduled Backups

### Cron (daily at 2:00 AM)

```bash
crontab -e
# Add:
0 2 * * * cd /opt/homelab && ./scripts/backup-v2.sh --target all --notify >> /var/log/homelab-backup.log 2>&1
```

### Systemd Timer (alternative)

```ini
# /etc/systemd/system/homelab-backup.service
[Unit]
Description=HomeLab Backup

[Service]
Type=oneshot
ExecStart=/opt/homelab/scripts/backup-v2.sh --target all --notify
WorkingDirectory=/opt/homelab

# /etc/systemd/system/homelab-backup.timer
[Unit]
Description=Daily HomeLab Backup

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable homelab-backup.timer
sudo systemctl start homelab-backup.timer
```

## Duplicati Setup

1. Open `https://backup.<DOMAIN>`
2. Set a password on first access
3. **Add Backup**:
   - Source: `/source` (maps to `BACKUP_SOURCE`)
   - Destination: Choose your backend (S3/B2/SFTP/local)
   - Schedule: Daily at 2:00 AM (or custom)
   - Encryption: AES-256 (default, recommended)
4. Configure retention: Keep backups for 30 days, or keep N weekly/monthly

## Restic Setup

```bash
# Initialize repository (first time only)
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
restic init --rest-url https://restic.${DOMAIN}/homelab

# Manual backup
restic backup --rest-url https://restic.${DOMAIN}/homelab /opt/homelab/config /opt/homelab/stacks

# List snapshots
restic snapshots --rest-url https://restic.${DOMAIN}/homelab

# Restore latest
restic restore latest --rest-url https://restic.${DOMAIN}/homelab --target /tmp/restore

# Verify integrity
restic check --rest-url https://restic.${DOMAIN}/homelab
```

### Create Restic User

```bash
# Generate htpasswd entry for the Restic REST server
htpasswd -nb restic "${RESTIC_PASSWORD}" >> /path/to/restic-data/.htpasswd
```

## Disaster Recovery Procedure

Full recovery from bare metal — see `docs/disaster-recovery.md` for details.

### Recovery Order

1. **Base Stack** — Traefik + Portainer (reverse proxy)
2. **Databases Stack** — PostgreSQL + Redis + MariaDB (restore DB dumps)
3. **SSO Stack** — Authentik (identity provider)
4. **Other Stacks** — Media, Storage, Network, Productivity

### Estimated Recovery Time (RTO)

| Stack | Estimated Time |
|-------|---------------|
| Base | 5 min |
| Databases | 10-30 min (depends on dump size) |
| SSO | 10 min |
| All other stacks | 20 min |
| **Total** | **~1 hour** |

### Recovery Checklist

- [ ] Fresh Docker installed on new host
- [ ] Clone homelab-stack repo
- [ ] Restore `.env` from backup
- [ ] Start base stack: `docker compose -f stacks/base/docker-compose.yml up -d`
- [ ] Start databases: `docker compose -f stacks/databases/docker-compose.yml up -d`
- [ ] Restore DB dumps: `./scripts/backup-v2.sh --restore <backup_id>`
- [ ] Start SSO stack
- [ ] Start remaining stacks
- [ ] Verify all services healthy: `docker compose ps` in each stack
- [ ] Verify Traefik routes: `curl -sf https://service.${DOMAIN}`
- [ ] Verify database connections from each service
