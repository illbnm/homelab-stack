# Backup & DR

Automated volume + database backups with rotation.

## Usage

```bash
# Full backup (volumes + config)
./scripts/backup.sh

# Database-only backup
./scripts/backup-databases.sh

# Restore from backup
tar -xzf backups/homelab-backup-YYYYMMDD-HHMMSS.tar.gz -C /
```
