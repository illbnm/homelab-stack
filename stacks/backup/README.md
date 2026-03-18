# Backup & Disaster Recovery Stack

Complete 3-2-1 backup solution for HomeLab Stack.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Duplicati | 2.0.8 | `backup.<DOMAIN>` | Encrypted cloud backup with GUI |
| Restic REST Server | 0.13.0 | — | Local backup repository API |
| backup.sh | — | CLI | Automated backup/restore script |

## 3-2-1 Backup Strategy

```
3 Copies               2 Media Types        1 Offsite
─────────────────────   ──────────────────   ─────────────────
① Live data (Docker)    ① Local disk         ① Cloud storage
② Local backup (Restic) ② Cloud / NAS        (S3/B2/R2/SFTP)
③ Cloud backup (Duplicati)
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    backup.sh                        │
│  CLI for automated backup/restore/verify/list       │
│  Supports: local, S3, B2, SFTP, R2                 │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
┌──────────────┐ ┌─────────┐ ┌───────────────┐
│ Docker       │ │ Database│ │ Config Files  │
│ Volumes      │ │ Dumps   │ │ (.env, yml)   │
│ tar.gz       │ │ pg/redis│ │ tar.gz        │
└──────┬───────┘ └────┬────┘ └──────┬────────┘
       │              │             │
       ▼              ▼             ▼
┌─────────────────────────────────────────────────────┐
│          /opt/homelab-backups/backup_YYYYMMDD_HHMMSS│
│  ├── volumes/                                        │
│  ├── databases/                                      │
│  ├── configs.tar.gz                                  │
│  ├── checksums.sha256                                │
│  └── backup.meta (JSON)                             │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │  Local  │ │   S3    │ │  SFTP   │
    │  Disk   │ │ B2 / R2 │ │  NAS    │
    └─────────┘ └─────────┘ └─────────┘
```

## Quick Start

```bash
# 1. Deploy backup services
cp stacks/backup/.env.example stacks/backup/.env
# Edit stacks/backup/.env
docker compose -f stacks/backup/docker-compose.yml up -d

# 2. Run first backup
./scripts/backup.sh --target all

# 3. Verify backup
./scripts/backup.sh --verify

# 4. Set up automatic daily backups
sudo cp scripts/homelab-backup.cron /etc/cron.d/homelab-backup
# Or use systemd timer:
sudo cp scripts/homelab-backup.timer /etc/systemd/system/
sudo cp scripts/homelab-backup.service /etc/systemd/system/
sudo systemctl enable --now homelab-backup.timer
```

## backup.sh — CLI Reference

### Backup

```bash
# Backup all stacks
./scripts/backup.sh --target all

# Backup specific stack
./scripts/backup.sh --target databases
./scripts/backup.sh --target media

# Dry run — preview what would be backed up
./scripts/backup.sh --target all --dry-run
```

### List Backups

```bash
./scripts/backup.sh --list
```

Output:
```
═══ Available Backups ═══
  backup_20240315_020000 (1.2G) | target=all | 2024-03-15T02:00:00Z
  backup_20240316_020000 (1.3G) | target=all | 2024-03-16T02:00:00Z
```

### Verify Backup Integrity

```bash
# Verify latest
./scripts/backup.sh --verify

# Verify specific
./scripts/backup.sh --verify backup_20240315_020000
```

Checks:
- Metadata file exists and is valid JSON
- SHA-256 checksums match for all files
- All tar.gz and sql.gz archives are intact

### Restore

```bash
./scripts/backup.sh --restore backup_20240315_020000
```

The restore process:
1. Downloads from remote if not local
2. Decrypts if encrypted
3. Verifies checksums
4. Shows what will be restored
5. Asks for confirmation
6. Restores configs → volumes → databases (in order)

## Backup Targets

### Local (default)

```bash
BACKUP_TARGET=local
BACKUP_DIR=/opt/homelab-backups
```

### MinIO / S3

```bash
BACKUP_TARGET=s3
BACKUP_S3_ENDPOINT=http://minio.home.example.com:9000
BACKUP_S3_BUCKET=homelab-backups
BACKUP_S3_ACCESS_KEY=minioadmin
BACKUP_S3_SECRET_KEY=minioadmin
```

### Backblaze B2

```bash
BACKUP_TARGET=b2
BACKUP_B2_BUCKET=homelab-backups
BACKUP_B2_KEY_ID=your-key-id
BACKUP_B2_APPLICATION_KEY=your-application-key
```

### SFTP / NAS

