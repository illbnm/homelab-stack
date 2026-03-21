#!/bin/bash
set -euo pipefail

# Database initialization script for HomeLab Stack
# Creates databases and users for all services requiring database backends
# Safe for repeated execution with proper idempotency checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    source "${PROJECT_ROOT}/.env"
fi

# Default database credentials (override in .env)
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_ROOT_USER="${POSTGRES_ROOT_USER:-postgres}"
POSTGRES_ROOT_PASSWORD="${POSTGRES_ROOT_PASSWORD:-postgres}"

MARIADB_HOST="${MARIADB_HOST:-localhost}"
MARIADB_PORT="${MARIADB_PORT:-3306}"
MARIADB_ROOT_USER="${MARIADB_ROOT_USER:-root}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-mariadb}"

# Service database configurations
declare -A POSTGRES_DBS=(
    ["nextcloud"]="nextcloud_user:nextcloud_pass"
    ["authentik"]="authentik_user:authentik_pass"
    ["outline"]="outline_user:outline_pass"
    ["grafana"]="grafana_user:grafana_pass"
)

declare -A MARIADB_DBS=(
    ["gitea"]="gitea_user:gitea_pass"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

check_postgres_connection() {
    log "Testing PostgreSQL connection..."
    if ! PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        error "Cannot connect to PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"
    fi
    success "PostgreSQL connection established"
}

check_mariadb_connection() {
    log "Testing MariaDB connection..."
    if ! mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        error "Cannot connect to MariaDB at ${MARIADB_HOST}:${MARIADB_PORT}"
    fi
    success "MariaDB connection established"
}

database_exists_postgres() {
    local db_name="$1"
    PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}';" | grep -q 1
}

user_exists_postgres() {
    local username="$1"
    PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -tAc "SELECT 1 FROM pg_user WHERE usename='${username}';" | grep -q 1
}

database_exists_mariadb() {
    local db_name="$1"
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" | grep -q "${db_name}"
}

user_exists_mariadb() {
    local username="$1"
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT User FROM mysql.user WHERE User='${username}';" | grep -q "${username}"
}

create_postgres_database() {
    local service="$1"
    local creds="${POSTGRES_DBS[$service]}"
    local username="${creds%:*}"
    local password="${creds#*:}"

    log "Setting up PostgreSQL database for ${service}..."

    # Create user if not exists
    if ! user_exists_postgres "${username}"; then
        log "Creating PostgreSQL user: ${username}"
        PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c \
            "CREATE USER ${username} WITH PASSWORD '${password}';"
        success "Created PostgreSQL user: ${username}"
    else
        log "PostgreSQL user ${username} already exists"
        # Update password to ensure it matches current config
        PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c \
            "ALTER USER ${username} WITH PASSWORD '${password}';"
    fi

    # Create database if not exists
    if ! database_exists_postgres "${service}"; then
        log "Creating PostgreSQL database: ${service}"
        PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c \
            "CREATE DATABASE ${service} OWNER ${username};"
        success "Created PostgreSQL database: ${service}"
    else
        log "PostgreSQL database ${service} already exists"
        # Ensure correct ownership
        PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c \
            "ALTER DATABASE ${service} OWNER TO ${username};"
    fi

    # Grant all privileges
    PGPASSWORD="${POSTGRES_ROOT_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_ROOT_USER}" -d postgres -c \
        "GRANT ALL PRIVILEGES ON DATABASE ${service} TO ${username};"

    success "PostgreSQL setup complete for ${service}"
}

create_mariadb_database() {
    local service="$1"
    local creds="${MARIADB_DBS[$service]}"
    local username="${creds%:*}"
    local password="${creds#*:}"

    log "Setting up MariaDB database for ${service}..."

    # Create database if not exists
    if ! database_exists_mariadb "${service}"; then
        log "Creating MariaDB database: ${service}"
        mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e \
            "CREATE DATABASE IF NOT EXISTS ${service} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        success "Created MariaDB database: ${service}"
    else
        log "MariaDB database ${service} already exists"
    fi

    # Create or update user
    log "Setting up MariaDB user: ${username}"
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e \
        "CREATE USER IF NOT EXISTS '${username}'@'%' IDENTIFIED BY '${password}';"

    # Update password (in case user exists)
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e \
        "SET PASSWORD FOR '${username}'@'%' = PASSWORD('${password}');"

    # Grant privileges
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e \
        "GRANT ALL PRIVILEGES ON ${service}.* TO '${username}'@'%';"

    # Flush privileges
    mysql -h "${MARIADB_HOST}" -P "${MARIADB_PORT}" -u "${MARIADB_ROOT_USER}" -p"${MARIADB_ROOT_PASSWORD}" -e \
        "FLUSH PRIVILEGES;"

    success "MariaDB setup complete for ${service}"
}

wait_for_databases() {
    local max_attempts=30
    local attempt=0

    log "Waiting for database services to be ready..."

    while [[ $attempt -lt $max_attempts ]]; do
        if check_postgres_connection >/dev/null 2>&1 && check_mariadb_connection >/dev/null 2>&1; then
            success "All database services are ready"
            return 0
        fi

        attempt=$((attempt + 1))
        log "Attempt ${attempt}/${max_attempts}: Waiting for databases..."
        sleep 2
    done

    error "Database services failed to become ready within ${max_attempts} attempts"
}

main() {
    log "Starting database initialization for HomeLab Stack"

    # Check if databases stack is running
    if ! docker compose -f "${PROJECT_ROOT}/stacks/databases/docker-compose.yml" ps --status running | grep -q postgres; then
        warn "Databases stack appears to be down. Please start it first:"
        warn "  cd stacks/databases && docker compose up -d"
        exit 1
    fi

    # Wait for services to be ready
    wait_for_databases

    # Verify connections
    check_postgres_connection
    check_mariadb_connection

    # Initialize PostgreSQL databases
    log "Initializing PostgreSQL databases..."
    for service in "${!POSTGRES_DBS[@]}"; do
        create_postgres_database "${service}"
    done

    # Initialize MariaDB databases
    log "Initializing MariaDB databases..."
    for service in "${!MARIADB_DBS[@]}"; do
        create_mariadb_database "${service}"
    done

    success "Database initialization completed successfully!"

    log "Database summary:"
    log "  PostgreSQL databases: ${!POSTGRES_DBS[*]}"
    log "  MariaDB databases: ${!MARIADB_DBS[*]}"
    log ""
    log "Management UIs available at:"
    log "  pgAdmin: https://pgadmin.${DOMAIN:-localhost}"
    log "  Redis Commander: https://redis.${DOMAIN:-localhost}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
