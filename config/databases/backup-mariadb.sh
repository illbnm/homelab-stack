#!/bin/bash
# =============================================================================
# HomeLab Stack — MariaDB Backup Script
# Backs up all MariaDB databases to a specified directory.
#
# Usage:
#   ./backup-mariadb.sh [backup_dir]
#
# Environment variables:
#   MARIADB_HOST         - MariaDB host (default: homelab-mariadb)
#   MARIADB_ROOT_USER    - MariaDB root user (default: root)
#   MARIADB_ROOT_PASSWORD - MariaDB root password
#
# Cron example (daily at 3am):
#   0 3 * * * cd /opt/homelab/stacks/databases && ./config/backup-mariadb.sh /opt/homelab/backups/mariadb >> /var/log/mariadb-backup.log 2>&1
# =============================================================================

set -euo pipefail

BACKUP_DIR="${1:-${BACKUP_DIR:-/opt/homelab/backups/mariadb}}"
MARIADB_HOST="${MARIADB_HOST:-homelab-mariadb}"
MARIADB_ROOT_USER="${MARIADB_ROOT_USER:-root}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/mariadb_all_${TIMESTAMP}.sql.gz"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Create backup dir
mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Starting MariaDB backup..."

# Get all databases
DATABASES=$(docker exec "${MARIADB_HOST}" mysql -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -N -e "SHOW DATABASES" 2>/dev/null | grep -v information_schema | grep -v performance_schema | grep -v mysql | grep -v sys || echo "")

# Backup each database
for db in ${DATABASES}; do
    db=$(echo "${db}" | tr -d ' ')
    if [ -z "${db}" ]; then continue; fi
    
    echo "  Backing up database: ${db}"
    docker exec "${MARIADB_HOST}" mysqldump -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" \
        --single-transaction --quick --lock-tables=false \
        --routines --triggers --events \
        "${db}" 2>/dev/null | gzip >> "${BACKUP_FILE}.tmp" || {
        echo "  WARNING: Failed to backup ${db}, skipping..."
    }
done

# If no databases, create empty file marker
if [ ! -f "${BACKUP_FILE}.tmp" ]; then
    echo "-- No databases to backup at ${TIMESTAMP}" | gzip > "${BACKUP_FILE}.tmp"
fi

# Rename temp file
mv "${BACKUP_FILE}.tmp" "${BACKUP_FILE}"

# Cleanup old backups
echo "[$(date)] Cleaning up backups older than ${KEEP_DAYS} days..."
find "${BACKUP_DIR}" -name "mariadb_all_*.sql.gz" -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true

echo "[$(date)] Backup complete: ${BACKUP_FILE}"
echo "[$(date)] Backup size: $(du -h "${BACKUP_FILE}" | cut -f1)"
