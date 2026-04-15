# Disaster Recovery Guide

## Overview

This stack implements a **3-2-1 backup strategy**:

| Rule | Implementation |
|------|----------------|
| **3** copies | Original data + Duplicati (cloud) + Restic (local) |
| **2** media types | Disk (local Restic) + Cloud (Duplicati remote destinations) |
| **1** offsite | Duplicati encrypted uploads to S3/B2/SFTP |

---

## Backup Components

### 1. Duplicati — Encrypted Cloud Backup
- **Purpose**: Long-term encrypted backup to cloud storage
- **UI**: `https://duplicati.yourdomain.com`
- **Destinations**: S3, Backblaze B2, SFTP, Google Drive, Azure Blob
- **Encryption**: AES-256 built-in

### 2. Restic — Fast Local Deduplicated Backup
- **Purpose**: Fast incremental local backups with deduplication
- **Repository**: `/backups/restic/repo`
- **Features**: Snapshots, deduplication, encryption

---

## Recovery Procedures

### Scenario 1: Single File Recovery (Restic)

```bash
# List snapshots
./scripts/backup.sh --list

# Restore specific snapshot to /restore
./scripts/backup.sh --restore restic <SNAPSHOT_ID>

# Browse and copy files
ls /restore/data/
cp /restore/data/important-file.txt /data/
```

### Scenario 2: Full System Restore (Restic)

```bash
# 1. Verify backup integrity
./scripts/backup.sh --verify

# 2. Restore to temporary location
./scripts/backup.sh --restore restic latest

# 3. Stop services
docker compose down

# 4. Replace data
mv /data /data.old
mv /restore/data /data

# 5. Restart services
docker compose up -d
```

### Scenario 3: Cloud Recovery (Duplicati)

1. Access Duplicati web UI at `https://duplicati.yourdomain.com`
2. Go to **Restore** → Select backup job
3. Choose destination and files to restore
4. Enter encryption passphrase
5. Click **Restore**

### Scenario 4: Complete Disaster (New Server)

```bash
# 1. Install Docker + Docker Compose
# 2. Clone this repo
git clone <repo-url> && cd homelab-stack

# 3. Configure environment
cp stacks/backup/.env.example stacks/backup/.env
# Edit .env with your settings

# 4. Start backup stack first
cd stacks/backup && docker compose up -d

# 5. Restore from Duplicati cloud backup via web UI
# OR restore from Restic if local storage survived

# 6. Start remaining stacks
cd ../.. && docker compose up -d
```

---

## Maintenance

### Weekly Checks

```bash
# Verify backup integrity
./scripts/backup.sh --verify

# Check backup sizes
du -sh /backups/restic/repo
du -sh /backups/duplicati

# Review logs
tail -50 /backups/backup.log
```

### Monthly Tasks

- Test restore procedure (pick random file, restore, verify)
- Review retention policy effectiveness
- Check cloud storage costs
- Update encryption keys if rotated

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Restic repo locked | `restic -r /backups/restic/repo unlock` |
| Duplicati UI inaccessible | Check Traefik labels and DNS resolution |
| Backup too slow | Exclude large temp dirs via `--exclude` flag |
| Out of disk space | Run `./scripts/backup.sh --cleanup` |
| Restore fails integrity | Try `restic -r repo rebuild-index` |

---

## Retention Policy

| Period | Keep | Managed By |
|--------|------|------------|
| Daily | 7 | Restic `--keep-daily 7` |
| Weekly | 4 | Restic `--keep-weekly 4` |
| Monthly | 12 | Restic `--keep-monthly 12` |

Duplicati retention is configured per backup job in the web UI.