```bash
BACKUP_TARGET=sftp
BACKUP_SFTP_HOST=nas.local
BACKUP_SFTP_USER=backup
BACKUP_SFTP_PATH=/volume1/backups
BACKUP_SFTP_KEY=~/.ssh/id_rsa
```

### Cloudflare R2

```bash
BACKUP_TARGET=r2
BACKUP_R2_ENDPOINT=https://ACCOUNT_ID.r2.cloudflarestorage.com
BACKUP_R2_BUCKET=homelab-backups
BACKUP_R2_ACCESS_KEY=your-r2-access-key
BACKUP_R2_SECRET_KEY=your-r2-secret-key
```

## Encryption

Enable AES-256-CBC encryption for backup archives:

```bash
BACKUP_ENCRYPT=true
BACKUP_ENCRYPTION_KEY=your-secure-passphrase-minimum-32-chars
```

**⚠️ Store the encryption key safely! Without it, backups cannot be decrypted.**

## Scheduled Backups

### Cron (recommended for most setups)

```bash
sudo cp scripts/homelab-backup.cron /etc/cron.d/homelab-backup
```

Default: daily at 2:00 AM.

### Systemd Timer

```bash
sudo cp scripts/homelab-backup.timer /etc/systemd/system/
sudo cp scripts/homelab-backup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer

# Check timer status
systemctl list-timers homelab-backup.timer
```

## Notifications

Backup completion/failure notifications via ntfy:

```bash
NTFY_URL=https://ntfy.home.example.com
NTFY_BACKUP_TOPIC=homelab-backup
```

Or use the unified `scripts/notify.sh` interface (auto-detected if present).

Notification events:
- ✅ Backup complete (with size + duration)
- ⚠️ Partial backup (with warning count)
- ❌ Backup failed (with error details)
- 🔄 Restore complete
- ✅ Verification passed

## What Gets Backed Up

| Stack | Volumes | Databases | Config |
|-------|---------|-----------|--------|
| base | portainer-data, traefik-logs | — | ✅ |
| network | adguard-data/conf, npm-data | — | ✅ |
| storage | nextcloud-html, minio-data, filebrowser | PostgreSQL | ✅ |
| databases | postgres/redis/mariadb-data | PostgreSQL, Redis, MariaDB | ✅ |
| media | jellyfin, *arr configs | — | ✅ |
| monitoring | prometheus, grafana, loki, alertmanager | — | ✅ |
| productivity | gitea, vaultwarden, outline, bookstack | PostgreSQL | ✅ |
| ai | ollama-data, open-webui-data | — | ✅ |
| sso | authentik-postgres/redis/media | PostgreSQL, Redis | ✅ |
| home-automation | hass, nodered, mosquitto, zigbee2mqtt | — | ✅ |
| notifications | ntfy-data/cache, apprise-config | — | ✅ |

## Duplicati Web UI

Access at `https://backup.<DOMAIN>`:

1. **Add Backup** → Choose destination (S3, B2, Google Drive, etc.)
2. **Source Data** → Select `/source/docker-volumes/` and `/source/config/`
3. **Schedule** → Set backup frequency
4. **Encryption** → Built-in AES-256 encryption
5. **Options** → Set retention policy, bandwidth limits, etc.

### Duplicati + MinIO Integration

```
Storage Type: S3 Compatible
Server: minio.home.example.com:9000
Bucket: homelab-backups
AWS Access ID: minioadmin
AWS Access Key: minioadmin
Use SSL: ☑ (if behind Traefik)
```

## Troubleshooting

### Backup fails for a specific volume
```bash
# Check if volume exists
docker volume ls | grep volume-name

# Check volume contents
docker run --rm -v volume-name:/data alpine ls -la /data
```

### Database dump fails
```bash
# Check if container is running
docker ps | grep postgres

# Test connection manually
docker exec homelab-postgres pg_isready
```

### Remote upload fails
```bash
# Test S3 connectivity
aws s3 ls --endpoint-url $BACKUP_S3_ENDPOINT s3://$BACKUP_S3_BUCKET/

# Test SFTP connectivity
ssh -i $BACKUP_SFTP_KEY $BACKUP_SFTP_USER@$BACKUP_SFTP_HOST ls $BACKUP_SFTP_PATH
```

### Restore failed — container not running
Start the target stack first, then restore:
```bash
docker compose -f stacks/databases/docker-compose.yml up -d
sleep 10  # Wait for containers to be healthy
./scripts/backup.sh --restore backup_20240315_020000
```
