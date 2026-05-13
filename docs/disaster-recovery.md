# Disaster Recovery Guide

## Overview

This document describes how to recover the HomeLab Stack from a complete failure.

## Recovery Order

```
1. Base (Traefik, Portainer, Watchtower)
2. Databases (PostgreSQL, Redis, MariaDB)
3. SSO (Authentik)
4. Storage (MinIO, Nextcloud)
5. Monitoring (Prometheus, Grafana)
6. Notifications (ntfy, Gotify)
7. Other stacks (Media, AI, Productivity)
```

## Prerequisites

- Fresh Ubuntu 22.04+ server
- Docker + Docker Compose installed
- Access to backup repository (restic)
- `.env` file with credentials

## Full Recovery Steps

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
```

### 2. Clone Repository

```bash
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab
cd /opt/homelab
```

### 3. Restore Environment

```bash
cp .env.example .env
# Edit .env with your domain, passwords, etc.
```

### 4. Restore Backups

```bash
# Install restic
apt install restic

# Configure repository
export RESTIC_REPOSITORY="rest:http://your-backup-server:8000/"
export RESTIC_PASSWORD="your-password"

# List available snapshots
./scripts/backup.sh --list

# Restore latest
./scripts/backup.sh --restore latest
```

### 5. Start Stacks (in order)

```bash
cd stacks/base && docker compose up -d
cd ../databases && docker compose up -d
cd ../sso && docker compose up -d
cd ../storage && docker compose up -d
cd ../monitoring && docker compose up -d
cd ../notifications && docker compose up -d
```

### 6. Verify Recovery

```bash
./tests/run-tests.sh --all
```

## Recovery Time Objective (RTO)

| Component | Estimated Time |
|-----------|---------------|
| Base infrastructure | 5 min |
| Database restore | 10-30 min |
| SSO configuration | 5 min |
| Full stack | 30-60 min |

## Verification Checklist

- [ ] Traefik dashboard accessible
- [ ] All services show healthy in Portainer
- [ ] SSO login works
- [ ] Database data restored correctly
- [ ] Monitoring dashboards show data
- [ ] Notifications working (test with `scripts/notify.sh`)

## Backup Schedule

Daily at 2:00 AM via crontab:

```cron
0 2 * * * /opt/homelab/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

## Backup Targets

Configure via `BACKUP_TARGET` in `.env`:

| Target | Config |
|--------|--------|
| Local | `BACKUP_TARGET=local` |
| MinIO (S3) | `BACKUP_TARGET=s3` + `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `RESTIC_REPO=s3:http://minio:9000/backups` |
| Backblaze B2 | `BACKUP_TARGET=b2` + `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, `RESTIC_REPO=b2:bucket-name:path` |
| SFTP | `BACKUP_TARGET=sftp` + `RESTIC_REPO=sftp:user@host:/backups` |
| Cloudflare R2 | `BACKUP_TARGET=r2` + S3-compatible config with R2 endpoint |
