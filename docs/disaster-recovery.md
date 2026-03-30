# Disaster Recovery Guide

## 3-2-1 Backup Strategy

- **3** copies of data (primary + 2 backups)
- **2** different storage media (local disk + restic/cloud)
- **1** offsite / cloud backup

## Backup Components

| Component | Image | Purpose |
|-----------|-------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | GUI backup scheduler with encryption |
| Restic REST Server | `restic/rest-server:0.13.0` | Restic-compatible backup repository |

## Quick Reference

```bash
# Full backup
./scripts/backup.sh --target all

# Dry run (see what would be backed up)
./scripts/backup.sh --target all --dry-run

# Backup specific stack
./scripts/backup.sh --target databases

# List available backups
./scripts/backup.sh --list

# Verify backup integrity
./scripts/backup.sh --verify

# Restore from backup
./scripts/backup.sh --restore 20260327_020000
```

## Supported Backup Targets

Export `BACKUP_TARGET` in `config/.env`:

| Target | Variable | Example |
|--------|----------|---------|
| Local | `BACKUP_TARGET=local` | `/opt/homelab-backups` |
| S3 | `BACKUP_TARGET=s3` | `s3:https://s3.amazonaws.com/bucket` |
| Backblaze B2 | `BACKUP_TARGET=b2` | `b2:bucket-name` |
| SFTP | `BACKUP_TARGET=sftp` | `sftp:user@host:/path` |
| Cloudflare R2 | `BACKUP_TARGET=r2` | `r2:bucket-name` |

Required env vars per target:
- **S3/B2/R2**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- **SFTP**: `SFTP_USER`, `SFTP_PASSWORD` or SSH key

## Restoration Procedures

### 1. Full System Restoration

1. Reinstall base OS
2. Install Docker and Docker Compose
3. Clone all stack repositories
4. Restore configs:
   ```bash
   tar xzf /opt/homelab-backups/<backup_id>_configs.tar.gz -C /opt/homelab/
   ```
5. Restore Docker volumes:
   ```bash
   # For each volume:
   docker run --rm \
     -v <volume_name>:/data \
     -v /opt/homelab-backups:/backup:ro \
     alpine:3.19 \
     tar xzf /backup/<backup_id>_vol_<volume_name>.tar.gz -C /data
   ```
6. Restore databases (see below)
7. Start all stacks: `docker compose up -d` in each stack directory

### 2. Database Restoration

**PostgreSQL:**
```bash
docker exec -i <postgres_container> psql -U postgres < <backup_file>.sql
```

**MariaDB/MySQL:**
```bash
docker exec -i <mysql_container> mysql -u root -p < <backup_file>.sql
```

**Redis:**
```bash
docker cp <backup_file>.rdb <redis_container>:/data/dump.rdb
docker restart <redis_container>
```

### 3. Stack-Specific Restoration Order

Restoration must follow dependency order:

1. **Base** (authentication, networking)
2. **SSO** (authentication layer)
3. **Databases** (data stores)
4. **Storage** (file storage)
5. **Notifications** (alerting)
6. **Media** (media files)
7. **Applications** (apps)

### 4. Configuration Restoration

Each stack's config is in `config/<stack>/`. To restore:
```bash
# Restore specific stack config
tar xzf /opt/homelab-backups/<backup_id>_configs.tar.gz -C /opt/homelab/
# Then selectively extract:
tar xzf /opt/homelab-backups/<backup_id>_configs.tar.gz stacks/<stack>/ config/<stack>/
```

## Key Metrics

| Metric | Target |
|--------|--------|
| RTO (Recovery Time Objective) | 4 hours |
| RPO (Recovery Point Objective) | 24 hours |
| Backup frequency | Daily at 2:00 AM |
| Retention period | 7 days |

## Monitoring

Add to crontab for automated daily backups:
```cron
0 2 * * * /opt/homelab/scripts/backup.sh --target all >> /var/log/backup/backup.log 2>&1
```

Or use systemd timer:
```bash
cp stacks/backup/backup.timer /etc/systemd/system/
cp stacks/backup/backup.service /etc/systemd/system/
systemctl enable backup.timer
systemctl start backup.timer
```

## Testing Restorations

Quarterly, test restoration procedures in a staging environment:
1. Spin up a test VM
2. Simulate data loss
3. Follow restoration procedures
4. Verify all services operational
5. Document any issues found
