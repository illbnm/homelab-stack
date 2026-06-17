#!/usr/bin/env bash
# =============================================================================
# HomeLab Professional Restore Manager (Restic Based)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BASE_DIR/backups/restic}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-default_password}"

export RESTIC_REPOSITORY
export RESTIC_PASSWORD

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[restore-mgr]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[restore-mgr]${NC} $*"; }
log_error() { echo -e "${RED}[restore-mgr]${NC} $*" >&2; }

# --- Core Functions ---

list_snapshots() {
    log_info "Available snapshots:"
    restic snapshots
}

restore_latest() {
    log_info "Restoring the latest snapshot to $BASE_DIR..."
    
    # Create base directories
    mkdir -p "$BASE_DIR/config" "$BASE_DIR/stacks" "$BASE_DIR/scripts"
    
    # Restore files
    restic restore latest --target "$BASE_DIR"
    
    log_info "Files restored. Now starting Docker stacks..."
}

deploy_stacks() {
    log_info "Deploying Docker stacks..."
    
    # Order of deployment: Base -> DB -> Network -> SSO -> Others
    local order=("base" "databases" "network" "sso" "monitoring" "storage" "ai" "media" "productivity" "home-automation" "notifications" "dashboard")
    
    for stack in "${order[@]}"; do
        if [ -f "$BASE_DIR/stacks/$stack/docker-compose.yml" ]; then
            log_info "  Starting stack: $stack..."
            cd "$BASE_DIR/stacks/$stack" && docker compose up -d
        fi
    done
}

import_databases() {
    log_info "Importing database dumps..."
    local db_dir="/tmp/homelab_db_dumps" # Restic restores them here or we find them in the restored path
    
    # Search for restored dumps (they were backed up in /tmp/homelab_db_dumps)
    # In a real restore, we find them in the restored file tree
    
    # Example for PostgreSQL
    if [ -f "$BASE_DIR/tmp/homelab_db_dumps/postgresql_all.sql" ]; then
        log_info "  Restoring PostgreSQL..."
        local pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
        local pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
        docker exec -i "$pg_container" sh -c "PGPASSWORD='***' psql -U postgres" < "$BASE_DIR/tmp/homelab_db_dumps/postgresql_all.sql"
    fi
    
    # Example for MySQL
    if [ -f "$BASE_DIR/tmp/homelab_db_dumps/mysql_all.sql" ]; then
        log_info "  Restoring MySQL..."
        local mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
        local mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
        docker exec -i "$mysql_container" sh -c "mysql -u root -p'$mysql_pass'" < "$BASE_DIR/tmp/homelab_db_dumps/mysql_all.sql"
    fi
}

# --- Main Execution ---

if [ $# -eq 0 ]; then
    echo "Usage: $0 {list|restore}"
    exit 1
fi

case "$1" in
    list)
        list_snapshots
        ;;
    restore)
        restore_latest
        deploy_stacks
        import_databases
        log_info "Full system recovery completed!"
        ;;
    *)
        echo "Invalid option: $1"
        exit 1
        ;;
esac
