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

RED='[0;31m'; GREEN='[0;32m'; YELLOW='[1;33m'; RESET='[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

mkdir -p "$BACKUP_DIR"

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
    log_info "All backups completed in $BACKUP_DIR"
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"; exit 1 ;;
#!/bin/bash

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%F_%T")
BACKUP_FILE="$BACKUP_DIR/databases_backup_$TIMESTAMP.tar.gz"

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
PGPASSWORD=$POSTGRES_ROOT_PASSWORD pg_dumpall -U postgres > $BACKUP_DIR/postgres_backup.sql

# Backup Redis
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_backup.rdb

# Create tar.gz
tar -czf $BACKUP_FILE -C $BACKUP_DIR postgres_backup.sql redis_backup.rdb

# Remove old backups
find $BACKUP_DIR -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Backup completed: $BACKUP_FILE"

exit 0
esac
