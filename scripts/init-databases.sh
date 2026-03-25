#!/bin/bash
# =============================================================================
# init-databases.sh - Multi-tenant database initialization
# Usage: init-databases.sh [--postgres|--mariadb|--all]
#
# Creates databases and users for each service.
# IDEMPOTENT: Safe to run multiple times.
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")/stacks/databases"

# Load environment
if [ -f "$STACK_DIR/.env" ]; then
    set -a
    source "$STACK_DIR/.env"
    set +a
fi

# Default: initialize all
INIT_POSTGRES=true
INIT_MARIADB=true

# Parse arguments
case "${1:-all}" in
    --postgres)
        INIT_MARIADB=false
        ;;
    --mariadb)
        INIT_POSTGRES=false
        ;;
    --all|*)
        ;;
esac

echo -e "${GREEN}=== Database Initialization ===${NC}"
echo ""

# -----------------------------------------------------------------------------
# PostgreSQL Initialization
# -----------------------------------------------------------------------------
init_postgres() {
    echo -e "${GREEN}Initializing PostgreSQL...${NC}"

    # Check if PostgreSQL is running
    if ! docker exec homelab-postgres pg_isready -U "${POSTGRES_ROOT_USER:-postgres}" >/dev/null 2>&1; then
        echo -e "${RED}Error: PostgreSQL container is not running${NC}"
        return 1
    fi

    # Function to create database and user (idempotent)
    create_db() {
        local db_name="$1"
        local db_user="$2"
        local db_password="$3"

        if [ -z "$db_password" ]; then
            echo -e "${YELLOW}  Skipping $db_name: no password provided${NC}"
            return 0
        fi

        echo "  Creating: $db_name"

        docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -d postgres <<-EOSQL
            DO \$\$
            BEGIN
                IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
                    CREATE ROLE ${db_user} WITH LOGIN PASSWORD '${db_password}';
                END IF;
            END
            \$\$;

            SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user} ENCODING '\''UTF8'\'''
            WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec

            GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOSQL

        echo -e "  ${GREEN}✓ $db_name ready${NC}"
    }

    # Create databases
    create_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
    create_db "gitea" "gitea" "${GITEA_DB_PASSWORD:-}"
    create_db "outline" "outline" "${OUTLINE_DB_PASSWORD:-}"
    create_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
    create_db "grafana" "grafana" "${GRAFANA_DB_PASSWORD:-}"

    echo ""
    echo "PostgreSQL databases:"
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';"
}

# -----------------------------------------------------------------------------
# MariaDB Initialization
# -----------------------------------------------------------------------------
init_mariadb() {
    echo -e "${GREEN}Initializing MariaDB...${NC}"

    # Check if MariaDB is running
    if ! docker exec homelab-mariadb healthcheck.sh --connect >/dev/null 2>&1; then
        echo -e "${RED}Error: MariaDB container is not running${NC}"
        return 1
    fi

    # Function to create database and user (idempotent)
    create_mysql_db() {
        local db_name="$1"
        local db_user="$2"
        local db_password="$3"

        if [ -z "$db_password" ]; then
            echo -e "${YELLOW}  Skipping $db_name: no password provided${NC}"
            return 0
        fi

        echo "  Creating: $db_name"

        docker exec homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
            CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';
            CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
            GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
            FLUSH PRIVILEGES;
EOSQL

        echo -e "  ${GREEN}✓ $db_name ready${NC}"
    }

    # Create databases
    create_mysql_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
    create_mysql_db "bookstack" "bookstack" "${BOOKSTACK_DB_PASSWORD:-}"

    echo ""
    echo "MariaDB databases:"
    docker exec homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -N -e "SHOW DATABASES;" | grep -v -E "information_schema|mysql|performance_schema"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if [ "$INIT_POSTGRES" = true ]; then
    init_postgres
fi

if [ "$INIT_MARIADB" = true ]; then
    init_mariadb
fi

echo ""
echo -e "${GREEN}=== Initialization Complete ===${NC}"
