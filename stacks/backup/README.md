# Backup Stack — 3-2-1 Backup Strategy

**Bounty:** #12 — Backup & Recovery ($150)

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Duplicati | lscr.io/linuxserver/duplicati:2.0.8 | 8200 | Encrypted cloud backups with web UI |
| Restic REST Server | restic/rest-server:0.13.0 | 9000 | Local backup repository |

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env with your settings

# 2. Start
docker compose up -d

# 3. Access Duplicati
# https://backup.your-domain.com
```

## Backup Targets

Configure via `.env`:

- `BACKUP_TARGET=local` — Local volume
- `BACKUP_TARGET=s3` — MinIO / S3 compatible
- `BACKUP_TARGET=b2` — Backblaze B2
- `BACKUP_TARGET=sftp` — Remote SFTP

## Automatic Backup

Backups run daily at 2:00 AM via cron (configurable via `BACKUP_SCHEDULE` env var).

## Restore

See [Disaster Recovery Guide](../../docs/disaster-recovery.md) for full recovery procedures.

## Notifications

Backup status is monitored via healthchecks. Failed backups trigger alerts.
