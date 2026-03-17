#!/bin/bash

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%F_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/databases_backup_$TIMESTAMP.tar.gz"

mkdir -p $BACKUP_DIR

pg_dumpall -U postgres > $BACKUP_DIR/postgres_backup.sql
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_backup.rdb

tar -czvf $BACKUP_FILE -C $BACKUP_DIR postgres_backup.sql redis_backup.rdb

find $BACKUP_DIR -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Backup completed and old backups cleaned up."

exit 0