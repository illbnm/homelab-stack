#!/usr/bin/env bash
# Backup all databases
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups/databases}"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== Database Backup: $TIMESTAMP ==="

# PostgreSQL - dump all databases
echo "Backing up PostgreSQL..."
docker exec postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
echo "✓ PostgreSQL backup complete"

# Redis - trigger BGSAVE
echo "Backing up Redis..."
docker exec redis redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE
sleep 2
docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
echo "✓ Redis backup complete"

# MariaDB - dump all databases
echo "Backing up MariaDB..."
docker exec mariadb mariadb-dump -u root -p"${MARIADB_ROOT_PASSWORD:-}" --all-databases | gzip > "$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"
echo "✓ MariaDB backup complete"

# Compress all into single archive
tar -czf "$BACKUP_DIR/databases_${TIMESTAMP}.tar.gz" \
  -C "$BACKUP_DIR" \
  "postgres_${TIMESTAMP}.sql.gz" \
  "redis_${TIMESTAMP}.rdb" \
  "mariadb_${TIMESTAMP}.sql.gz"

# Cleanup individual files
rm -f "$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz" \
      "$BACKUP_DIR/redis_${TIMESTAMP}.rdb" \
      "$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"

# Remove old backups
find "$BACKUP_DIR" -name "databases_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "✓ Backup archive: $BACKUP_DIR/databases_${TIMESTAMP}.tar.gz"
echo "=== Backup complete ==="
