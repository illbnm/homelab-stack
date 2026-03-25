#!/bin/bash
# backup-databases.sh - Backup all databases
# Keeps last 7 days of backups

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -E '^[A-Z]' "$ENV_FILE" | xargs)
fi

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/databases_${TIMESTAMP}"
RETENTION_DAYS=7

# PostgreSQL settings
PG_HOST="${PG_HOST:-postgres}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${POSTGRES_ROOT_USER:-postgres}"
PG_PASSWORD="${POSTGRES_ROOT_PASSWORD}"

# Redis settings
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PASSWORD="${REDIS_PASSWORD}"

echo "=== Database Backup Started at $(date) ==="
echo ""

# Create backup directory
mkdir -p "${BACKUP_PATH}"

# Export PGPASSWORD for psql
export PGPASSWORD="${PG_PASSWORD}"

# Backup PostgreSQL
echo "--- Backing up PostgreSQL ---"
pg_dumpall -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" | gzip > "${BACKUP_PATH}/postgresql_all.gz"
echo "  PostgreSQL backup: ${BACKUP_PATH}/postgresql_all.gz"
echo "  Size: $(du -h "${BACKUP_PATH}/postgresql_all.gz" | cut -f1)"

# Trigger Redis persistence
echo ""
echo "--- Triggering Redis persistence ---"
redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null || true
echo "  Redis BGSAVE triggered"

# Wait a moment for Redis to finish
sleep 2

# Backup Redis
echo ""
echo "--- Backing up Redis ---"
redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" --rdb "${BACKUP_PATH}/redis.rdb" 2>/dev/null || true
if [ -f "${BACKUP_PATH}/redis.rdb" ]; then
    gzip "${BACKUP_PATH}/redis.rdb"
    echo "  Redis backup: ${BACKUP_PATH}/redis.rdb.gz"
    echo "  Size: $(du -h "${BACKUP_PATH}/redis.rdb.gz" | cut -f1)"
fi

# MariaDB backup (if enabled)
if [ -n "${MARIADB_ROOT_PASSWORD}" ]; then
    echo ""
    echo "--- Backing up MariaDB ---"
    mariadb-backup --host=mariadb --user=root --password="${MARIADB_ROOT_PASSWORD}" --backup --target-dir="${BACKUP_PATH}/mariadb" 2>/dev/null || {
        echo "  MariaDB backup skipped (container may not be running)"
    }
    if [ -d "${BACKUP_PATH}/mariadb" ]; then
        tar -czf "${BACKUP_PATH}/mariadb.tar.gz" -C "${BACKUP_PATH}/mariadb" .
        rm -rf "${BACKUP_PATH}/mariadb"
        echo "  MariaDB backup: ${BACKUP_PATH}/mariadb.tar.gz"
        echo "  Size: $(du -h "${BACKUP_PATH}/mariadb.tar.gz" | cut -f1)"
    fi
fi

# Create backup manifest
echo ""
echo "--- Creating backup manifest ---"
cat > "${BACKUP_PATH}/manifest.txt" << EOF
Backup created: $(date)
Hostname: $(hostname)
PostgreSQL: ${PG_HOST}:${PG_PORT}
Redis: ${REDIS_HOST}
EOF
echo "  Manifest created"

# Create latest symlink
ln -sfn "${BACKUP_PATH}" "${BACKUP_DIR}/latest"

# Cleanup old backups
echo ""
echo "--- Cleaning up backups older than ${RETENTION_DAYS} days ---"
find "${BACKUP_DIR}" -maxdepth 1 -type d -name "databases_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true
echo "  Cleanup complete"

echo ""
echo "=== Backup Completed Successfully! ==="
echo "Backup location: ${BACKUP_PATH}"
echo "Latest symlink: ${BACKUP_DIR}/latest"
echo ""

# Optional: Upload to MinIO
if [ -n "${MINIO_ENDPOINT}" ] && [ -n "${MINIO_ACCESS_KEY}" ]; then
    echo "--- Uploading to MinIO ---"
    mc alias set homelab "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>/dev/null || true
    mc cp -r "${BACKUP_PATH}" "homelab/databases/" 2>/dev/null && echo "  Uploaded to MinIO" || echo "  MinIO upload skipped"
fi

unset PGPASSWORD
