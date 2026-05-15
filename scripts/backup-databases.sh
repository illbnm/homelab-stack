#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB to timestamped archives.
# Includes automatic retention (default 7 days).
# Usage: ./backup-databases.sh [--postgres|--redis|--mariadb|--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-7}"

RED=''; GREEN=''; YELLOW=''; RESET=''
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

mkdir -p "$BACKUP_DIR"

cleanup_old_backups() {
  log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
  local count
  count=$(find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete
    log_info "Removed $count old backup(s)"
  else
    log_info "No old backups to clean up"
  fi
}

backup_postgres() {
  log_info "Backing up PostgreSQL..."
  local file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
  docker exec homelab-postgres pg_dumpall     -U "${POSTGRES_ROOT_USER:-postgres}"     | gzip > "$file"
  log_info "PostgreSQL backup: $file ($(du -sh "$file" | cut -f1))"
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
  docker exec homelab-redis redis-cli     -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
  sleep 2
  docker cp homelab-redis:/data/dump.rdb "$file"
  log_info "Redis backup: $file"
}

backup_mariadb() {
  log_info "Backing up MariaDB..."
  local file="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"
  docker exec homelab-mariadb mariadb-dump     --all-databases     -u root -p"${MARIADB_ROOT_PASSWORD}"     | gzip > "$file"
  log_info "MariaDB backup: $file ($(du -sh "$file" | cut -f1))"
}

case "${1:---all}" in
  --postgres) backup_postgres ;;
  --redis)    backup_redis ;;
  --mariadb)  backup_mariadb ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    cleanup_old_backups
    log_info "All backups completed in $BACKUP_DIR"
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"; exit 1 ;;
esac
