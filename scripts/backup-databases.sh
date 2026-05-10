#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Backup Script
# Performs full backup of PostgreSQL databases + Redis persistence trigger.
# Saves compressed .tar.gz with 7-day retention.
#
# Usage:
#   ./scripts/backup-databases.sh                 # Local backup
#   ./scripts/backup-databases.sh --upload-minio    # + upload to MinIO
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log_ok()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

UPLOAD_MINIO=false
[[ "${1:-}" == "--upload-minio" ]] && UPLOAD_MINIO=true

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${ROOT_DIR}/backups"
BACKUP_FILE="${BACKUP_DIR}/databases-${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PGHOST="${DB_HOST:-homelab-postgres}"
PGPORT="${DB_PORT:-5432}"
PGUSER="${POSTGRES_ROOT_USER:-postgres}"
PGPASSWORD="${POSTGRES_ROOT_PASSWORD:-}"
export PGPASSWORD

REDIS_HOST="${REDIS_HOST:-homelab-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASS="${REDIS_PASSWORD:-}"

# ------------------------------------------------------------------
# PostgreSQL backup (pg_dumpall)
# ------------------------------------------------------------------
log_ok "Backing up PostgreSQL (all databases)..."
PG_DUMP="${TMP_DIR}/postgres-all.sql"
if pg_dumpall -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c --if-exists > "$PG_DUMP" 2>/dev/null; then
  PG_SIZE=$(du -h "$PG_DUMP" | cut -f1)
  log_ok "PostgreSQL dump: $PG_SIZE"
else
  log_err "PostgreSQL dump failed"
  exit 1
fi

# ------------------------------------------------------------------
# Redis persistence trigger (BGSAVE)
# ------------------------------------------------------------------
log_ok "Triggering Redis BGSAVE..."
if command -v redis-cli &>/dev/null; then
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASS" --no-auth-warning BGSAVE > /dev/null 2>&1 && \
    log_ok "Redis BGSAVE triggered" || log_warn "Redis BGSAVE failed (non-fatal)"
else
  log_warn "redis-cli not found, skipping Redis backup"
fi

# ------------------------------------------------------------------
# Compress
# ------------------------------------------------------------------
log_ok "Compressing backup..."
tar -czf "$BACKUP_FILE" -C "$TMP_DIR" .
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_ok "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# ------------------------------------------------------------------
# Cleanup old backups
# ------------------------------------------------------------------
log_ok "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "databases-*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
DELETED=$(find "$BACKUP_DIR" -name "databases-*.tar.gz" | wc -l)
log_ok "Retaining $DELETED backups"

# ------------------------------------------------------------------
# Optional: Upload to MinIO
# ------------------------------------------------------------------
if [ "$UPLOAD_MINIO" = true ]; then
  if command -v mc &>/dev/null; then
    BUCKET="${MINIO_BACKUP_BUCKET:-homelab-backups}"
    log_ok "Uploading to MinIO bucket: $BUCKET"
    mc cp "$BACKUP_FILE" "myminio/${BUCKET}/" 2>/dev/null && \
      log_ok "Uploaded to MinIO" || log_err "MinIO upload failed"
  else
    log_err "mc (MinIO client) not found. Install: brew install minio-mc"
  fi
fi

log_ok "Backup complete: $(date)"
echo "$BACKUP_FILE"

# Notify via notify.sh if available
if [ -x "${ROOT_DIR}/scripts/notify.sh" ]; then
  "${ROOT_DIR}/scripts/notify.sh" \
    backup-status \
    "Database Backup Complete" \
    "Backup: ${BACKUP_FILE} (${BACKUP_SIZE}) — $(date)" \
    3 check 2>/dev/null || true
fi