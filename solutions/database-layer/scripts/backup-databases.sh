#!/bin/bash
set -e

# Database backup script
# Creates compressed backups of PostgreSQL and Redis
# Retains backups for 7 days

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

echo "=========================================="
echo "Database Backup - $DATE"
echo "=========================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
POSTGRES_BACKUP="$BACKUP_DIR/postgres_$DATE.sql.gz"

if docker exec postgres pg_dumpall -U postgres | gzip > "$POSTGRES_BACKUP"; then
    echo "  PostgreSQL backup created: $POSTGRES_BACKUP"
    echo "  Size: $(du -h "$POSTGRES_BACKUP" | cut -f1)"
else
    echo "  ERROR: PostgreSQL backup failed"
    exit 1
fi

# Backup Redis
echo "Backing up Redis..."
REDIS_BACKUP="$BACKUP_DIR/redis_$DATE.rdb.gz"

# Trigger Redis BGSAVE
docker exec redis redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE > /dev/null 2>&1
sleep 2

# Copy RDB file
if docker exec redis tar czf - /data/dump.rdb | cat > "$REDIS_BACKUP"; then
    echo "  Redis backup created: $REDIS_BACKUP"
    echo "  Size: $(du -h "$REDIS_BACKUP" | cut -f1)"
else
    echo "  WARNING: Redis backup failed (non-critical)"
fi

# Create combined archive
echo "Creating combined archive..."
COMBINED_BACKUP="$BACKUP_DIR/databases_$DATE.tar.gz"
tar czf "$COMBINED_BACKUP" -C "$BACKUP_DIR" "postgres_$DATE.sql.gz" "redis_$DATE.rdb.gz" 2>/dev/null || true

if [ -f "$COMBINED_BACKUP" ]; then
    echo "  Combined backup: $COMBINED_BACKUP"
    echo "  Size: $(du -h "$COMBINED_BACKUP" | cut -f1)"
    
    # Remove individual files
    rm -f "$POSTGRES_BACKUP" "$REDIS_BACKUP"
fi

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "databases_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "postgres_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "redis_*.rdb.gz" -type f -mtime +$RETENTION_DAYS -delete

# Optional: Upload to MinIO
if [ -n "${MINIO_ENDPOINT}" ] && [ -n "${MINIO_ACCESS_KEY}" ]; then
    echo "Uploading to MinIO..."
    if command -v mc > /dev/null 2>&1; then
        mc alias set local "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>/dev/null || true
        mc cp "$COMBINED_BACKUP" "local/${MINIO_BUCKET:-backups}/databases/" 2>/dev/null || echo "  WARNING: MinIO upload failed"
    else
        echo "  WARNING: MinIO client (mc) not installed, skipping upload"
    fi
fi

echo ""
echo "=========================================="
echo "Backup complete!"
echo "=========================================="
echo ""
echo "Backup location: $BACKUP_DIR"
echo "Latest backup: $COMBINED_BACKUP"
echo ""
echo "To restore PostgreSQL:"
echo "  gunzip -c $COMBINED_BACKUP | docker exec -i postgres psql -U postgres"
echo ""
echo "To restore Redis:"
echo "  tar xzf $COMBINED_BACKUP -C /tmp"
echo "  docker cp /tmp/dump.rdb redis:/data/dump.rdb"
echo "  docker exec redis redis-cli -a \${REDIS_PASSWORD} BGSAVE"
echo ""
