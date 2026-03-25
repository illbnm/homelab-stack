#!/bin/bash
set -e

BACKUP_DIR="/opt/homelab/backups/databases"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "Starting database backups..."

# PostgreSQL Backup
if docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
    echo "Backing up PostgreSQL..."
    docker exec postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_$DATE.sql"
    gzip "$BACKUP_DIR/postgres_$DATE.sql"
fi

# Redis Backup
if docker ps --format '{{.Names}}' | grep -q "^redis$"; then
    echo "Backing up Redis..."
    # Trigger BGSAVE and wait a bit
    docker exec redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
    sleep 5
    # Copy dump.rdb
    docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"
    gzip "$BACKUP_DIR/redis_$DATE.rdb"
fi

# MariaDB Backup
if docker ps --format '{{.Names}}' | grep -q "^mariadb$"; then
    echo "Backing up MariaDB..."
    docker exec mariadb sh -c 'exec mysqldump --all-databases -uroot -p"${MARIADB_ROOT_PASSWORD}"' > "$BACKUP_DIR/mariadb_$DATE.sql"
    gzip "$BACKUP_DIR/mariadb_$DATE.sql"
fi

# Bundle them up
echo "Creating bundle..."
tar -czf "$BACKUP_DIR/db_backup_$DATE.tar.gz" -C "$BACKUP_DIR" ./*_$DATE.*

# Cleanup individual files
rm -f "$BACKUP_DIR"/*_$DATE.sql.gz "$BACKUP_DIR"/*_$DATE.rdb.gz

# Keep only last 7 days
find "$BACKUP_DIR" -name "db_backup_*.tar.gz" -type f -mtime +7 -delete

echo "Database backup complete: $BACKUP_DIR/db_backup_$DATE.tar.gz"
