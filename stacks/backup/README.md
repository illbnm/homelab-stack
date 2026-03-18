# Backup & Recovery Stack

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | Encrypted cloud backup with web UI |
| Restic REST Server | `restic/rest-server:0.13.0` | 8000 (internal) | Local backup repository server |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Homelab Host                       │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ backup.sh │─▶│ Duplicati│  │ Restic REST Srv  │  │
│  │ (cron)    │  │  :8200   │  │  :8000 (int)     │  │
│  └─────┬────┘  └────┬─────┘  └────────┬─────────┘  │
│        │            │                 │              │
│        v            v                 v              │
│  ┌─────────────────────────────────────────┐        │
│  │         Backup Storage Targets           │        │
│  │  Local │ S3/MinIO │ B2 │ SFTP │ R2     │        │
│  └─────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────┘
         │                         │
         v                         v
   ┌───────────┐            ┌───────────┐
   │ Off-site  │            │  Cloud    │
   │ (NAS/NFS) │            │ Provider  │
   └───────────┘            └───────────┘
```

## Quick Start

```bash
# 1. Copy and edit env
cd stacks/backup
cp .env.example .env
nano .env  # Set passwords and targets

# 2. Generate htpasswd for Restic
docker run --rm httpd:2 htpasswd -nb ${RESTIC_REST_USER} ${RESTIC_REST_PASS} > config/.htpasswd

# 3. Start services
docker compose up -d

# 4. Test backup
cd ../..
chmod +x scripts/backup.sh
./scripts/backup.sh --target all --dry-run
./scripts/backup.sh --target all

# 5. Set up cron (daily 2:00 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/homelab/scripts/backup.sh --target all >> /var/log/backup.log 2>&1") | crontab -
```

## 3-2-1 Backup Strategy

| Copy | Medium | Location | Tool |
|------|--------|----------|------|
| 1 | NVMe SSD | Local host | backup.sh → local path |
| 2 | HDD/NAS | LAN (SFTP/NFS) | backup.sh → SFTP |
| 3 | Cloud | Off-site | Duplicati → S3/B2/R2 |

## Restore Flow

1. **Identify** backup: `./scripts/backup.sh --list`
2. **Stop** affected stack: `docker compose -f stacks/<stack>/docker-compose.yml down`
3. **Restore**: `./scripts/restore.sh --target <stack> --backup-id <id>`
4. **Restart**: `docker compose -f stacks/<stack>/docker-compose.yml up -d`
5. **Verify**: Check service health and data integrity

## Verification Checklist

- [ ] `backup.sh --verify` passes
- [ ] Restored container starts without errors
- [ ] Database connectivity confirmed
- [ ] Application data intact (file count / checksum)
- [ ] Service responds on expected port
- [ ] SSL certificate valid (if applicable)
