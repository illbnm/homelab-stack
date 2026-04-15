#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB to timestamped archives.
# Usage: ./backup-databases.sh [--postgres|--redis|--mariadb|--all] [--minio]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED=''; GREEN=''; YELLOW=''; RESET=''
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Parse arguments
UPLOAD_MINIO=false
TARGET="--all"

for arg in "$@"; do
  case "$arg" in
    --minio) UPLOAD_MINIO=true ;;
    --postgres|--redis|--mariadb|--all) TARGET="$arg" ;;
    *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all] [--minio]"; exit 1 ;;
  esac
done

mkdir -p "$BACKUP_DIR"

upload_to_minio() {
  local file="$1"
  if [ "$UPLOAD_MINIO" != "true" ]; then return 0; fi
  
  local endpoint="${MINIO_ENDPOINT:-http://minio:9000}"
  local access_key="${MINIO_ACCESS_KEY:-}"
  local secret_key="${MINIO_SECRET_KEY:-}"
  local bucket="${MINIO_BUCKET:-homelab-backups}"
  local object_name="databases/$(basename "$file")"
  
  if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
    log_warn "MinIO credentials not set, skipping upload"
    return 0
  fi
  
  log_info "Uploading to MinIO: $object_name"
  
  # Use mc (MinIO Client) if available, otherwise use curl with S3 API
  if command -v mc &>/dev/null; then
    mc alias set homelab "$endpoint" "$access_key" "$secret_key" --api S3v4 2>/dev/null
    mc cp "$file" "homelab/$bucket/$object_name"
  else
    # Fallback: curl with S3 presigned-style upload
    local date_val=$(date -R)
    local resource="/$bucket/$object_name"
    local content_type="application/octet-stream"
    local string_to_sign="PUT\n\n$content_type\n$date_val\n$resource"
    local signature=$(echo -en "$string_to_sign" | openssl sha1 -hmac "$secret_key" -binary | base64)
    
    curl -s -X PUT \
      -H "Date: $date_val" \
      -H "Content-Type: $content_type" \
      -H "Authorization: AWS $access_key:$signature" \
      --data-binary "@$file" \
      "$endpoint$resource"
  fi
  
  log_info "MinIO upload complete: $bucket/$object_name"
}

backup_postgres() {
  log_info "Backing up PostgreSQL..."
  local file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
  docker exec homelab-postgres pg_dumpall \
    -U "${POSTGRES_ROOT_USER:-postgres}" \
    | gzip > "$file"
  log_info "PostgreSQL backup: $file ($(du -sh "$file" | cut -f1))"
  upload_to_minio "$file"
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
  docker exec homelab-redis redis-cli \
    -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
  sleep 2
  docker cp homelab-redis:/data/dump.rdb "$file"
  log_info "Redis backup: $file ($(du -sh "$file" | cut -f1))"
  upload_to_minio "$file"
}

backup_mariadb() {
  log_info "Backing up MariaDB..."
  local file="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"
  docker exec homelab-mariadb mariadb-dump \
    --all-databases \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    | gzip > "$file"
  log_info "MariaDB backup: $file ($(du -sh "$file" | cut -f1))"
  upload_to_minio "$file"
}

case "$TARGET" in
  --postgres) backup_postgres ;;
  --redis)    backup_redis ;;
  --mariadb)  backup_mariadb ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    log_info "All backups completed in $BACKUP_DIR"
    ;;
esac

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -type f -mtime +7 -delete 2>/dev/null || true
log_info "Cleaned up backups older than 7 days"
