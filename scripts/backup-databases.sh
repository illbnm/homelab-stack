#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB to timestamped archives.
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

mkdir -p "$BACKUP_DIR"

# Source .env to get passwords
if [ -f "$ROOT_DIR/.env" ]; then
    source "$ROOT_DIR/.env"
fi

backup_postgres() {
  log_info "Backing up PostgreSQL..."
  local file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql"
  docker exec homelab-postgres pg_dumpall \
    -U "${POSTGRES_ROOT_USER:-postgres}" > "$file"
  tar -czf "${file}.tar.gz" -C "$BACKUP_DIR" "postgres_${TIMESTAMP}.sql"
  rm -f "$file"
  log_info "PostgreSQL backup: ${file}.tar.gz ($(du -sh "${file}.tar.gz" | cut -f1))"
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
  docker exec homelab-redis redis-cli \
    -a "${REDIS_PASSWORD:-}" --no-auth-warning BGSAVE
  sleep 2
  docker cp homelab-redis:/data/dump.rdb "$file"
  tar -czf "${file}.tar.gz" -C "$BACKUP_DIR" "redis_${TIMESTAMP}.rdb"
  rm -f "$file"
  log_info "Redis backup: ${file}.tar.gz"
}

backup_mariadb() {
  log_info "Backing up MariaDB..."
  local file="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql"
  docker exec homelab-mariadb mariadb-dump \
    --all-databases \
    -u root -p"${MARIADB_ROOT_PASSWORD:-}" > "$file"
  tar -czf "${file}.tar.gz" -C "$BACKUP_DIR" "mariadb_${TIMESTAMP}.sql"
  rm -f "$file"
  log_info "MariaDB backup: ${file}.tar.gz ($(du -sh "${file}.tar.gz" | cut -f1))"
}

cleanup_old_backups() {
  log_info "Cleaning up backups older than 7 days..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -exec rm -f {} \;
}

case "${1:---all}" in
  --postgres) backup_postgres; cleanup_old_backups ;;
  --redis)    backup_redis; cleanup_old_backups ;;
  --mariadb)  backup_mariadb; cleanup_old_backups ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    cleanup_old_backups
    log_info "All backups completed in $BACKUP_DIR"
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"; exit 1 ;;
esac
