#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL (pg_dumpall) + Redis (BGSAVE) + MariaDB (mysqldump)
# Compresses to .tar.gz, retains last N days, optional MinIO upload
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/databases}"
RETAIN_DAYS="${RETAIN_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab-db-backup-${TIMESTAMP}"
WORK_DIR="${BACKUP_DIR}/${BACKUP_NAME}"

# MinIO upload (optional)
MINIO_ENABLED="${MINIO_ENABLED:-false}"
MINIO_ALIAS="${MINIO_ALIAS:-homelab}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"
MINIO_PATH="${MINIO_PATH:-databases}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[backup]${NC} $*"; }
warn() { echo -e "${YELLOW}[backup]${NC} $*"; }
err() { echo -e "${RED}[backup]${NC} $*" >&2; }

# ── Setup ─────────────────────────────────────
mkdir -p "$WORK_DIR"
log "Starting backup: $BACKUP_NAME"

# ── PostgreSQL Backup ─────────────────────────
log "Backing up PostgreSQL..."
if docker exec homelab-postgres pg_dumpall \
  -U "${POSTGRES_ROOT_USER:-postgres}" \
  --clean --if-exists \
  > "${WORK_DIR}/postgres-all.sql" 2>/dev/null; then
  log "  PostgreSQL: $(wc -c < "${WORK_DIR}/postgres-all.sql" | xargs) bytes"
else
  warn "  PostgreSQL backup failed (container may not be running)"
fi

# ── Redis Backup ──────────────────────────────
log "Backing up Redis..."
if docker exec homelab-redis redis-cli \
  -a "${REDIS_PASSWORD:-}" \
  BGSAVE >/dev/null 2>&1; then
  # Wait for BGSAVE to complete
  sleep 2
  docker cp homelab-redis:/data/dump.rdb "${WORK_DIR}/redis-dump.rdb" 2>/dev/null || true
  if [[ -f "${WORK_DIR}/redis-dump.rdb" ]]; then
    log "  Redis: $(wc -c < "${WORK_DIR}/redis-dump.rdb" | xargs) bytes"
  else
    warn "  Redis dump.rdb copy failed"
  fi
  # Also copy AOF if available
  docker cp homelab-redis:/data/appendonly.aof "${WORK_DIR}/redis-appendonly.aof" 2>/dev/null || true
else
  warn "  Redis backup failed (container may not be running)"
fi

# ── MariaDB Backup ────────────────────────────
log "Backing up MariaDB..."
if docker exec homelab-mariadb mysqldump \
  -u root \
  -p"${MARIADB_ROOT_PASSWORD:-}" \
  --all-databases \
  --single-transaction \
  --routines \
  --triggers \
  > "${WORK_DIR}/mariadb-all.sql" 2>/dev/null; then
  log "  MariaDB: $(wc -c < "${WORK_DIR}/mariadb-all.sql" | xargs) bytes"
else
  warn "  MariaDB backup failed (container may not be running)"
fi

# ── Compress ──────────────────────────────────
log "Compressing..."
ARCHIVE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
tar -czf "$ARCHIVE" -C "$BACKUP_DIR" "$BACKUP_NAME"
rm -rf "$WORK_DIR"
log "Archive: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# ── Upload to MinIO (optional) ────────────────
if [[ "$MINIO_ENABLED" == "true" ]]; then
  log "Uploading to MinIO..."
  if command -v mc &>/dev/null; then
    mc cp "$ARCHIVE" "${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PATH}/${BACKUP_NAME}.tar.gz"
    log "  Uploaded to ${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PATH}/"
  else
    warn "  mc (MinIO client) not found, skipping upload"
  fi
fi

# ── Cleanup old backups ───────────────────────
log "Cleaning up backups older than ${RETAIN_DAYS} days..."
DELETED=$(find "$BACKUP_DIR" -name "homelab-db-backup-*.tar.gz" -mtime +"$RETAIN_DAYS" -delete -print | wc -l | xargs)
log "  Removed $DELETED old backup(s)"

# ── Summary ───────────────────────────────────
log "Backup complete: $ARCHIVE"
log "Retention: ${RETAIN_DAYS} days"
ls -lh "$BACKUP_DIR"/homelab-db-backup-*.tar.gz 2>/dev/null | tail -5
