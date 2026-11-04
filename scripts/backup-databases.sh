#!/usr/bin/env bash
# ==============================================================================
# Automated Database Backup & 7-Day Retention Rotation
# Backs up PostgreSQL (pg_dumpall) and Redis (bgsave)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups/databases}"
DATE_TAG="$(date +'%Y%m%d_%H%M%S')"
TARGET_DIR="${BACKUP_DIR}/${DATE_TAG}"

mkdir -p "${TARGET_DIR}"

echo "[*] Starting Database Backup at $(date)..."

# 1. Backup PostgreSQL
echo "[*] Dumping all PostgreSQL databases..."
docker exec -t postgres pg_dumpall -U "${POSTGRES_USER:-postgres}" > "${TARGET_DIR}/postgres_all_${DATE_TAG}.sql"

# 2. Backup Redis
echo "[*] Triggering Redis background save..."
docker exec -t redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE || true
sleep 3
docker cp redis:/data/dump.rdb "${TARGET_DIR}/redis_dump_${DATE_TAG}.rdb" || true

# 3. Compress Archive
ARCHIVE_FILE="${BACKUP_DIR}/homelab_db_backup_${DATE_TAG}.tar.gz"
echo "[*] Compressing backup to ${ARCHIVE_FILE}..."
tar -czf "${ARCHIVE_FILE}" -C "${BACKUP_DIR}" "${DATE_TAG}"
rm -rf "${TARGET_DIR}"

echo "[+] Backup created: ${ARCHIVE_FILE} ($(du -h "${ARCHIVE_FILE}" | cut -f1))"

# 4. Retention Policy: Keep last 7 days (delete older than 7 days)
echo "[*] Cleaning up backups older than 7 days..."
find "${BACKUP_DIR}" -name "homelab_db_backup_*.tar.gz" -type f -mtime +7 -delete

echo "[+] Backup routine completed successfully."
