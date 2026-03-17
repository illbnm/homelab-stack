#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Backup Script
# =============================================================================
# Backs up all databases (PostgreSQL, MariaDB, Redis) into a timestamped
# compressed archive. Retains backups for the configured number of days.
#
# Usage:
#   ./stacks/databases/scripts/backup-databases.sh
#
# Environment variables (set in .env or export before running):
#   BACKUP_DIR              — Target directory for backups (default: /opt/homelab/backups/databases)
#   BACKUP_RETENTION_DAYS   — Days to retain old backups (default: 7)
#   POSTGRES_ROOT_PASSWORD  — PostgreSQL root password
#   MARIADB_ROOT_PASSWORD   — MariaDB root password
#   REDIS_PASSWORD          — Redis auth password
#
# Optional MinIO upload:
#   MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_BUCKET
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups/databases}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
WORK_DIR="${BACKUP_DIR}/tmp_${TIMESTAMP}"
ARCHIVE_NAME="databases_backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

# Container names
PG_CONTAINER="homelab-postgres"
MARIADB_CONTAINER="homelab-mariadb"
REDIS_CONTAINER="homelab-redis"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[BACKUP][INFO]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[BACKUP][WARN]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "${RED}[BACKUP][ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() {
  if [ -d "${WORK_DIR}" ]; then
    rm -rf "${WORK_DIR}"
    log_info "Cleaned up temporary directory."
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Pre-checks
# ---------------------------------------------------------------------------
check_container_running() {
  local container_name="$1"
  if ! docker inspect --format='{{.State.Running}}' "${container_name}" 2>/dev/null | grep -q true; then
    log_warn "Container '${container_name}' is not running. Skipping its backup."
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_info "========================================"
log_info "Starting database backup"
log_info "Backup directory: ${BACKUP_DIR}"
log_info "Timestamp: ${TIMESTAMP}"
log_info "========================================"

# Create directories
mkdir -p "${BACKUP_DIR}" "${WORK_DIR}"

BACKUP_SUCCESS=true

# ---------------------------------------------------------------------------
# 1. PostgreSQL — pg_dumpall
# ---------------------------------------------------------------------------
if check_container_running "${PG_CONTAINER}"; then
  log_info "[PostgreSQL] Starting pg_dumpall..."
  if docker exec -e PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" "${PG_CONTAINER}" \
    pg_dumpall -U postgres --clean --if-exists \
    > "${WORK_DIR}/postgresql_all.sql" 2>/dev/null; then
    PG_SIZE=$(du -sh "${WORK_DIR}/postgresql_all.sql" | cut -f1)
    log_info "[PostgreSQL] Backup complete (${PG_SIZE})"
  else
    log_error "[PostgreSQL] pg_dumpall failed!"
    BACKUP_SUCCESS=false
  fi
else
  log_warn "[PostgreSQL] Skipped — container not running."
fi

# ---------------------------------------------------------------------------
# 2. MariaDB — mysqldump --all-databases
# ---------------------------------------------------------------------------
if check_container_running "${MARIADB_CONTAINER}"; then
  log_info "[MariaDB] Starting mysqldump..."
  if docker exec "${MARIADB_CONTAINER}" \
    mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --all-databases --single-transaction --routines --triggers --events \
    > "${WORK_DIR}/mariadb_all.sql" 2>/dev/null; then
    MARIA_SIZE=$(du -sh "${WORK_DIR}/mariadb_all.sql" | cut -f1)
    log_info "[MariaDB] Backup complete (${MARIA_SIZE})"
  else
    log_error "[MariaDB] mysqldump failed!"
    BACKUP_SUCCESS=false
  fi
else
  log_warn "[MariaDB] Skipped — container not running."
fi

# ---------------------------------------------------------------------------
# 3. Redis — BGSAVE + copy dump.rdb
# ---------------------------------------------------------------------------
if check_container_running "${REDIS_CONTAINER}"; then
  log_info "[Redis] Triggering BGSAVE..."

  # Trigger background save
  docker exec "${REDIS_CONTAINER}" redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null || true

  # Wait for BGSAVE to complete (max 60 seconds)
  WAITED=0
  while [ "${WAITED}" -lt 60 ]; do
    BGSAVE_STATUS=$(docker exec "${REDIS_CONTAINER}" \
      redis-cli -a "${REDIS_PASSWORD}" LASTSAVE 2>/dev/null || echo "0")
    sleep 2
    NEW_STATUS=$(docker exec "${REDIS_CONTAINER}" \
      redis-cli -a "${REDIS_PASSWORD}" LASTSAVE 2>/dev/null || echo "0")
    if [ "${BGSAVE_STATUS}" != "${NEW_STATUS}" ] || [ "${WAITED}" -gt 0 ]; then
      break
    fi
    WAITED=$((WAITED + 2))
  done

  # Copy the dump file
  if docker cp "${REDIS_CONTAINER}:/data/dump.rdb" "${WORK_DIR}/redis_dump.rdb" 2>/dev/null; then
    REDIS_SIZE=$(du -sh "${WORK_DIR}/redis_dump.rdb" | cut -f1)
    log_info "[Redis] Backup complete (${REDIS_SIZE})"
  else
    log_warn "[Redis] Could not copy dump.rdb (may not exist yet if no data)."
  fi

  # Also copy AOF if it exists
  if docker cp "${REDIS_CONTAINER}:/data/appendonly.aof" "${WORK_DIR}/redis_appendonly.aof" 2>/dev/null; then
    log_info "[Redis] AOF file copied."
  fi
else
  log_warn "[Redis] Skipped — container not running."
fi

# ---------------------------------------------------------------------------
# 4. Compress into .tar.gz
# ---------------------------------------------------------------------------
log_info "Compressing backup to ${ARCHIVE_PATH}..."
if tar -czf "${ARCHIVE_PATH}" -C "${WORK_DIR}" .; then
  ARCHIVE_SIZE=$(du -sh "${ARCHIVE_PATH}" | cut -f1)
  log_info "Archive created: ${ARCHIVE_PATH} (${ARCHIVE_SIZE})"
else
  log_error "Failed to create archive!"
  BACKUP_SUCCESS=false
fi

# ---------------------------------------------------------------------------
# 5. Rotate old backups (retain last N days)
# ---------------------------------------------------------------------------
log_info "Cleaning up backups older than ${BACKUP_RETENTION_DAYS} days..."
DELETED_COUNT=$(find "${BACKUP_DIR}" -name "databases_backup_*.tar.gz" \
  -mtime "+${BACKUP_RETENTION_DAYS}" -type f -print -delete 2>/dev/null | wc -l)
log_info "Removed ${DELETED_COUNT} old backup(s)."

# ---------------------------------------------------------------------------
# 6. Optional: Upload to MinIO
# ---------------------------------------------------------------------------
if [ -n "${MINIO_ENDPOINT:-}" ] && [ -n "${MINIO_ACCESS_KEY:-}" ] && \
   [ -n "${MINIO_SECRET_KEY:-}" ] && [ -n "${MINIO_BUCKET:-}" ]; then
  log_info "Uploading backup to MinIO (${MINIO_ENDPOINT})..."

  if command -v mc &>/dev/null; then
    # Configure MinIO client
    mc alias set homelab-backup "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --api S3v4 2>/dev/null

    # Upload
    if mc cp "${ARCHIVE_PATH}" "homelab-backup/${MINIO_BUCKET}/databases/${ARCHIVE_NAME}" 2>/dev/null; then
      log_info "Uploaded to MinIO: ${MINIO_BUCKET}/databases/${ARCHIVE_NAME}"
    else
      log_error "MinIO upload failed!"
    fi
  else
    log_warn "MinIO client (mc) not found. Install it for off-site backup uploads."
    log_warn "  See: https://min.io/docs/minio/linux/reference/minio-mc.html"
  fi
else
  log_info "MinIO not configured. Skipping off-site upload."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log_info "========================================"
if [ "${BACKUP_SUCCESS}" = true ]; then
  log_info "Backup completed successfully!"
else
  log_error "Backup completed with errors. Check logs above."
fi
log_info "Archive: ${ARCHIVE_PATH}"
log_info "Retention: ${BACKUP_RETENTION_DAYS} days"

# List current backups
log_info "Current backups:"
ls -lh "${BACKUP_DIR}"/databases_backup_*.tar.gz 2>/dev/null || log_info "(none)"
log_info "========================================"

# Exit with error if any backup failed
if [ "${BACKUP_SUCCESS}" != true ]; then
  exit 1
fi
