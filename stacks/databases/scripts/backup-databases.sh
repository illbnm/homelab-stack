#!/usr/bin/env bash
# =============================================================================
# backup-databases.sh — Backup all databases, retain 7 days
# =============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups/databases}"
DATE=$(date +%Y%m%d_%H%M%S)
RETAIN_DAYS=${RETAIN_DAYS:-7}

mkdir -p "$BACKUP_DIR"

echo "=== Database Backup — $DATE ==="

# PostgreSQL full dump
echo "Backing up PostgreSQL..."
docker exec postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgres_$DATE.sql.gz"
echo "  ✅ PostgreSQL → postgres_$DATE.sql.gz"

# Redis trigger save
echo "Backing up Redis..."
docker exec redis redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE
sleep 2
docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"
echo "  ✅ Redis → redis_$DATE.rdb"

# MariaDB dump
if docker inspect mariadb &>/dev/null; then
  echo "Backing up MariaDB..."
  docker exec mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD:-}" --all-databases | gzip > "$BACKUP_DIR/mariadb_$DATE.sql.gz"
  echo "  ✅ MariaDB → mariadb_$DATE.sql.gz"
fi

# Bundle into single archive
tar -czf "$BACKUP_DIR/db_backup_$DATE.tar.gz" -C "$BACKUP_DIR" \
  "postgres_$DATE.sql.gz" \
  "redis_$DATE.rdb" 2>/dev/null || true
rm -f "$BACKUP_DIR/postgres_$DATE.sql.gz" "$BACKUP_DIR/redis_$DATE.rdb" "$BACKUP_DIR/mariadb_$DATE.sql.gz" 2>/dev/null || true

echo "Backup archive: $BACKUP_DIR/db_backup_$DATE.tar.gz"

# Prune old backups
echo "Pruning backups older than $RETAIN_DAYS days..."
find "$BACKUP_DIR" -name "db_backup_*.tar.gz" -mtime +$RETAIN_DAYS -delete
echo "✅ Backup complete"
