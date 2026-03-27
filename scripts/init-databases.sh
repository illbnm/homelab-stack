#!/bin/bash
# =============================================================================
# Database Initialization Script — HomeLab Stack
# Idempotent: safe to run multiple times, won't reset existing data
# =============================================================================
# Creates per-service databases and users in PostgreSQL and MariaDB.
# Run manually or automatically via docker-entrypoint-initdb.d mount.
#
# Usage:
#   ./scripts/init-databases.sh          # Run all
#   ./scripts/init-databases.sh --postgres  # PostgreSQL only
#   ./scripts/init-databases.sh --mariadb  # MariaDB only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Load environment
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a; source "$ROOT_DIR/.env"; set +a
else
    log_error ".env not found at $ROOT_DIR/.env"
    exit 1
fi

# PostgreSQL connection params
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${POSTGRES_ROOT_USER:-postgres}"
export PGPASSWORD="${POSTGRES_ROOT_PASSWORD}"

# MariaDB connection params
MDB_HOST="${MDB_HOST:-localhost}"
MDB_PORT="${MDB_PORT:-3306}"
MDB_ROOT_USER="${MDB_ROOT_USER:-root}"

# -----------------------------------------------------------------------------
# PostgreSQL: Create database + user (idempotent)
# -----------------------------------------------------------------------------
create_pg_db() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="${3:-changeme}"

    log_info "PostgreSQL: Ensuring database '$db_name' and user '$db_user'..."

    # Check if user exists
    local user_exists
    user_exists=$(docker exec homelab-postgres psql \
        -U "$PG_USER" -d postgres -t -c \
        "SELECT 1 FROM pg_roles WHERE rolname='$db_user';" 2>/dev/null | tr -d ' ')

    if [[ "$user_exists" == "1" ]]; then
        log_info "  User '$db_user' already exists — skipping user creation"
    else
        docker exec homelab-postgres psql -U "$PG_USER" -d postgres <<-EOSQL
            CREATE USER "$db_user" WITH PASSWORD '$db_pass';
		EOSQL
        log_info "  User '$db_user' created"
    fi

    # Check if database exists
    local db_exists
    db_exists=$(docker exec homelab-postgres psql -U "$PG_USER" -d postgres -t -c \
        "SELECT 1 FROM pg_database WHERE datname='$db_name';" 2>/dev/null | tr -d ' ')

    if [[ "$db_exists" == "1" ]]; then
        log_info "  Database '$db_name' already exists — skipping"
    else
        docker exec homelab-postgres psql -U "$PG_USER" -d postgres <<-EOSQL
            CREATE DATABASE "$db_name" OWNER "$db_user" ENCODING 'UTF8';
            GRANT ALL PRIVILEGES ON DATABASE "$db_name" TO "$db_user";
	EOSQL
        log_info "  Database '$db_name' created (owner: $db_user)"
    fi
}

# -----------------------------------------------------------------------------
# PostgreSQL: Create databases for all services
# -----------------------------------------------------------------------------
init_postgres() {
    log_info "=== Initializing PostgreSQL databases ==="

    create_pg_db "nextcloud"  "nextcloud"  "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
    create_pg_db "gitea"      "gitea"      "${GITEA_DB_PASSWORD:-changeme_gitea}"
    create_pg_db "outline"    "outline"    "${OUTLINE_DB_PASSWORD:-changeme_outline}"
    create_pg_db "vaultwarden" "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
    create_pg_db "bookstack"  "bookstack"  "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"

    # Outline requires uuid-ossp extension
    log_info "  Enabling uuid-ossp extension for outline..."
    docker exec homelab-postgres psql -U "$PG_USER" -d outline -c \
        "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" 2>/dev/null || \
        log_warn "  Could not create uuid-ossp extension (may already exist)"

    # Grafana (if configured)
    if [[ -n "${GRAFANA_DB_PASSWORD:-}" ]]; then
        create_pg_db "grafana" "grafana" "${GRAFANA_DB_PASSWORD}"
    fi

    # Authentik (if configured)
    if [[ -n "${AUTHENTIK_DB_PASSWORD:-}" ]]; then
        create_pg_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD}"
    fi

    log_info "PostgreSQL initialization complete"
}

# -----------------------------------------------------------------------------
# MariaDB: Create database + user (idempotent)
# -----------------------------------------------------------------------------
create_mdb_db() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="${3:-changeme}"

    log_info "MariaDB: Ensuring database '$db_name' and user '$db_user'..."

    docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '$db_user'@'%' IDENTIFIED BY '$db_pass';
        GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'%';
	EOSQL
    log_info "  Database '$db_name', user '$db_user' — OK"
}

# -----------------------------------------------------------------------------
# MariaDB: Create databases for all services
# -----------------------------------------------------------------------------
init_mariadb() {
    log_info "=== Initializing MariaDB databases ==="

    create_mdb_db "nextcloud_mysql" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme}"
    create_mdb_db "bookstack"       "bookstack" "${BOOKSTACK_DB_PASSWORD:-changeme}"

    docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" \
        -e "FLUSH PRIVILEGES;"

    log_info "MariaDB initialization complete"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "HomeLab Database Initialization Script"
    log_info "========================================"

    case "${1:-all}" in
        --postgres)
            init_postgres
            ;;
        --mariadb)
            init_mariadb
            ;;
        --all)
            init_postgres
            echo ""
            init_mariadb
            ;;
        --help|-h)
            echo "Usage: $0 [--postgres|--mariadb|--all|--help]"
            ;;
        *)
            log_error "Unknown argument: $1"
            echo "Usage: $0 [--postgres|--mariadb|--all|--help]"
            exit 1
            ;;
    esac

    log_info "All database initialization complete"
}

main "$@"
