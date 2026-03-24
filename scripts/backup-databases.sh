#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script
# Backs up PostgreSQL, Redis, and MariaDB databases
# Usage: backup-databases.sh [output_dir]
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="${1:-/opt/homelab/backups/databases}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab-db-${DATE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "${BACKUP_DIR}"

log_info "Starting database backup: ${BACKUP_NAME}"

# =============================================================================
# PostgreSQL Backup
# =============================================================================
backup_postgres() {
    log_info "Backing up PostgreSQL..."
    
    local pg_container="homelab-postgres"
    local pg_backup="${BACKUP_DIR}/${BACKUP_NAME}_postgres.sql"
    
    if docker ps --format '{{.Names}}' | grep -q "^${pg_container}$"; then
        docker exec "${pg_container}" pg_dumpall -U postgres > "${pg_backup}"
        gzip -f "${pg_backup}"
        log_info "PostgreSQL backup complete: ${pg_backup}.gz"
    else
        log_warn "PostgreSQL container not running, skipping"
    fi
}

# =============================================================================
# Redis Backup
# =============================================================================
backup_redis() {
    log_info "Backing up Redis..."
    
    local redis_container="homelab-redis"
    local redis_backup="${BACKUP_DIR}/${BACKUP_NAME}_redis.rdb"
    
    if docker ps --format '{{.Names}}' | grep -q "^${redis_container}$"; then
        # Trigger BGSAVE
        docker exec "${redis_container}" redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE
        
        # Wait for backup to complete
        sleep 2
        
        # Copy dump file
        docker cp "${redis_container}:/data/dump.rdb" "${redis_backup}"
        gzip -f "${redis_backup}"
        log_info "Redis backup complete: ${redis_backup}.gz"
    else
        log_warn "Redis container not running, skipping"
    fi
}

# =============================================================================
# MariaDB Backup
# =============================================================================
backup_mariadb() {
    log_info "Backing up MariaDB..."
    
    local maria_container="homelab-mariadb"
    local maria_backup="${BACKUP_DIR}/${BACKUP_NAME}_mariadb.sql"
    
    if docker ps --format '{{.Names}}' | grep -q "^${maria_container}$"; then
        docker exec "${maria_container}" mariadb-dump -u root -p"${MARIADB_ROOT_PASSWORD:-}" --all-databases > "${maria_backup}"
        gzip -f "${maria_backup}"
        log_info "MariaDB backup complete: ${maria_backup}.gz"
    else
        log_warn "MariaDB container not running, skipping"
    fi
}

# =============================================================================
# Create combined archive
# =============================================================================
create_archive() {
    log_info "Creating combined backup archive..."
    
    local archive="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    
    # Collect all backup files
    local files=()
    for f in "${BACKUP_DIR}/${BACKUP_NAME}"_*.gz; do
        [ -f "$f" ] && files+=("$(basename "$f")")
    done
    
    if [ ${#files[@]} -gt 0 ]; then
        tar -czf "${archive}" -C "${BACKUP_DIR}" "${files[@]}"
        log_info "Archive created: ${archive}"
        
        # Calculate size
        local size
        size=$(du -h "${archive}" | cut -f1)
        log_info "Archive size: ${size}"
    else
        log_error "No backup files found"
        exit 1
    fi
}

# =============================================================================
# Cleanup old backups
# =============================================================================
cleanup_old_backups() {
    log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    find "${BACKUP_DIR}" -name "homelab-db-*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete
    find "${BACKUP_DIR}" -name "homelab-db-*_*.gz" -type f -mtime +${RETENTION_DAYS} -delete
    
    log_info "Cleanup complete"
}

# =============================================================================
# Optional: Upload to MinIO/S3
# =============================================================================
upload_to_s3() {
    if [ -n "${S3_BUCKET:-}" ] && [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        log_info "Uploading to S3..."
        aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "s3://${S3_BUCKET}/backups/databases/"
        log_info "Upload complete"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    backup_postgres
    backup_redis
    backup_mariadb
    create_archive
    cleanup_old_backups
    upload_to_s3
    
    log_info "Backup completed successfully!"
    log_info "Location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
}

main "$@"