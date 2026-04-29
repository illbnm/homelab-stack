#!/usr/bin/env bash
# =============================================================================
# backup-databases.sh — Backup all databases (PostgreSQL + Redis + MariaDB)
#
# Usage:
#   ./backup-databases.sh [--output DIR] [--keep DAYS] [--minio BUCKET]
#
# Options:
#   --output DIR    Backup output directory (default: ./backups)
#   --keep DAYS     Keep backups for N days (default: 7)
#   --minio BUCKET  Upload to MinIO bucket (e.g. minio/backups)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

OUTPUT_DIR="./backups"
KEEP_DAYS=7
MINIO_BUCKET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --output)  OUTPUT_DIR="$2"; shift 2 ;;
        --keep)    KEEP_DAYS="$2"; shift 2 ;;
        --minio)   MINIO_BUCKET="$2"; shift 2 ;;
        *) log_err "Unknown option: $1"; exit 1 ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

# Load .env if available
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    set -a; source "${SCRIPT_DIR}/../.env"; set +a
elif [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a; source "${SCRIPT_DIR}/.env"; set +a
fi

# ---- PostgreSQL Backup ----
echo "=== Backing up PostgreSQL ==="
docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" \
    > "${BACKUP_DIR}/postgresql_all.sql" 2>/dev/null \
    && gzip -f "${BACKUP_DIR}/postgresql_all.sql" \
    && log_ok "PostgreSQL backup: ${BACKUP_DIR}/postgresql_all.sql.gz" \
    || log_err "PostgreSQL backup failed"

# ---- Redis Backup ----
echo "=== Backing up Redis ==="
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null
sleep 2
docker cp homelab-redis:/data/dump.rdb "${BACKUP_DIR}/redis_dump.rdb" 2>/dev/null \
    && gzip -f "${BACKUP_DIR}/redis_dump.rdb" \
    && log_ok "Redis backup: ${BACKUP_DIR}/redis_dump.rdb.gz" \
    || log_err "Redis backup failed"

# ---- MariaDB Backup ----
echo "=== Backing up MariaDB ==="
docker exec homelab-mariadb mariadb-dump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases \
    > "${BACKUP_DIR}/mariadb_all.sql" 2>/dev/null \
    && gzip -f "${BACKUP_DIR}/mariadb_all.sql" \
    && log_ok "MariaDB backup: ${BACKUP_DIR}/mariadb_all.sql.gz" \
    || log_err "MariaDB backup failed"

# ---- Create archive ----
echo "=== Creating archive ==="
tar -czf "${OUTPUT_DIR}/db-backup-${TIMESTAMP}.tar.gz" -C "${OUTPUT_DIR}" "${TIMESTAMP}/"
rm -rf "${BACKUP_DIR}"
log_ok "Archive: ${OUTPUT_DIR}/db-backup-${TIMESTAMP}.tar.gz"

# ---- Cleanup old backups ----
echo "=== Cleaning up backups older than ${KEEP_DAYS} days ==="
find "${OUTPUT_DIR}" -name "db-backup-*.tar.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null \
    && log_ok "Old backups cleaned up" \
    || log_warn "No old backups to clean"

# ---- Upload to MinIO (optional) ----
if [ -n "${MINIO_BUCKET}" ]; then
    echo "=== Uploading to MinIO: ${MINIO_BUCKET} ==="
    if command -v mc &>/dev/null; then
        mc cp "${OUTPUT_DIR}/db-backup-${TIMESTAMP}.tar.gz" "${MINIO_BUCKET}/db-backup-${TIMESTAMP}.tar.gz" \
            && log_ok "Uploaded to MinIO" \
            || log_err "MinIO upload failed"
    else
        log_warn "mc client not found — install with: brew install minio/stable/mc"
    fi
fi

SIZE=$(du -sh "${OUTPUT_DIR}/db-backup-${TIMESTAMP}.tar.gz" 2>/dev/null | cut -f1)
log_ok "Backup complete! Size: ${SIZE}"
