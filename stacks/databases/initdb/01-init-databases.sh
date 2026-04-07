#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script (Idempotent)
# Runs on first container start. Creates per-service databases and users.
# =============================================================================

set -euo pipefail

echo "[init-postgres] Starting database initialization..."

# Idempotent function to create user and database
create_service_db() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    local extensions="${4:-}"

    echo "[init-postgres] Processing: $db_name"

    # Create user if not exists (idempotent)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
                CREATE USER ${db_user} WITH PASSWORD '${db_password}';
                RAISE NOTICE 'Created user: ${db_user}';
            ELSE
                RAISE NOTICE 'User already exists: ${db_user}';
            END IF;
        END
        \$\$;
EOSQL

    # Create database if not exists (idempotent)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user} ENCODING '\''UTF8'\'''
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL

    # Grant privileges
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOSQL

    # Apply extensions if specified
    if [ -n "$extensions" ]; then
        IFS=',' read -ra EXT_ARRAY <<< "$extensions"
        for ext in "${EXT_ARRAY[@]}"; do
            echo "[init-postgres] Adding extension: $ext to $db_name"
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
                CREATE EXTENSION IF NOT EXISTS "${ext}";
EOSQL
        done
    fi

    echo "[init-postgres] ✓ $db_name ready"
}

# Create databases for all services
echo "[init-postgres] Creating service databases..."

create_service_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_service_db "gitea" "gitea" "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_service_db "outline" "outline" "${OUTLINE_DB_PASSWORD:-changeme_outline}" "uuid-ossp"
create_service_db "vaultwarden" "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_service_db "bookstack" "bookstack" "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"
create_service_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_service_db "grafana" "grafana" "${GRAFANA_DB_PASSWORD:-changeme_grafana}"

echo "[init-postgres] ✓ All databases created successfully"
