#!/usr/bin/env bash
set -euo pipefail

# HomeLab Database Backup Script
# - pg_dumpall + redis BGSAVE + mariadb dump
# - packs into single tar.gz archive
# - keeps last 7 days
# - optional MinIO upload via mc

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR=$(mktemp -d)
ARCHIVE="$BACKUP_DIR/databases_${TIMESTAMP}.tar.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$BACKUP_DIR"

info(){ echo "[INFO] $*"; }
warn(){ echo "[WARN] $*"; }
err(){ echo "[ERR]  $*" >&2; }

backup_postgres() {
  info "Dumping PostgreSQL..."
  docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" > "$WORK_DIR/postgres.sql"
}

backup_redis() {
  info "Dumping Redis..."
  docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE >/dev/null
  sleep 2
  docker cp homelab-redis:/data/dump.rdb "$WORK_DIR/redis.rdb"
}

backup_mariadb() {
  info "Dumping MariaDB..."
  docker exec homelab-mariadb mariadb-dump --all-databases -u root -p"${MARIADB_ROOT_PASSWORD}" > "$WORK_DIR/mariadb.sql"
}

backup_postgres
backup_redis
backup_mariadb

info "Creating archive: $ARCHIVE"
tar -czf "$ARCHIVE" -C "$WORK_DIR" postgres.sql redis.rdb mariadb.sql

info "Pruning backups older than ${RETENTION_DAYS} days"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'databases_*.tar.gz' -mtime +"$RETENTION_DAYS" -delete

if [[ "${MINIO_UPLOAD_ENABLED:-false}" == "true" ]]; then
  if command -v mc >/dev/null 2>&1; then
    MINIO_BUCKET_PATH="${MINIO_BUCKET_PATH:-backups/databases}"
    info "Uploading archive to MinIO: ${MINIO_BUCKET_PATH}"
    mc cp "$ARCHIVE" "${MINIO_BUCKET_PATH}/"
  else
    warn "MINIO_UPLOAD_ENABLED=true but 'mc' not installed; skipped upload"
  fi
fi

info "Backup complete: $ARCHIVE"
