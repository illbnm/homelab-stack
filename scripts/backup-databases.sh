#!/bin/bash

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%F_%T")
BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.tar.gz"

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
pg_dumpall -U postgres -h postgres > $BACKUP_DIR/postgres_backup.sql

# Backup Redis
redis-cli -h redis BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_backup.rdb

# Create tar.gz
tar -czf $BACKUP_FILE -C $BACKUP_DIR postgres_backup.sql redis_backup.rdb

# Remove old backups
find $BACKUP_DIR -type f -name "db_backup_*.tar.gz" -mtime +7 -exec rm {} \;

echo "Backup completed: $BACKUP_FILE"

exit 0