#!/bin/bash
# init-databases.sh - Initialize PostgreSQL multi-tenant databases
# This script is idempotent - safe to run multiple times

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -E '^[A-Z]' "$ENV_FILE" | xargs)
fi

# Default values
PG_HOST="${PG_HOST:-postgres}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${POSTGRES_ROOT_USER:-postgres}"
PG_PASSWORD="${POSTGRES_ROOT_PASSWORD}"
PG_DB="${PG_DB:-postgres}"

# Databases and users to create
declare -A SERVICES
SERVICES["nextcloud"]="${NEXTCLOUD_DB_PASSWORD:-nextcloud_secret}"
SERVICES["gitea"]="${GITEA_DB_PASSWORD:-gitea_secret}"
SERVICES["outline"]="${OUTLINE_DB_PASSWORD:-outline_secret}"
SERVICES["authentik"]="${AUTHENTIK_DB_PASSWORD:-authentik_secret}"
SERVICES["grafana"]="${GRAFANA_DB_PASSWORD:-grafana_secret}"

echo "=== PostgreSQL Multi-Tenant Database Initialization ==="
echo "Host: ${PG_HOST}:${PG_PORT}"
echo "User: ${PG_USER}"
echo ""

# Export PGPASSWORD for psql
export PGPASSWORD="${PG_PASSWORD}"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c '\q' 2>/dev/null; do
    echo "  PostgreSQL is unavailable - sleeping"
    sleep 2
done
echo "PostgreSQL is ready!"
echo ""

# Function to create database and user (idempotent)
create_db() {
    local db_name="$1"
    local db_password="$2"

    echo "--- Setting up database: ${db_name} ---"

    # Check if database exists
    if psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
        echo "  Database '${db_name}' already exists"
    else
        echo "  Creating database '${db_name}'..."
        psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c "CREATE DATABASE \"${db_name}\";"
        echo "  Database '${db_name}' created"
    fi

    # Check if user exists
    if psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_name}'" | grep -q 1; then
        echo "  User '${db_name}' already exists"
    else
        echo "  Creating user '${db_name}'..."
        psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c "CREATE USER \"${db_name}\" WITH PASSWORD '${db_password}';"
        echo "  User '${db_name}' created"
    fi

    # Grant privileges
    echo "  Granting privileges..."
    psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c "GRANT ALL PRIVILEGES ON DATABASE \"${db_name}\" TO \"${db_name}\";"
    psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c "ALTER DATABASE \"${db_name}\" OWNER TO \"${db_name}\";"

    echo "  Database '${db_name}' setup complete!"
    echo ""
}

# Create all databases
for service in "${!SERVICES[@]}"; do
    password="${SERVICES[$service]}"
    create_db "$service" "$password"
done

# Grant schema privileges for psql tools
echo "--- Granting schema privileges ---"
psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -c "GRANT ALL ON SCHEMA public TO ${PG_USER};" 2>/dev/null || true

echo ""
echo "=== All databases initialized successfully! ==="
echo ""
echo "Database connection strings:"
echo ""
for service in "${!SERVICES[@]}"; do
    echo "  ${service}: postgresql://${service}:${SERVICES[$service]}@postgres:5432/${service}"
done
echo ""

unset PGPASSWORD
