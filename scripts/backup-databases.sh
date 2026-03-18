#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script — 带压缩和保留策略
# Backs up PostgreSQL, Redis, and MariaDB to timestamped archives.
# Usage: ./backup-databases.sh [--postgres|--redis|--mariadb|--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups/databases}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup-db]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup-db]${NC} $*"; }
log_error() { echo -e "${RED}[backup-db]${NC} $*" >&2; }

mkdir -p "$BACKUP_PATH"

backup_postgres() {
  log_info "Backing up PostgreSQL..."
  local file="$BACKUP_PATH/postgres_${TIMESTAMP}.sql.gz"
  docker exec homelab-postgres pg_dumpall \
    -U "${POSTGRES_ROOT_USER:-postgres}" \
    | gzip > "$file"
  log_info "PostgreSQL backup: $file ($(du -sh "$file" | cut -f1))"
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$BACKUP_PATH/redis_${TIMESTAMP}.rdb"
  docker exec homelab-redis redis-cli \
    -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
  sleep 3
  docker cp homelab-redis:/data/dump.rdb "$file"
  gzip "$file"
  log_info "Redis backup: ${file}.gz ($(du -sh "${file}.gz" | cut -f1))"
}

backup_mariadb() {
  log_info "Backing up MariaDB..."
  local file="$BACKUP_PATH/mariadb_${TIMESTAMP}.sql.gz"
  docker exec homelab-mariadb mariadb-dump \
    --all-databases \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    | gzip > "$file"
  log_info "MariaDB backup: $file ($(du -sh "$file" | cut -f1))"
}

cleanup_old() {
  log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
  log_info "Cleanup complete"
}

# Create final archive
create_archive() {
  local archive="$BACKUP_DIR/homelab-db-${TIMESTAMP}.tar.gz"
  tar -czf "$archive" -C "$BACKUP_DIR" "$TIMESTAMP"
  rm -rf "$BACKUP_PATH"
  log_info "Archive: $archive ($(du -sh "$archive" | cut -f1))"
}

case "${1:---all}" in
  --postgres)
    backup_postgres
    ;;
  --redis)
    backup_redis
    ;;
  --mariadb)
    backup_mariadb
    ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    create_archive
    cleanup_old
    log_info "All database backups completed"
    ;;
  *)
    echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"
    exit 1
    ;;
esac
