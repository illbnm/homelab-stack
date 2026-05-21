#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Initialization Script
# Creates required databases and users idempotently.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
source "$ROOT_DIR/.env" 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Function to create user and database idempotently in PostgreSQL
create_db() {
    local db_name=$1
    local db_pass=$2
    local pg_user="${POSTGRES_ROOT_USER:-postgres}"

    log_info "Ensuring PostgreSQL user and database for: $db_name"
    
    # Check if role exists, if not create
    local user_exists=$(docker exec homelab-postgres psql -U "$pg_user" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db_name'")
    if [ "$user_exists" != "1" ]; then
        docker exec homelab-postgres psql -U "$pg_user" -c "CREATE USER \"$db_name\" WITH ENCRYPTED PASSWORD '$db_pass';"
        log_info "User $db_name created."
    else
        log_warn "User $db_name already exists."
    fi

    # Check if database exists, if not create
    local db_exists=$(docker exec homelab-postgres psql -U "$pg_user" -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'")
    if [ "$db_exists" != "1" ]; then
        docker exec homelab-postgres psql -U "$pg_user" -c "CREATE DATABASE \"$db_name\" OWNER \"$db_name\";"
        docker exec homelab-postgres psql -U "$pg_user" -c "GRANT ALL PRIVILEGES ON DATABASE \"$db_name\" TO \"$db_name\";"
        log_info "Database $db_name created."
    else
        log_warn "Database $db_name already exists."
    fi
}

log_info "Waiting for PostgreSQL to be ready..."
until docker exec homelab-postgres pg_isready -U "${POSTGRES_ROOT_USER:-postgres}" >/dev/null 2>&1; do
    sleep 2
done

log_info "PostgreSQL is ready. Initializing databases..."

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud_secure_pass}"
create_db "gitea"     "${GITEA_DB_PASSWORD:-gitea_secure_pass}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:-outline_secure_pass}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik_secure_pass}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-grafana_secure_pass}"

log_info "Database initialization complete."
