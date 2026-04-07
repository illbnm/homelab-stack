#!/bin/bash
# =============================================================================
# Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/mnt/backups/databases}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.tar.gz"

# MinIO configuration (optional)
MINIO_ENABLED="${MINIO_ENABLED:-false}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/temp"

echo "[backup] Starting database backup..."
echo "[backup] Timestamp: ${TIMESTAMP}"

# =============================================================================
# PostgreSQL Backup
# =============================================================================
echo "[backup] Backing up PostgreSQL..."
docker exec homelab-postgres pg_dumpall -U postgres > "${BACKUP_DIR}/temp/postgres_dump.sql" 2>/dev/null || {
    echo "[backup] ERROR: PostgreSQL backup failed"
    exit 1
}
echo "[backup] ✓ PostgreSQL backup complete"

# =============================================================================
# Redis Backup
# =============================================================================
echo "[backup] Backing up Redis..."
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null || {
    echo "[backup] WARNING: Redis BGSAVE failed, copying existing dump"
}
# Wait for Redis to finish saving
sleep 5
# Copy Redis dump file
docker cp homelab-redis:/data/dump.rdb "${BACKUP_DIR}/temp/redis_dump.rdb" 2>/dev/null || {
    echo "[backup] WARNING: Redis dump file not found"
}
echo "[backup] ✓ Redis backup complete"

# =============================================================================
# MariaDB Backup
# =============================================================================
echo "[backup] Backing up MariaDB..."
docker exec homelab-mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > "${BACKUP_DIR}/temp/mariadb_dump.sql" 2>/dev/null || {
    echo "[backup] WARNING: MariaDB backup failed (may not be in use)"
}
echo "[backup] ✓ MariaDB backup complete"

# =============================================================================
# Create compressed archive
# =============================================================================
echo "[backup] Creating compressed archive..."
tar -czf "${BACKUP_FILE}" -C "${BACKUP_DIR}/temp" . 2>/dev/null || {
    echo "[backup] ERROR: Failed to create archive"
    exit 1
}

# Calculate checksum
sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"

# Cleanup temp files
rm -rf "${BACKUP_DIR}/temp"

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[backup] ✓ Archive created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# =============================================================================
# Retention policy - Remove old backups
# =============================================================================
echo "[backup] Applying retention policy (${RETENTION_DAYS} days)..."
find "${BACKUP_DIR}" -name "db_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_DIR}" -name "db_backup_*.sha256" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
echo "[backup] ✓ Old backups removed"

# =============================================================================
# Optional: Upload to MinIO
# =============================================================================
if [ "${MINIO_ENABLED}" = "true" ] && [ -n "${MINIO_ENDPOINT}" ]; then
    echo "[backup] Uploading to MinIO..."
    if command -v mc &> /dev/null; then
        mc alias set minio "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>/dev/null
        mc cp "${BACKUP_FILE}" "minio/${MINIO_BUCKET}/databases/" 2>/dev/null || {
            echo "[backup] WARNING: MinIO upload failed"
        }
        echo "[backup] ✓ Uploaded to MinIO"
    else
        echo "[backup] WARNING: mc (MinIO Client) not found, skipping upload"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "db_backup_*.tar.gz" | wc -l)

echo "[backup] ========================================"
echo "[backup] Backup completed successfully!"
echo "[backup] ========================================"
echo "[backup] Archive: ${BACKUP_FILE}"
echo "[backup] Size: ${BACKUP_SIZE}"
echo "[backup] Retention: ${RETENTION_DAYS} days"
echo "[backup] Total backups: ${BACKUP_COUNT}"
echo "[backup] Total storage: ${TOTAL_SIZE}"
echo "[backup] ========================================"
