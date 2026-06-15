# Backup & Disaster Recovery

HomeLab Stack implements a **3-2-1 backup strategy**: 3 copies of data, 2 different media types, 1 offsite location.

## Backup Services

### Duplicati (Cloud Backup)

- Web UI: `https://duplicati.<DOMAIN>`
- Encrypted backups to cloud storage (S3, Backblaze B2, Google Drive, etc.)
- Configure via the web interface

### Restic REST Server (Local Backup)

- Local backup repository (HTTP REST server)
- Available at `http://restic-rest-server:8000` (internal network)
- Use with `restic` CLI or `restic backup` scripts

## Backup Script

Use the `scripts/backup.sh` script to backup Docker volumes.

### Usage

```bash
# Backup all volumes
./scripts/backup.sh --target all

# Backup volumes of a specific stack
./scripts/backup.sh --target monitoring

# Dry-run mode (show what would be done)
./scripts/backup.sh --target all --dry-run

# Keep backups for 14 days
./scripts/backup.sh --target all --retention 14
```

### How it works

1. The script identifies Docker volumes based on the target name (prefix matching).
2. For each volume, it creates a compressed tar.gz archive using a temporary Alpine container.
3. Archives are stored in `backups/volumes/<target>/<timestamp>/`.
4. A SHA256 checksum file is created for each archive.
5. Old backups older than `--retention` days are automatically deleted.

### Scheduling (cron)

Add to crontab for automated daily backups:

```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/homelab-stack && ./scripts/backup.sh --target all --retention 7 >> /var/log/homelab-backup.log 2>&1
```

## Restore

### Restore a single volume

```bash
# List available backups
ls -la backups/volumes/all/

# Restore from a backup
BACKUP_FILE="backups/volumes/all/20250315_020000/prometheus_data.tar.gz"
docker run --rm \
  -v prometheus_data:/target \
  -v $(pwd)/backups:/backups:ro \
  alpine sh -c "tar xzf /backups/volumes/all/20250315_020000/prometheus_data.tar.gz -C /target"
```

### Disaster Recovery

In case of complete server failure:

1. Reinstall Docker and Docker Compose.
2. Clone the homelab-stack repository.
3. Restore the `.env` file from your offsite backup.
4. Restore all volumes from the latest backup archives.
5. Start infrastructure and stacks.

## Best Practices

- Set up Duplicati to send encrypted backups to an offsite location (e.g., Backblaze B2, S3).
- Schedule regular backups via cron.
- Test restore procedure regularly (at least monthly).
- Keep a copy of `.env` in your password manager or offline.
