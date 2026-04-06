#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB to timestamped archives.
# Keeps only the last 7 days of backups.
# Usage: ./backup-databases.sh [--postgres|--redis|--mariadb|--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Cleanup old backups (keep only last N days)
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    local count=0
    
    # PostgreSQL
    find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    count=$(find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    [[ $count -gt 0 ]] && log_warn "Removed $count old PostgreSQL backups"
    
    # Redis
    find "$BACKUP_DIR" -name "redis_*.rdb" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    count=$(find "$BACKUP_DIR" -name "redis_*.rdb" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    [[ $count -gt 0 ]] && log_warn "Removed $count old Redis backups"
    
    # MariaDB
    find "$BACKUP_DIR" -name "mariadb_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    count=$(find "$BACKUP_DIR" -name "mariadb_*.sql.gz" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    [[ $count -gt 0 ]] && log_warn "Removed $count old MariaDB backups"
    
    log_info "Cleanup complete"
}

backup_postgres() {
    log_info "Backing up PostgreSQL..."
    local file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-postgres"; then
        log_error "PostgreSQL container not running"
        return 1
    fi
    
    docker exec homelab-postgres pg_dumpall \
        -U "${POSTGRES_ROOT_USER:-postgres}" \
        --clean \
        --if-exists \
        | gzip > "$file"
    
    log_info "PostgreSQL backup: $file ($(du -sh "$file" | cut -f1))"
}

backup_redis() {
    log_info "Backing up Redis..."
    local file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-redis"; then
        log_error "Redis container not running"
        return 1
    fi
    
    # Trigger background save
    docker exec homelab-redis redis-cli \
        -a "${REDIS_PASSWORD}" \
        --no-auth-warning BGSAVE
    
    # Wait for save to complete (max 30 seconds)
    local wait_count=0
    while docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning LASTSAVE | \
          xargs -I {} docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning DEBUG SLEEP 1 2>/dev/null; do
        sleep 1
        wait_count=$((wait_count + 1))
        if [ $wait_count -ge 30 ]; then
            log_warn "Redis BGSAVE taking too long, continuing anyway..."
            break
        fi
    done
    
    # Copy the RDB file
    docker cp homelab-redis:/data/dump.rdb "$file"
    
    log_info "Redis backup: $file ($(du -sh "$file" | cut -f1))"
}

backup_mariadb() {
    log_info "Backing up MariaDB..."
    local file="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-mariadb"; then
        log_error "MariaDB container not running"
        return 1
    fi
    
    docker exec homelab-mariadb mariadb-dump \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        -u root -p"${MARIADB_ROOT_PASSWORD}" \
        | gzip > "$file"
    
    log_info "MariaDB backup: $file ($(du -sh "$file" | cut -f1))"
}

# Optional: Upload to MinIO/S3
upload_to_minio() {
    local file="$1"
    local bucket="${MINIO_BUCKET:-homelab-backups}"
    
    if [[ -z "${MINIO_ENDPOINT:-}" ]]; then
        log_warn "MinIO not configured, skipping upload"
        return
    fi
    
    log_info "Uploading $file to MinIO..."
    
    # Use mc (MinIO Client) or aws CLI if available
    if command -v mc &> /dev/null; then
        mc cp "$file" "myminio/${bucket}/$(basename $file)"
    elif command -v aws &> /dev/null; then
        aws s3 cp "$file" "s3://${bucket}/$(basename $file)"
    else
        log_warn "MinIO client not available, skipping upload"
    fi
}

# Main
case "${1:---all}" in
    --postgres)
        backup_postgres
        cleanup_old_backups
        ;;
    --redis)
        backup_redis
        cleanup_old_backups
        ;;
    --mariadb)
        backup_mariadb
        cleanup_old_backups
        ;;
    --all)
        backup_postgres
        backup_redis
        backup_mariadb
        cleanup_old_backups
        log_info "All backups completed in $BACKUP_DIR"
        ;;
    --upload)
        # Upload latest backups to MinIO
        find "$BACKUP_DIR" -name "postgres_*.sql.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | tail -1 | cut -d' ' -f2- | xargs -I {} upload_to_minio {}
        find "$BACKUP_DIR" -name "mariadb_*.sql.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | tail -1 | cut -d' ' -f2- | xargs -I {} upload_to_minio {}
        ;;
    *)
        echo "Usage: $0 [--postgres|--redis|--mariadb|--all|--upload]"
        echo ""
        echo "Options:"
        echo "  --postgres  Backup only PostgreSQL"
        echo "  --redis     Backup only Redis"
        echo "  --mariadb   Backup only MariaDB"
        echo "  --all       Backup all databases (default)"
        echo "  --upload    Upload latest backups to MinIO"
        exit 1
        ;;
esac

log_info "Backup process complete!"