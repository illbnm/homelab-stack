#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Backup Script
# Dumps all PostgreSQL + Redis + MariaDB to compressed archives.
# Usage: ./backup-databases.sh [--upload]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${DB_BACKUP_RETENTION_DAYS:-7}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

UPLOAD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload) UPLOAD=true; shift ;;
    *) shift ;;
  esac
done

mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# ── PostgreSQL ───────────────────────────────────────────────────────────────
if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
  log_info "Backing up PostgreSQL..."
  docker exec homelab-postgres pg_dumpall -U postgres 2>/dev/null | \
    gzip > "$BACKUP_DIR/$TIMESTAMP/postgres_all.sql.gz"
  log_info "  Size: $(du -sh "$BACKUP_DIR/$TIMESTAMP/postgres_all.sql.gz" | cut -f1)"
fi

# ── Redis ────────────────────────────────────────────────────────────────────
if docker ps --format '{{.Names}}' | grep -q 'homelab-redis'; then
  log_info "Backing up Redis..."
  redis_pass=$(docker exec homelab-redis redis-cli CONFIG GET requirepass 2>/dev/null | tail -1 || echo "")
  if [ -n "$redis_pass" ]; then
    docker exec homelab-redis redis-cli -a "$redis_pass" --rdb /data/dump.rdb SAVE 2>/dev/null || true
  fi
  docker cp homelab-redis:/data/dump.rdb "$BACKUP_DIR/$TIMESTAMP/redis_dump.rdb" 2>/dev/null || log_warn "Redis backup skipped"
  log_info "  Done"
fi

# ── MariaDB ──────────────────────────────────────────────────────────────────
if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
  log_info "Backing up MariaDB..."
  docker exec homelab-mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases 2>/dev/null | \
    gzip > "$BACKUP_DIR/$TIMESTAMP/mariadb_all.sql.gz"
  log_info "  Size: $(du -sh "$BACKUP_DIR/$TIMESTAMP/mariadb_all.sql.gz" | cut -f1)"
fi

# ── Upload to MinIO ──────────────────────────────────────────────────────────
if $UPLOAD && command -v mc &>/dev/null; then
  log_info "Uploading to MinIO..."
  mc cp -r "$BACKUP_DIR/$TIMESTAMP" "minio/database-backups/$TIMESTAMP/" 2>/dev/null || log_warn "Upload failed"
fi

# ── Cleanup ──────────────────────────────────────────────────────────────────
log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

log_info "Backup complete: $BACKUP_DIR/$TIMESTAMP"
