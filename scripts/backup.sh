#!/bin/bash
# =============================================================================
# backup.sh - Unified backup script for homelab stacks
# Usage: backup.sh --target <stack|all> [options]
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/homelab}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Default options
TARGET=""
DRY_RUN=false
RESTORE_ID=""
LIST_MODE=false
VERIFY_MODE=false

# Usage
usage() {
    cat << USAGE
Usage: backup.sh --target <stack|all> [options]

Options:
    --target <stack|all>   Backup target: all, media, databases, config
    --dry-run              Show what would be backed up without executing
    --restore <backup_id>  Restore from specified backup
    --list                 List all backups
    --verify               Verify backup integrity
    --help                 Show this help

Examples:
    backup.sh --target all
    backup.sh --target databases --dry-run
    backup.sh --list
    backup.sh --restore 20240115_020000
USAGE
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target) TARGET="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --restore) RESTORE_ID="$2"; shift 2 ;;
            --list) LIST_MODE=true; shift ;;
            --verify) VERIFY_MODE=true; shift ;;
            --help|-h) usage; exit 0 ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
        esac
    done
}

# Backup PostgreSQL
backup_postgres() {
    echo -e "${GREEN}Backing up PostgreSQL...${NC}"
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-postgres"; then
        echo -e "${YELLOW}  PostgreSQL not running, skipping${NC}"
        return 0
    fi
    [ "$DRY_RUN" = true ] && { echo "    [DRY RUN] pg_dumpall"; return 0; }
    
    mkdir -p "${BACKUP_DIR}/databases"
    docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" | \
        gzip > "${BACKUP_DIR}/databases/postgres_${TIMESTAMP}.sql.gz"
    echo -e "  ${GREEN}✓ PostgreSQL backed up${NC}"
}

# Backup Redis
backup_redis() {
    echo -e "${GREEN}Backing up Redis...${NC}"
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-redis"; then
        echo -e "${YELLOW}  Redis not running, skipping${NC}"
        return 0
    fi
    [ "$DRY_RUN" = true ] && { echo "    [DRY RUN] BGSAVE"; return 0; }
    
    docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null || true
    sleep 2
    mkdir -p "${BACKUP_DIR}/databases"
    docker cp homelab-redis:/data/dump.rdb "${BACKUP_DIR}/databases/redis_${TIMESTAMP}.rdb"
    gzip "${BACKUP_DIR}/databases/redis_${TIMESTAMP}.rdb"
    echo -e "  ${GREEN}✓ Redis backed up${NC}"
}

# Backup MariaDB
backup_mariadb() {
    echo -e "${GREEN}Backing up MariaDB...${NC}"
    if ! docker ps --format '{{.Names}}' | grep -q "homelab-mariadb"; then
        echo -e "${YELLOW}  MariaDB not running, skipping${NC}"
        return 0
    fi
    [ "$DRY_RUN" = true ] && { echo "    [DRY RUN] mysqldump"; return 0; }
    
    mkdir -p "${BACKUP_DIR}/databases"
    docker exec homelab-mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases 2>/dev/null | \
        gzip > "${BACKUP_DIR}/databases/mariadb_${TIMESTAMP}.sql.gz"
    echo -e "  ${GREEN}✓ MariaDB backed up${NC}"
}

