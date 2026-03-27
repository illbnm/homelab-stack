# Backup & Disaster Recovery Stack

3-2-1 backup strategy: 3 copies, 2 media types, 1 offsite.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Duplicati | 2.0 | `backup.<DOMAIN>` | Encrypted backup with deduplication |
| Restic REST Server | 0.13 | `restic.<DOMAIN>` | Self-hosted backup repository |

## 3-2-1 Strategy

```
Data Source
    │
    ├──► Local disk ──► Restic REST Server ──► Offsite (MinIO/S3)
    │                        │
    │                        └──► Duplicati (encrypted) ──► Cloud/MinIO
    │
    └──► Docker volumes (snapshots)
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Backup & Disaster Recovery                    │
│                                                          │
│  ┌────────────┐         ┌──────────────────┐           │
│  │ Duplicati  │         │ Restic REST Srv  │           │
│  │ (encrypted)│         │ (deduplicated)   │           │
│  └─────┬──────┘         └────────┬─────────┘           │
│        │                          │                     │
│        └───► MinIO / S3 ──────────┘                     │
│                  (offsite)                              │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
cd stacks/backup
cp .env.example .env
# Edit: RESTIC_PASSWORD, backup paths

docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `RESTIC_PASSWORD` | ✅ | Password for restic repository |
| `BACKUP_ROOT` | — | Root path for backups (default: /backups) |
| `TZ` | — | Timezone (default: Asia/Shanghai) |

## Duplicati Setup

1. Access Duplicati at `https://backup.${DOMAIN}`
2. On first login, configure:
   - **Backup destination**: MinIO S3 bucket, local folder, or cloud storage
   - **Source**: paths to backup (e.g., `/backups/stacks`)
   - **Schedule**: daily/weekly backups
   - **Encryption**: AES-256 recommended

### Duplicati Backup Jobs

Configure jobs for each stack:

| Job | Source | Destination |
|-----|--------|-------------|
| Stack Configs | `./stacks/*/docker-compose.yml` | MinIO S3 |
| Database Dumps | `scripts/backup-databases.sh` output | Local |
| Media Metadata | `jellyfin-config` volume | MinIO S3 |

## Restic REST Server Setup

### Initialize a Repository

```bash
# On any machine with restic client installed:
export RESTIC_PASSWORD="your-password"
restic -r rest:http://restic.${DOMAIN}:8000/init

# Or pre-existing repo:
restic -r rest:http://restic.${DOMAIN}:8000 backup /path/to/data
```

### Backup Docker Volumes

```bash
# Via included backup.sh:
./scripts/backup.sh --target all --restic

# Or manual:
RESTIC_PASSWORD="..." restic \
  -r rest:http://restic:8000/volumes/postgres \
  backup /var/lib/docker/volumes/postgres-data/_data
```

## backup.sh Script

Located at repo root: `scripts/backup.sh`

```bash
# Backup all stacks via Restic
./scripts/backup.sh --target all --restic

# Backup specific stack
./scripts/backup.sh --target databases --restic

# Preview without executing
./scripts/backup.sh --target all --dry-run

# List available stacks
./scripts/backup.sh --list

# Check backup status
./scripts/backup.sh --status
```

## Restore from Backup

### Duplicati
1. Open Duplicati UI at `https://backup.${DOMAIN}`
2. Navigate to Restore tab
3. Select backup job and restore destination

### Restic

```bash
# List snapshots
RESTIC_PASSWORD="..." restic -r rest:http://restic:8000/volumes/postgres snapshots

# Restore latest
RESTIC_PASSWORD="..." restic -r rest:http://restic:8000/volumes/postgres \
  restore latest --target /restored/path

# Restore specific snapshot
RESTIC_PASSWORD="..." restic -r rest:http://restic:8000/volumes/postgres \
  restore <snapshot-id> --target /restored/path
```

## MinIO Offsite Backup

Configure MinIO as offsite destination for both Duplicati and Restic:

```bash
# MinIO S3-compatible endpoint
export AWS_ACCESS_KEY_ID=${MINIO_ROOT_USER}
export AWS_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}

# Restic to MinIO
restic -r s3:http://minio.${DOMAIN}:9000/bucketName backup /data

# Duplicati to MinIO:
# Add S3-compatible destination, endpoint: minio.${DOMAIN}:9000
```

## Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Duplicati | `https://backup.${DOMAIN}` | Set on first login |
| Restic REST Server | `https://restic.${DOMAIN}` | No auth by default — protect with network isolation |
