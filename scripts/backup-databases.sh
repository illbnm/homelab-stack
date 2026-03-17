#!/bin/bash
#
# backup-databases.sh - Backup all databases
# Creates .tar.gz backups, keeps last 7 days
#

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

echo "=== Database Backup ==="
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
echo ""
echo "=== Backing up PostgreSQL ==="
docker exec postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_all_$TIMESTAMP.sql"
gzip "$BACKUP_DIR/postgres_all_$TIMESTAMP.sql"
echo "✓ PostgreSQL backup: postgres_all_$TIMESTAMP.sql.gz"

# Trigger Redis BGSAVE
echo ""
echo "=== Backing up Redis ==="
docker exec redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE || true
sleep 2
docker exec redis redis-cli -a "${REDIS_PASSWORD}" LASTSAVE > /dev/null
echo "✓ Redis BGSAVE triggered"

# Backup MariaDB
echo ""
echo "=== Backing up MariaDB ==="
docker exec mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > "$BACKUP_DIR/mariadb_all_$TIMESTAMP.sql"
gzip "$BACKUP_DIR/mariadb_all_$TIMESTAMP.sql"
echo "✓ MariaDB backup: mariadb_all_$TIMESTAMP.sql.gz"

# Cleanup old backups (keep last 7 days)
echo ""
echo "=== Cleaning up old backups ==="
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "✓ Old backups cleaned up"

# List current backups
echo ""
echo "=== Current backups ==="
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "No backups found"

echo ""
echo "=== Backup Complete ==="