# Backup configs
backup_configs() {
    echo -e "${GREEN}Backing up configurations...${NC}"
    [ "$DRY_RUN" = true ] && { echo "    [DRY RUN] tar config/"; return 0; }
    
    mkdir -p "${BACKUP_DIR}/configs"
    tar -czf "${BACKUP_DIR}/configs/configs_${TIMESTAMP}.tar.gz" \
        -C "$PROJECT_ROOT" config/ .env stacks/*/docker-compose.yml 2>/dev/null || true
    echo -e "  ${GREEN}✓ Configs backed up${NC}"
}

# Create combined archive
create_archive() {
    echo -e "${GREEN}Creating archive...${NC}"
    [ "$DRY_RUN" = true ] && return 0
    
    local archive="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"
    find "$BACKUP_DIR" -name "*_${TIMESTAMP}*" -type f | tar -czf "$archive" -T - 2>/dev/null || true
    find "$BACKUP_DIR" -name "*_${TIMESTAMP}*" ! -name "backup_*" -delete 2>/dev/null || true
    
    local size=$(du -h "$archive" 2>/dev/null | cut -f1 || echo "unknown")
    echo -e "  ${GREEN}✓ Archive: $archive ($size)${NC}"
}

# Cleanup old backups
cleanup_old_backups() {
    local keep_days="${KEEP_DAYS:-7}"
    echo -e "${GREEN}Cleaning up backups older than $keep_days days...${NC}"
    [ "$DRY_RUN" = true ] && return 0
    
    local count=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +${keep_days} -delete -print 2>/dev/null | wc -l)
    echo -e "  ${GREEN}✓ Removed $count old backup(s)${NC}"
}

# List backups
list_backups() {
    echo -e "${GREEN}Available Backups${NC}"
    echo "=================="
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f 2>/dev/null | sort -r | while read -r f; do
        local id=$(basename "$f" | sed 's/backup_\|\.tar\.gz//g')
        local size=$(du -h "$f" | cut -f1)
        echo "  $id ($size)"
    done || echo "  No backups found"
}

# Verify backup
verify_backup() {
    echo -e "${GREEN}Verifying backup integrity...${NC}"
    local latest=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f | sort -r | head -1)
    
    if [ -z "$latest" ]; then
        echo -e "${RED}No backup found${NC}"
        return 1
    fi
    
    echo "Checking: $latest"
    if tar -tzf "$latest" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Archive integrity: OK${NC}"
    else
        echo -e "  ${RED}✗ Archive integrity: FAILED${NC}"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    local backup_id="$1"
    local backup_file="${BACKUP_DIR}/backup_${backup_id}.tar.gz"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Backup not found: $backup_file${NC}"
        list_backups
        return 1
    fi
    
    echo -e "${GREEN}Restoring from: $backup_file${NC}"
    local restore_dir="${BACKUP_DIR}/restore_${TIMESTAMP}"
    mkdir -p "$restore_dir"
    tar -xzf "$backup_file" -C "$restore_dir"
    echo -e "${GREEN}Extracted to: $restore_dir${NC}"
    echo "Next: Restore databases from extracted files"
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -f "$SCRIPT_DIR/notify.sh" ]; then
        export NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
        bash "$SCRIPT_DIR/notify.sh" backups "Backup ${status}" "$message" "${status}" 2>/dev/null || true
    fi
}

# Main
main() {
    parse_args "$@"
    
    if [ "$LIST_MODE" = true ]; then
        list_backups
        exit 0
    fi
    
    if [ "$VERIFY_MODE" = true ]; then
        verify_backup
        exit $?
    fi
    
    if [ -n "$RESTORE_ID" ]; then
        restore_backup "$RESTORE_ID"
        exit $?
    fi
    
    if [ -z "$TARGET" ]; then
        usage
        exit 1
    fi
    
    echo -e "${GREEN}=== Backup Started: $TIMESTAMP ===${NC}"
    
    case "$TARGET" in
        all|databases)
            backup_postgres
            backup_redis
            backup_mariadb
            ;&  # Fall through
        all|config)
            backup_configs
            ;&  # Fall through
        all)
            ;;
        media)
            echo -e "${YELLOW}Media backup requires Duplicati Web UI${NC}"
            ;;
        *)
            echo -e "${RED}Unknown target: $TARGET${NC}"
            usage
            exit 1
            ;;
    esac
    
    create_archive
    cleanup_old_backups
    
    echo ""
    echo -e "${GREEN}=== Backup Complete ===${NC}"
    send_notification "default" "Backup completed successfully"
}

main "$@"
