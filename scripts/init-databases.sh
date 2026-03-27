#!/usr/bin/env bash
# =============================================================================
# init-databases.sh — Initialize per-service databases and users in PostgreSQL
# Run this AFTER starting the databases stack to create databases for each service.
# Idempotent: safe to run multiple times without resetting existing data.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[init-db]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[init-db]${NC} $*" >&2; }
log_error() { echo -e "${RED}[init-db]${NC} $*" >&2; }

PGHOST="${PGHOST:-homelab-postgres}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-${POSTGRES_ROOT_PASSWORD}}"

# Load env vars if .env exists
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR/../../.env" ]; then
    set -a; source "$SCRIPT_DIR/../../.env"; set +a
fi

export PGPASSWORD

# Databases and users to create
declare -A DBS=(
    [nextcloud]="NEXTCLOUD_DB_PASSWORD"
    [gitea]="GITEA_DB_PASSWORD"
    [outline]="OUTLINE_DB_PASSWORD"
    [authentik]="AUTHENTIK_DB_PASSWORD"
    [grafana]="GRAFANA_DB_PASSWORD"
    [vaultwarden]="VAULTWARDEN_DB_PASSWORD"
    [bookstack]="BOOKSTACK_DB_PASSWORD"
)

create_db() {
    local dbname="$1"
    local dbuser="$2"
    local dbpass="${3:-}"

    log_info "Creating database '$dbname' with owner '$dbuser'..."

    # Check if database exists
    if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$dbname"; then
        log_warn "Database '$dbname' already exists — skipping creation"
    else
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE DATABASE \"$dbname\";" 2>/dev/null
        log_info "Database '$dbname' created"
    fi

    # Check if user exists
    if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$dbuser'" 2>/dev/null | grep -q 1; then
        log_warn "User '$dbuser' already exists — skipping"
    else
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE USER $dbuser WITH PASSWORD '$dbpass';" 2>/dev/null
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "GRANT ALL PRIVILEGES ON DATABASE \"$dbname\" TO $dbuser;" 2>/dev/null
        log_info "User '$dbuser' created and granted privileges on '$dbname'"
    fi

    # Grant schema privileges
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $dbuser;" -d "$dbname" 2>/dev/null || true
}

wait_for_postgres() {
    local max_wait=30
    local count=0
    log_info "Waiting for PostgreSQL to be ready..."
    until psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "SELECT 1" &>/dev/null; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $max_wait ]; then
            log_error "PostgreSQL did not become ready in ${max_wait}s"
            exit 1
        fi
    done
    log_info "PostgreSQL is ready"
}

show_usage() {
    cat << EOF
Usage: $0 [--wait]

Initialize per-service databases in PostgreSQL.

Options:
  --wait    Wait for PostgreSQL to be ready before initializing

Environment variables:
  PGHOST, PGPORT, PGUSER, PGPASSWORD
  Or load from .env at repo root

Examples:
  $0                  # Run immediately
  $0 --wait           # Wait for PostgreSQL first
EOF
}

WAIT_FLAG=false
[[ "${1:-}" == "--wait" ]] && WAIT_FLAG=true

$WAIT_FLAG && wait_for_postgres

for db in "${!DBS[@]}"; do
    pass_var="${DBS[$db]}"
    pass="${!pass_var:-changeme_${db}_pass}"
    user="${db}"  # username = database name for simplicity
    create_db "$db" "$user" "$pass"
done

# Redis databases allocation (0-5)
log_info "Redis DB allocation:"
log_info "  DB 0 — Authentik"
log_info "  DB 1 — Outline"
log_info "  DB 2 — Gitea"
log_info "  DB 3 — Nextcloud"
log_info "  DB 4 — Grafana sessions"
log_info "  DB 5 — Vaultwarden"

# Configure Redis DB allocation via environment in each service's compose
log_info ""
log_info "PostgreSQL connection strings (for other stacks):"
log_info "  postgresql://nextcloud:NEXTCLOUD_DB_PASSWORD@homelab-postgres:5432/nextcloud"
log_info "  postgresql://gitea:GITEA_DB_PASSWORD@homelab-postgres:5432/gitea"
log_info "  postgresql://outline:OUTLINE_DB_PASSWORD@homelab-postgres:5432/outline"

log_info ""
log_info "Databases initialized successfully!"
