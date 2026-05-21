# Backup & DR Stack

3-2-1 backup strategy for HomeLab Stack — encrypted cloud backup (Duplicati) + local backup repository (Restic) + automated scripts.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Duplicati | v2.0.8.1 | `backup.<DOMAIN>` | Encrypted backup UI (cloud/S3/B2/SFTP) |
| Restic REST Server | 0.13.0 | `restic.<DOMAIN>` | Local restic backup repository |

## 3-2-1 Backup Strategy

```
Data Sources
    │
    ├──► [Duplicati] ──► Cloud (S3/B2/SFTP/R2)     [Copy 1: remote]
    │                    Local /backups               [Copy 2: local]
    │
    └──► [scripts/backup.sh] ──► Docker volumes
                                 PostgreSQL dumps
                                 MariaDB dumps
                                 Config tarballs        [Copy 3: local]
    │
    [Restic REST Server] ──► Deduplicated backup repo [Medium 2: separate volume]
```

## Quick Start

```bash
cd stacks/base && docker compose up -d
cd ../backup
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `BACKUP_SOURCE` | No | `/opt/homelab` | Path to backup (mounted read-only) |
| `BACKUP_DEST_LOCAL` | No | `/opt/homelab-backups` | Local backup destination |
| `DUPLICATI_PASSWORD` | No | — | Duplicati web UI password |
| `TZ` | No | `Asia/Shanghai` | Timezone |

### Duplicati Setup

1. Visit `https://backup.<DOMAIN>`
2. Add backup job: Settings → Add Backup
3. Select source: `/source` (maps to `BACKUP_SOURCE`)
4. Select destination: Choose one:
   - **Local**: `/backups`
   - **S3**: MinIO at `https://s3.<DOMAIN>`
   - **B2**: Backblaze B2 (need keyID + appKey)
   - **SFTP**: Remote server
5. Set encryption passphrase (important!)
6. Schedule: Daily at 2:00 AM
7. Retention: Keep 7 daily, 4 weekly, 12 monthly

### Restic Setup

Use with the `restic` CLI from any machine:

```bash
export RESTIC_REPOSITORY=rest:https://restic.${DOMAIN}/myrepo
export RESTIC_PASSWORD=my-encryption-password

# Initialize repo (first time only)
restic init

# Backup
restic backup /path/to/data

# Restore
restic restore latest --target /path/to/restore

# List snapshots
restic snapshots
```

### Automated Backups with backup.sh

The repo includes `scripts/backup.sh` for automated backups:

```bash
# Full backup (volumes + databases + configs)
./scripts/backup.sh

# Add to crontab for daily 2AM backup
echo '0 2 * * * /opt/homelab/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1' | crontab -
```

### Backup Notifications

Configure Duplicati to send notifications via ntfy:

1. In Duplicati: Settings → Default options → Send notifications
2. Type: Custom HTTP URL
3. URL: `http://ntfy:80/homelab-backup`

## Disaster Recovery

### Full Restore Procedure (new host)

```bash
# 1. Install Docker + Compose
# 2. Clone repo
git clone <repo-url> /opt/homelab

# 3. Restore .env from backup
tar xzf /opt/homelab-backups/<latest>/configs.tar.gz -C /opt/homelab

# 4. Start base stack
cd /opt/homelab/stacks/base && docker compose up -d

# 5. Start databases and restore data
cd ../databases && docker compose up -d
cat <backup>/postgresql_all.sql | docker exec -i homelab-postgres psql -U postgres

# 6. Start remaining stacks in order
cd ../sso && docker compose up -d
cd ../storage && docker compose up -d
cd ../productivity && docker compose up -d
# ... etc
```

### Restore Order

1. Base (Traefik) → 2. Databases → 3. SSO → 4. All others

### Estimated RTO

| Component | Time |
|-----------|------|
| Base + DB | ~5 min |
| SSO | ~3 min |
| Storage | ~5 min |
| Productivity | ~5 min |
| Other stacks | ~10 min |
| **Total** | **~30 min** |

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Duplicati can't access source | Check `BACKUP_SOURCE` mount is correct |
| Restic REST returns 401 | No auth by default; add `--htpasswd-file` for auth |
| Backup too large | Duplicati uses deduplication; first backup is largest |
| Restore fails | Check encryption passphrase matches |
