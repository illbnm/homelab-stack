#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Initialize Shared Databases
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
ENV_FILE="$ROOT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "[ERROR] .env file not found at $ENV_FILE"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Wait for Postgres to be ready
log_info "Waiting for PostgreSQL to be ready..."
until docker exec homelab-postgres pg_isready -U "${POSTGRES_ROOT_USER:-postgres}" >/dev/null 2>&1; do
    sleep 2
done

create_db() {
    local db_name=$1
    local db_pass=$2

    if [ -z "$db_pass" ]; then
        log_warn "Password for $db_name is empty. Skipping."
        return
    fi

    log_info "Creating user and database for $db_name..."
    
    # Create role if not exists
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -tc "SELECT 1 FROM pg_roles WHERE rolname = '$db_name'" | grep -q 1 || \
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -c "CREATE ROLE $db_name LOGIN PASSWORD '$db_pass';"
    
    # Create database if not exists
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -tc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1 || \
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -c "CREATE DATABASE $db_name OWNER $db_name;"
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db "gitea"     "${GITEA_DB_PASSWORD:-}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:-}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-}"

log_info "Database initialization completed successfully."
