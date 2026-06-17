#!/usr/bin/env bash
# =============================================================================
# HomeLab Professional Backup Manager (Restic Based)
# =============================================================================
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

# Load environment variables
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Restic Configuration (defaults to local if not provided in .env)
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BASE_DIR/backups/restic}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-default_password_change_me}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_KEEP_LAST="${BACKUP_KEEP_LAST:-10}"

# Colors for logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup-mgr]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup-mgr]${NC} $*"; }
log_error() { echo -e "${RED}[backup-mgr]${NC} $*" >&2; }

# Ensure Restic is installed
if ! command -v restic &> /dev/null; then
    log_error "Restic is not installed. Please install it: 'sudo apt install restic'"
    exit 1
fi

export RESTIC_REPOSITORY
export RESTIC_PASSWORD

# --- Core Functions ---

init_repository() {
    if [ ! -d "$RESTIC_REPOSITORY" ]; then
        log_info "Initializing Restic repository at $RESTIC_REPOSITORY..."
        restic init
    fi
}

backup_databases() {
    log_info "Creating database dumps before backup..."
    local tmp_db_dir="/tmp/homelab_db_dumps"
    mkdir -p "$tmp_db_dir"
    
    # Use existing database backup logic but redirect to tmp dir
    # (We can wrap the existing script or call the logic directly)
    # For now, we simulate the db dump logic for the Restic source
    
    # PostgreSQL
    if docker ps --format '{{.Names}}' | grep -q 'postgres\|postgresql'; then
        local pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
        local pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
        docker exec "$pg_container" sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" > "$tmp_db_dir/postgresql_all.sql" 2>/dev/null || log_warn "Postgres dump failed"
    fi
    
    # MySQL/MariaDB
    if docker ps --format '{{.Names}}' | grep -q 'mariadb\|mysql'; then
        local mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
        local mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
        docker exec "$mysql_container" sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" > "$tmp_db_dir/mysql_all.sql" 2>/dev/null || log_warn "MySQL dump failed"
    fi
    
    echo "$tmp_db_dir"
}

run_backup() {
    local db_dir=$1
    log_info "Starting Restic backup..."
    
    # 1. Backing up the project structure and DB dumps
    # We backup the root folder, which includes config/, stacks/, and the temp db dumps
    restic backup "$BASE_DIR" "$db_dir" --exclude-file=<(echo "backups/")
    
    log_info "Backup completed successfully."
}

cleanup_snapshots() {
    log_info "Cleaning up old snapshots (Keep last $BACKUP_KEEP_LAST, daily for $BACKUP_RETENTION_DAYS days)..."
    restic forget --keep-last "$BACKUP_KEEP_LAST" --keep-daily "$BACKUP_RETENTION_DAYS" --prune
}

verify_backup() {
    log_info "Verifying backup integrity..."
    restic check
}

# --- Main Execution ---

main() {
    init_repository
    
    local db_path
    db_path=$(backup_databases)
    
    run_backup "$db_path"
    
    cleanup_snapshots
    verify_backup
    
    # Cleanup temp DB dumps
    rm -rf "$db_path"
    
    log_info "Backup & DR cycle finished."
}

main "$@"
