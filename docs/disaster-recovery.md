# Disaster Recovery Guide

This document outlines the disaster recovery procedures for the homelab stack.

## Overview

### Backup Strategy: 3-2-1

- **3** copies of data
- **2** different media types (local + cloud)
- **1** offsite copy (B2/R2)

### Components

| Component | Backup Method | Frequency | Retention |
|-----------|---------------|-----------|-----------|
| PostgreSQL | pg_dumpall | Daily | 7 days |
| Redis | RDB snapshot | Daily | 7 days |
| MariaDB | mysqldump | Daily | 7 days |
| Config files | tar archive | Daily | 30 days |
| Docker volumes | tar archive | Weekly | 4 weeks |
| Media files | Duplicati | Weekly | 4 versions |

## Backup Locations

### Local Storage

```
/var/backups/homelab/
├── backup_YYYYMMDD_HHMMSS.tar.gz    # Combined archive
├── databases/
│   ├── postgres_*.sql.gz
│   ├── redis_*.rdb.gz
│   └── mariadb_*.sql.gz
└── configs/
    └── configs_*.tar.gz
```

### Cloud Storage (Optional)

- **S3**: `s3://${S3_BUCKET}/backups/`
- **B2**: `b2://${B2_BUCKET}/backups/`
- **R2**: `r2://${R2_BUCKET}/backups/`
- **SFTP**: `${SFTP_HOST}:${SFTP_PATH}/`

## Recovery Procedures

### Scenario 1: Database Corruption

**Symptoms:** Application errors, data inconsistency

**Steps:**

```bash
# 1. Stop affected services
docker compose -f stacks/media/docker-compose.yml down
docker compose -f stacks/databases/docker-compose.yml down

# 2. List available backups
./scripts/backup.sh --list

# 3. Restore from backup
./scripts/backup.sh --restore YYYYMMDD_HHMMSS

# 4. Restore PostgreSQL
gunzip -c /var/backups/homelab/restore_*/postgres_*.sql.gz | \
    docker exec -i homelab-postgres psql -U postgres

# 5. Restore Redis (copy RDB file)
gunzip -c /var/backups/homelab/restore_*/redis_*.rdb.gz > \
    /var/lib/docker/volumes/homelab_redis-data/_data/dump.rdb

# 6. Restore MariaDB
gunzip -c /var/backups/homelab/restore_*/mariadb_*.sql.gz | \
    docker exec -i homelab-mariadb mysql -u root -p

# 7. Restart services
docker compose -f stacks/databases/docker-compose.yml up -d
docker compose -f stacks/media/docker-compose.yml up -d
```

### Scenario 2: Complete Server Failure

**Symptoms:** Server unreachable, hardware failure

**Steps:**

```bash
# 1. Provision new server with same OS

# 2. Install Docker and Docker Compose
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER

# 3. Clone homelab-stack
git clone https://github.com/YOUR_REPO/homelab-stack.git
cd homelab-stack

# 4. Restore .env from backup
tar -xzf configs_*.tar.gz .env

# 5. Start databases first
docker compose -f stacks/databases/docker-compose.yml up -d
./scripts/init-databases.sh

# 6. Restore databases from backup
# (Follow Scenario 1 steps 4-6)

# 7. Start remaining stacks
docker compose -f stacks/base/docker-compose.yml up -d
docker compose -f stacks/sso/docker-compose.yml up -d
docker compose -f stacks/media/docker-compose.yml up -d

# 8. Verify all services
docker ps
curl -sf http://localhost:8080/health
```

### Scenario 3: Ransomware Attack

**Symptoms:** Files encrypted, ransom note

**Steps:**

```bash
# 1. Disconnect from network immediately
# 2. Do NOT pay ransom

# 3. Wipe affected systems
# Assuming backups are on isolated storage

# 4. Reinstall from scratch
# (Follow Scenario 2 steps)

# 5. Restore from verified clean backup
# Check backup dates before encryption

# 6. Change all passwords
# Regenerate all tokens and secrets

# 7. Enable additional monitoring
# Review security logs
```

### Scenario 4: Accidental Data Deletion

**Symptoms:** Missing files, empty databases

**Steps:**

```bash
# 1. Stop affected service immediately
docker compose -f stacks/APP/docker-compose.yml down

# 2. Identify the backup with data
./scripts/backup.sh --list

# 3. Restore specific database
gunzip -c /var/backups/homelab/databases/postgres_YYYYMMDD.sql.gz | \
    docker exec -i homelab-postgres psql -U postgres -d affected_db

# 4. Verify data restored
docker exec -it homelab-postgres psql -U postgres -d affected_db -c "SELECT count(*) FROM table;"

# 5. Restart service
docker compose -f stacks/APP/docker-compose.yml up -d
```

## Testing Backups

### Monthly Backup Test

```bash
#!/bin/bash
# Test backup integrity monthly

# 1. Verify archive
./scripts/backup.sh --verify

# 2. Test restore (dry run)
./scripts/backup.sh --restore latest --dry-run

# 3. Check backup sizes
du -sh /var/backups/homelab/

# 4. Verify cloud upload
aws s3 ls s3://${S3_BUCKET}/backups/ | tail -5

# 5. Send test notification
./scripts/notify.sh backups "Backup Test" "Monthly backup verification completed"
```

## Scheduled Backups

### Crontab Configuration

```bash
# Edit crontab
crontab -e

# Add backup jobs
# Daily database backup at 2:00 AM
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target databases >> /var/log/backup.log 2>&1

# Weekly full backup on Sunday at 3:00 AM
0 3 * * 0 /path/to/homelab-stack/scripts/backup.sh --target all >> /var/log/backup.log 2>&1

# Monthly backup test on 1st at 4:00 AM
0 4 1 * * /path/to/homelab-stack/scripts/backup.sh --verify >> /var/log/backup-test.log 2>&1
```

### Systemd Timer (Alternative)

```bash
# /etc/systemd/system/homelab-backup.service
[Unit]
Description=Homelab Backup
After=docker.service

[Service]
Type=oneshot
ExecStart=/path/to/homelab-stack/scripts/backup.sh --target all
User=root

# /etc/systemd/system/homelab-backup.timer
[Unit]
Description=Daily Homelab Backup

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target

# Enable
systemctl enable --now homelab-backup.timer
```

## Monitoring and Alerts

### Backup Failure Notification

The backup script sends notifications via ntfy on:
- Backup completion
- Backup failure
- Restore operations

### Monitoring Checklist

- [ ] Backup script runs without errors
- [ ] Backup files are created with correct size
- [ ] Archive integrity verified
- [ ] Cloud upload successful
- [ ] Retention policy working (old backups deleted)
- [ ] Recovery procedure tested quarterly

## Contact Information

| Role | Contact |
|------|---------|
| Primary Admin | [Your Email] |
| Backup Storage | [S3/B2 Provider Support] |
| Server Hosting | [Hosting Provider Support] |

## Appendix: Backup Script Options

```bash
# Backup all
./scripts/backup.sh --target all

# Backup only databases
./scripts/backup.sh --target databases

# Dry run (show what would happen)
./scripts/backup.sh --target all --dry-run

# List backups
./scripts/backup.sh --list

# Verify latest backup
./scripts/backup.sh --verify

# Restore specific backup
./scripts/backup.sh --restore YYYYMMDD_HHMMSS
```
