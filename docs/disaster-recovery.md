# Disaster Recovery Guide

## HomeLab Stack - Backup & DR Documentation

This document outlines the disaster recovery procedures for the HomeLab Stack, implementing the 3-2-1 backup strategy: **3 copies of data, 2 different storage types, 1 off-site backup**.

---

## Table of Contents

1. [Backup Overview](#backup-overview)
2. [Backup Strategy](#backup-strategy)
3. [Restore Procedures](#restore-procedures)
4. [Service Recovery Order](#service-recovery-order)
5. [RTO Estimates](#rto-estimates)
6. [Verification Checklist](#verification-checklist)
7. [Automated Backups](#automated-backups)

---

## Backup Overview

### 3-2-1 Backup Strategy

| Component | Description |
|-----------|-------------|
| **3 Copies** | Original data + 2 backup copies |
| **2 Media Types** | Local storage + remote/cloud storage |
| **1 Off-site** | Backup stored at different location |

### Backup Components

- **Duplicati** (`lscr.io/linuxserver/duplicati:2.0.8`) - Encrypted cloud backup
- **Restic REST Server** (`restic/rest-server:0.13.0`) - Local backup repository

### Backup Targets Supported

- **Local** - Local directory backup
- **S3/MinIO** - S3-compatible storage
- **Backblaze B2** - Cloud storage
- **SFTP** - Secure file transfer
- **Cloudflare R2** - S3-compatible cloud storage

---

## Backup Strategy

### Backup Schedule

| Frequency | Time | Target |
|-----------|------|--------|
| Daily | 2:00 AM | All stacks |
| Weekly | Sunday 3:00 AM | Full system |
| Monthly | 1st of month | Archive |

### Data Categories

#### Critical (Base Stack)
- PostgreSQL databases
- Redis cache data
- MariaDB databases
- Configuration files
- SSL certificates

#### Important (Productivity Stack)
- Nextcloud data
- Gitea repositories
- Outline wiki
- Bookstack content

#### Media (Media Stack)
- Media configurations
- Download client configs
-arr/Sonarr databases

### Retention Policy

- **Daily backups**: Keep for 7 days
- **Weekly backups**: Keep for 4 weeks
- **Monthly backups**: Keep for 12 months

---

## Restore Procedures

### Quick Restore (Single Service)

```bash
# List available backups
./scripts/backup.sh --list

# Restore specific backup
./scripts/backup.sh --restore <backup_id>
```

### Full System Restore (New Host)

#### Prerequisites
- Fresh Ubuntu/Debian installation
- Docker and Docker Compose installed
- Backup files accessible

#### Step 1: Prepare Environment

```bash
# Install required packages
sudo apt update && sudo apt install -y docker.io docker-compose curl

# Create backup directory
sudo mkdir -p /opt/homelab-backups

# Restore backup files
# (From your off-site backup location)
```

#### Step 2: Clone Repository

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# Copy and configure environment
cp .env.example .env
nano .env  # Fill in your configuration
```

#### Step 3: Restore Configuration

```bash
# Restore configs from backup
./scripts/backup.sh --restore configs_<timestamp>
```

#### Step 4: Restore Databases

```bash
# Start database services first
docker compose -f stacks/databases/docker-compose.yml up -d

# Wait for databases to be ready
sleep 30

# Restore PostgreSQL
./scripts/backup.sh --restore postgres_<timestamp>

# Restore MariaDB
./scripts/backup.sh --restore mysql_<timestamp>
```

#### Step 5: Restore Volumes

```bash
# Restore Docker volumes
for vol in homelab_postgres_data homelab_redis_data homelab_mariadb_data; do
    ./scripts/backup.sh --restore "vol_${vol}_<timestamp>"
done
```

#### Step 6: Start Services

```bash
# Start base stack
docker compose -f stacks/base/docker-compose.yml up -d

# Start SSO stack
docker compose -f stacks/sso/docker-compose.yml up -d

# Start other stacks as needed
```

---

## Service Recovery Order

### Recommended Restore Sequence

| Order | Stack | Reason | RTO |
|-------|-------|--------|-----|
| 1 | Base | Foundation for all services | 5 min |
| 2 | Databases | All data depends on DB | 10 min |
| 3 | SSO | Authentication required | 5 min |
| 4 | Storage | File services | 5 min |
| 5 | Productivity | User productivity apps | 10 min |
| 6 | Media | Entertainment stack | 10 min |
| 7 | Observability | Monitoring & logs | 5 min |
| 8 | AI | Optional services | 10 min |

### Critical Path

```
Base → Databases → SSO → Productivity → All Others
```

---

## RTO Estimates

### Recovery Time Objectives

| Scenario | Estimated Time | Notes |
|----------|---------------|-------|
| Single volume restore | 5-10 min | Depends on size |
| Database restore | 10-15 min | + time for verification |
| Single service | 5-10 min | Docker restart |
| Full stack restore | 30-60 min | All services |
| New host restore | 60-120 min | Complete rebuild |

### Factors Affecting RTO

- Backup file size
- Network speed (for remote restores)
- Hardware performance
- Number of services
- Data verification requirements

---

## Verification Checklist

### Post-Restore Verification

After any restore operation, verify:

- [ ] **Docker Status**: `docker compose ps` - all services running
- [ ] **Database Connections**: Test database connectivity
- [ ] **Service Health**: Check health endpoints
- [ ] **Authentication**: SSO login works
- [ ] **Data Integrity**: Verify data completeness

### Health Check Commands

```bash
# Check all services
docker compose -f stacks/base/docker-compose.yml ps
docker compose -f stacks/databases/docker-compose.yml ps
docker compose -f stacks/sso/docker-compose.yml ps

# Test database connections
docker exec -it <postgres_container> psql -U postgres -c "SELECT 1"
docker exec -it <mariadb_container> mysql -u root -p -e "SELECT 1"

# Verify backup integrity
./scripts/backup.sh --verify

# Test authentication
curl -I https://auth.yourdomain.com
```

### Monitoring

- Check Uptime Kuma for service status
- Review logs in Grafana/Loki
- Verify backup notifications received

---

## Automated Backups

### Systemd Timer (Recommended)

Install the backup timer for automatic daily backups:

```bash
# Copy service files
sudo cp systemd/homelab-backup.service /etc/systemd/system/
sudo cp systemd/homelab-backup.timer /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable homelab-backup.timer
sudo systemctl start homelab-backup.timer

# Check status
sudo systemctl status homelab-backup.timer
```

### Cron Backup

Alternatively, add to crontab:

```bash
# Edit crontab
crontab -e

# Add this line for daily 2 AM backup
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target all
```

### Notification Setup

Configure ntfy for backup notifications:

```bash
# In .env file, set:
NTFY_URL=https://ntfy.sh
NTFY_TOPIC=homelab-backups
```

---

## Backup Script Usage

### Command Reference

```bash
# Backup all stacks
./scripts/backup.sh --target all

# Backup media stack only
./scripts/backup.sh --target media

# Preview what would be backed up
./scripts/backup.sh --dry-run

# List all backups
./scripts/backup.sh --list

# Verify backup integrity
./scripts/backup.sh --verify

# Restore from backup
./scripts/backup.sh --restore <backup_id>
```

### Environment Variables

Set in `.env`:

```bash
# Backup target (local|s3|b2|sftp|r2)
BACKUP_TARGET=local

# Retention in days
BACKUP_RETENTION_DAYS=7

# Backup directory
BACKUP_DIR=/opt/homelab-backups

# S3 Configuration (if using S3)
S3_ENDPOINT=https://s3.example.com:9000
S3_BUCKET=homelab-backups
S3_ACCESS_KEY=your_access_key
S3_SECRET_KEY=your_secret_key

# B2 Configuration (if using Backblaze B2)
B2_ACCOUNT_ID=your_account_id
B2_ACCOUNT_KEY=your_account_key
B2_BUCKET=homelab-backups
```

---

## Troubleshooting

### Common Issues

#### Backup Fails to Start
- Check Docker daemon is running: `systemctl status docker`
- Verify backup directory exists and is writable
- Check disk space: `df -h`

#### Volume Backup Fails
- Ensure volume exists: `docker volume ls`
- Check volume is not in use

#### Restore Fails
- Verify backup file exists: `./scripts/backup.sh --list`
- Check backup file integrity: `./scripts/backup.sh --verify`
- Ensure enough disk space for restore

#### Remote Backup Upload Fails
- Verify credentials are correct
- Check network connectivity
- Review remote storage quotas

### Get Help

If you encounter issues:

1. Check logs: `journalctl -u homelab-backup -f`
2. Run backup with DEBUG mode: `DEBUG=true ./scripts/backup.sh`
3. Verify configuration in `.env`

---

## Security Notes

- Never commit `.env` file to version control
- Use strong passwords for backup encryption
- Store backup encryption keys securely
- Regularly test restore procedures
- Keep backup access credentials separate

---

## References

- [Restic Documentation](https://restic.readthedocs.io/)
- [Duplicati Documentation](https://duplicati.readthedocs.io/)
- [Docker Volume Backup](https://docs.docker.com/engine/backup/)
- [3-2-1 Backup Strategy](https://www.veeam.com/blog/321-backup-rule.html)

---

*Last updated: 2026-04-06*
*For Issue #12 - Backup & DR*