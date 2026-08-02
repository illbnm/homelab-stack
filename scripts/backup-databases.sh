#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB to a timestamped tar archive.
# Retains backups for 7 days.
# Usage: ./backup-databases.sh [--postgres|--redis|--mariadb|--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

mkdir -p "$BACKUP_DIR/tmp_${TIMESTAMP}"
TMP_DIR="$BACKUP_DIR/tmp_${TIMESTAMP}"

backup_postgres() {
  log_info "Backing up PostgreSQL..."
  local file="$TMP_DIR/postgres_${TIMESTAMP}.sql.gz"
  docker exec homelab-postgres pg_dumpall \
    -U "${POSTGRES_ROOT_USER:-postgres}" \
    | gzip > "$file"
  log_info "PostgreSQL backup created."
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$TMP_DIR/redis_${TIMESTAMP}.rdb"
  docker exec homelab-redis redis-cli \
    -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
  sleep 3 # Allow background save to finish
  docker cp homelab-redis:/data/dump.rdb "$file"
  log_info "Redis backup created."
}

backup_mariadb() {
  log_info "Backing up MariaDB..."
  local file="$TMP_DIR/mariadb_${TIMESTAMP}.sql.gz"
  docker exec homelab-mariadb mariadb-dump \
    --all-databases \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    | gzip > "$file"
  log_info "MariaDB backup created."
}

# Ensure cleanup of tmp dir on exit
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

case "${1:---all}" in
  --postgres) backup_postgres ;;
  --redis)    backup_redis ;;
  --mariadb)  backup_mariadb ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"; exit 1 ;;
esac

# Create tar.gz archive
ARCHIVE_FILE="$BACKUP_DIR/databases_backup_${TIMESTAMP}.tar.gz"
log_info "Compressing backups into archive: $ARCHIVE_FILE"
tar -czf "$ARCHIVE_FILE" -C "$TMP_DIR" .

log_info "Backup archive size: $(du -sh "$ARCHIVE_FILE" | cut -f1)"

# 7-day retention policy
log_info "Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -name "databases_backup_*.tar.gz" -type f -mtime +7 -delete

log_info "All backups completed successfully."
