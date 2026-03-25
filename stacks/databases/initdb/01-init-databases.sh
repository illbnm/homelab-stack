#!/bin/bash
# =============================================================================
# PostgreSQL Multi-tenant Initialization Script
# Creates databases and users for each service
# IDEMPOTENT: Safe to run multiple times
# =============================================================================

set -euo pipefail

echo "=== Initializing PostgreSQL Databases ==="

# Function to create database and user (idempotent)
create_db() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"

    if [ -z "$db_password" ]; then
        echo "Skipping $db_name: no password provided"
        return 0
    fi

    echo "Creating database: $db_name"

    # Create user if not exists (idempotent)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
                CREATE ROLE ${db_user} WITH LOGIN PASSWORD '${db_password}';
                RAISE NOTICE 'Created user: ${db_user}';
            ELSE
                RAISE NOTICE 'User already exists: ${db_user}';
            END IF;
        END
        \$\$;

        -- Create database if not exists
        SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user} ENCODING '\''UTF8'\'''
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec

        -- Grant privileges
        GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOSQL

    echo "✓ Database $db_name ready"
}

# Create databases for each service
# Passwords are passed via environment variables

create_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db "gitea" "gitea" "${GITEA_DB_PASSWORD:-}"
create_db "outline" "outline" "${OUTLINE_DB_PASSWORD:-}"
create_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db "grafana" "grafana" "${GRAFANA_DB_PASSWORD:-}"

echo ""
echo "=== PostgreSQL Initialization Complete ==="
echo "Databases created:"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';"
