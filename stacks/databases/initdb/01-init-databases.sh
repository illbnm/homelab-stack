#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# IDEMPOTENT: Can be run multiple times without errors.
# =============================================================================
set -euo pipefail

echo "[init-postgres] Starting database initialization..."

# Function to create user and database if not exists
create_db() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="$3"

    if [ -z "$db_pass" ]; then
        echo "[init-postgres] Skipping $db_name - no password provided"
        return 0
    fi

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- Create user if not exists
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
                CREATE USER ${db_user} WITH PASSWORD '${db_pass}';
                RAISE NOTICE 'Created user: ${db_user}';
            END IF;
        END
        \$\$;

        -- Create database if not exists
        SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user} ENCODING ''UTF8'''
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec

        -- Grant privileges
        GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOSQL

    echo "[init-postgres] Database '${db_name}' ready for user '${db_user}'"
}

# Create databases for each service
create_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db "gitea" "gitea" "${GITEA_DB_PASSWORD:-}"
create_db "outline" "outline" "${OUTLINE_DB_PASSWORD:-}"
create_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db "grafana" "grafana" "${GRAFANA_DB_PASSWORD:-}"
create_db "vaultwarden" "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-}"
create_db "bookstack" "bookstack" "${BOOKSTACK_DB_PASSWORD:-}"

# Create extensions for Outline database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EOSQL

echo "[init-postgres] All databases created successfully"