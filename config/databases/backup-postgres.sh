#!/bin/bash
# =============================================================================
# HomeLab Stack — PostgreSQL Backup Script
# Backs up all PostgreSQL databases to a specified directory.
#
# Usage:
#   ./backup-postgres.sh [backup_dir]
#
# Environment variables:
#   POSTGRES_HOST      - PostgreSQL host (default: homelab-postgres)
#   POSTGRES_PORT      - PostgreSQL port (default: 5432)
#   POSTGRES_USER      - PostgreSQL user (default: postgres)
#   POSTGRES_DB        - Default database (default: postgres)
#   POSTGRES_PASSWORD  - PostgreSQL password
#   POSTGRES_BACKUP_PASSWORD - GPG encryption password (optional)
#
# Cron example (daily at 2am):
#   0 2 * * * cd /opt/homelab/stacks/databases && ./config/backup-postgres.sh /opt/homelab/backups/postgres >> /var/log/postgres-backup.log 2>&1
# =============================================================================

set -euo pipefail

BACKUP_DIR="${1:-${BACKUP_DIR:-/opt/homelab/backups/postgres}}"
POSTGRES_HOST="${POSTGRES_HOST:-homelab-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_all_${TIMESTAMP}.sql.gz"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Create backup dir
mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Starting PostgreSQL backup..."

# List all databases
DATABASES=$(docker exec "${POSTGRES_HOST}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1')" 2>/dev/null || echo "")

# Backup all databases
ALL_DBS="postgres ${DATABASES}"
BACKUP_LIST="${BACKUP_DIR}/postgres_all_${TIMESTAMP}.list"

for db in ${ALL_DBS}; do
    db=$(echo "${db}" | tr -d ' ')
    if [ -z "${db}" ]; then continue; fi
    
    echo "  Backing up database: ${db}"
    docker exec "${POSTGRES_HOST}" pg_dump -U "${POSTGRES_USER}" -d "${db}" 2>/dev/null | gzip >> "${BACKUP_FILE}.tmp" || {
        echo "  WARNING: Failed to backup ${db}, skipping..."
    }
done

# Rename temp file
mv "${BACKUP_FILE}.tmp" "${BACKUP_FILE}"

# GPG encrypt if password provided
if [ -n "${POSTGRES_BACKUP_PASSWORD:-}" ]; then
    echo "[$(date)] Encrypting backup with GPG..."
    mv "${BACKUP_FILE}" "${BACKUP_FILE}.tmp"
    echo "${POSTGRES_BACKUP_PASSWORD}" | gpg --batch --yes --passphrase-fd 0 --compress-algo none -c -o "${BACKUP_FILE}" "${BACKUP_FILE}.tmp"
    rm -f "${BACKUP_FILE}.tmp"
    BACKUP_FILE="${BACKUP_FILE}.gpg"
fi

# Save backup list
echo "${ALL_DBS}" | tr ' ' '\n' > "${BACKUP_LIST}"

# Cleanup old backups
echo "[$(date)] Cleaning up backups older than ${KEEP_DAYS} days..."
find "${BACKUP_DIR}" -name "postgres_all_*.sql.gz*" -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true
find "${BACKUP_DIR}" -name "postgres_all_*.list" -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true

echo "[$(date)] Backup complete: ${BACKUP_FILE}"
echo "[$(date)] Backup size: $(du -h "${BACKUP_FILE}" | cut -f1)"
