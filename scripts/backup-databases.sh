#!/bin/bash
# =============================================================================
# backup-databases.sh - Database backup script
# Usage: backup-databases.sh [--target local|s3] [--keep DAYS]
#
# Backs up PostgreSQL, Redis, and MariaDB databases
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/homelab}"
KEEP_DAYS="${KEEP_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)

# Load environment
STACK_DIR="$(dirname "$SCRIPT_DIR")/stacks/databases"
if [ -f "$STACK_DIR/.env" ]; then
    set -a
    source "$STACK_DIR/.env"
    set +a
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            BACKUP_TARGET="$2"
            shift 2
            ;;
        --keep)
            KEEP_DAYS="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${GREEN}=== Database Backup ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"
echo "Keep days: $KEEP_DAYS"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# -----------------------------------------------------------------------------
# PostgreSQL Backup
# -----------------------------------------------------------------------------
backup_postgres() {
    echo -e "${GREEN}Backing up PostgreSQL...${NC}"

    if ! docker ps --format '{{.Names}}' | grep -q "homelab-postgres"; then
        echo -e "${YELLOW}  PostgreSQL container not running, skipping${NC}"
        return 0
    fi

    local backup_file="${BACKUP_DIR}/postgres_${TIMESTAMP}.sql"

    docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" > "$backup_file"

    # Compress
    gzip "$backup_file"

    local size=$(du -h "${backup_file}.gz" | cut -f1)
    echo -e "  ${GREEN}✓ PostgreSQL backup: ${backup_file}.gz ($size)${NC}"
}

# -----------------------------------------------------------------------------
# Redis Backup
# -----------------------------------------------------------------------------
backup_redis() {
    echo -e "${GREEN}Backing up Redis...${NC}"

    if ! docker ps --format '{{.Names}}' | grep -q "homelab-redis"; then
        echo -e "${YELLOW}  Redis container not running, skipping${NC}"
        return 0
    fi

    # Trigger BGSAVE
    docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null

    # Wait for save to complete
    sleep 2

    local backup_file="${BACKUP_DIR}/redis_${TIMESTAMP}.rdb"

    # Copy RDB file
    docker cp homelab-redis:/data/dump.rdb "$backup_file"

    # Compress
    gzip "$backup_file"

    local size=$(du -h "${backup_file}.gz" | cut -f1)
    echo -e "  ${GREEN}✓ Redis backup: ${backup_file}.gz ($size)${NC}"
}

# -----------------------------------------------------------------------------
# MariaDB Backup
# -----------------------------------------------------------------------------
backup_mariadb() {
    echo -e "${GREEN}Backing up MariaDB...${NC}"

    if ! docker ps --format '{{.Names}}' | grep -q "homelab-mariadb"; then
        echo -e "${YELLOW}  MariaDB container not running, skipping${NC}"
        return 0
    fi

    local backup_file="${BACKUP_DIR}/mariadb_${TIMESTAMP}.sql"

    docker exec homelab-mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > "$backup_file" 2>/dev/null

    # Compress
    gzip "$backup_file"

    local size=$(du -h "${backup_file}.gz" | cut -f1)
    echo -e "  ${GREEN}✓ MariaDB backup: ${backup_file}.gz ($size)${NC}"
}

# -----------------------------------------------------------------------------
# Create combined archive
# -----------------------------------------------------------------------------
create_archive() {
    echo -e "${GREEN}Creating combined archive...${NC}"

    local archive="${BACKUP_DIR}/databases_${TIMESTAMP}.tar.gz"

    # Find today's backups
    find "$BACKUP_DIR" -name "*_${TIMESTAMP}*" -type f | tar -czf "$archive" -T -

    local size=$(du -h "$archive" | cut -f1)
    echo -e "  ${GREEN}✓ Archive: $archive ($size)${NC}"

    # Remove individual files (keep only archive)
    find "$BACKUP_DIR" -name "*_${TIMESTAMP}*.gz" ! -name "databases_*" -delete
}

# -----------------------------------------------------------------------------
# Cleanup old backups
# -----------------------------------------------------------------------------
cleanup_old_backups() {
    echo -e "${GREEN}Cleaning up old backups...${NC}"

    local count=$(find "$BACKUP_DIR" -name "databases_*.tar.gz" -mtime +${KEEP_DAYS} -delete -print | wc -l)
    echo -e "  ${GREEN}✓ Removed $count old backup(s)${NC}"
}

# -----------------------------------------------------------------------------
# Optional: Upload to S3/MinIO
# -----------------------------------------------------------------------------
upload_to_s3() {
    if [ "${BACKUP_TARGET:-}" = "s3" ] && [ -n "${S3_BUCKET:-}" ]; then
        echo -e "${GREEN}Uploading to S3...${NC}"

        local archive="${BACKUP_DIR}/databases_${TIMESTAMP}.tar.gz"

        if command -v aws &>/dev/null; then
            aws s3 cp "$archive" "s3://${S3_BUCKET}/backups/databases/"
            echo -e "  ${GREEN}✓ Uploaded to s3://${S3_BUCKET}/backups/databases/${NC}"
        elif command -v mc &>/dev/null; then
            mc cp "$archive" "${S3_ALIAS:-minio}/${S3_BUCKET}/backups/databases/"
            echo -e "  ${GREEN}✓ Uploaded to MinIO${NC}"
        else
            echo -e "${YELLOW}  Warning: No S3 client found (aws-cli or mc)${NC}"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Send notification
# -----------------------------------------------------------------------------
send_notification() {
    local status="$1"
    local message="$2"

    if [ -f "$SCRIPT_DIR/notify.sh" ]; then
        export NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
        bash "$SCRIPT_DIR/notify.sh" backups "Database Backup ${status}" "$message" "${status}" 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local errors=0

    backup_postgres || errors=$((errors + 1))
    backup_redis || errors=$((errors + 1))
    backup_mariadb || errors=$((errors + 1))

    create_archive
    cleanup_old_backups
    upload_to_s3

    echo ""
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}=== Backup Complete ===${NC}"
        send_notification "default" "All databases backed up successfully"
    else
        echo -e "${YELLOW}=== Backup Complete with $errors error(s) ===${NC}"
        send_notification "high" "Database backup completed with $errors error(s)"
    fi
}

main
