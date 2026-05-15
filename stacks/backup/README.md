# Backup & Disaster Recovery Stack

> 3-2-1 backup strategy for all HomeLab stacks — automated daily backups with 7-day retention.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Restic REST Server | `restic/rest-server:0.13.0` | Local backup repository with REST API |
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | Encrypted cloud backup with web UI |
| Backup Cron | `alpine:3.20` | Scheduled backup runner (crond) |

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env — set RESTIC_PASSWORD, BACKUP_TARGET, credentials

# 2. Create networks
docker network create proxy 2>/dev/null || true

# 3. Start backup stack
docker compose up -d

# 4. Run first backup
./scripts/backup.sh --target all --notify

# 5. Set up schedule
./scripts/setup-schedule.sh --time 02:00
```

## Backup Script Usage

```bash
./scripts/backup.sh --target <stack|all> [options]

Options:
  --target all          Backup all stack volumes
  --target <name>       Backup specific stack (e.g., media, databases)
  --dry-run             Show what would be backed up
  --list                List all available backups
  --verify              Verify backup integrity
  --restore <id>        Restore from specific backup ID
  --notify              Send ntfy notification
```

### Examples

```bash
# Full backup with notification
./scripts/backup.sh --target all --notify

# Preview what would be backed up
./scripts/backup.sh --target all --dry-run

# Backup only media stack
./scripts/backup.sh --target media

# List all backups
./scripts/backup.sh --list

# Verify latest backup
./scripts/backup.sh --verify

# Restore specific backup
./scripts/backup.sh --restore 20260515_020000
```

## Disaster Recovery

For full host recovery, see [docs/disaster-recovery.md](../../docs/disaster-recovery.md).

Quick restore:
```bash
# From latest backup
./scripts/restore.sh --from-latest

# From specific backup
./scripts/restore.sh --from 20260515_020000

# List available backups
./scripts/restore.sh --list
```

## Backup Targets

Configure `BACKUP_TARGET` in `.env`:

| Target | Value | Description |
|--------|-------|-------------|
| Local | `local` | Local directory (default) |
| S3/MinIO | `s3` | S3-compatible storage |
| Backblaze B2 | `b2` | Backblaze B2 cloud storage |
| SFTP | `sftp` | SFTP remote server |
| Cloudflare R2 | `r2` | Cloudflare R2 (S3-compatible) |

## What Gets Backed Up

- **Docker volumes**: All named volumes from all stacks
- **Databases**: PostgreSQL (pg_dumpall), MariaDB (mysqldump), Redis (RDB)
- **Config files**: All stack configs, scripts, environment templates
- **Retention**: Configurable (default: 7 days)

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Backup Architecture                 │
├─────────────────────────────────────────────────┤
│                                                  │
│  backup-cron (02:00 daily)                       │
│       │                                          │
│       ├── backup.sh --target all                 │
│       │     ├── Docker volumes → .tar.gz         │
│       │     ├── PostgreSQL → .sql dump           │
│       │     ├── MariaDB → .sql dump              │
│       │     ├── Redis → .rdb copy                │
│       │     └── Configs → .tar.gz                │
│       │                                          │
│       └── Push to target (local/s3/b2/sftp/r2)   │
│                                                  │
│  Duplicati (web UI)                              │
│       └── Encrypted cloud backup (optional)      │
│                                                  │
│  Restic REST Server                              │
│       └── Deduplicated local repository          │
│                                                  │
│  Notifications                                   │
│       └── ntfy on success/failure                │
└─────────────────────────────────────────────────┘
```

## Notifications

Backup results are pushed to ntfy on completion:

- **Success**: Default priority, includes backup ID, target, size
- **Failure**: High priority, includes error details

Configure in `.env`:
```bash
NTFY_URL=http://ntfy:80
NTFY_TOPIC=homelab-backup
NTFY_TOKEN=              # Optional auth token
```
