#!/usr/bin/env bash
# scripts/init-databases.sh
# Idempotent database & user provisioning for shared PostgreSQL multi-tenant layer

set -euo pipefail

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

create_db() {
    local db_name="$1"
    local db_pass="$2"

    echo "[init-db] Ensuring user and database exist for: ${db_name}..."

    # Create user if not exists
    psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}') THEN
                CREATE ROLE ${db_name} WITH LOGIN PASSWORD '${db_pass}';
            END IF;
        END
        \$\$;
EOSQL

    # Create database if not exists
    psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
        SELECT 'CREATE DATABASE ${db_name} OWNER ${db_name}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
        GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_name};
EOSQL
}

# Idempotently provision shared databases
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud_secret_pass}"
create_db "gitea"     "${GITEA_DB_PASSWORD:-gitea_secret_pass}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:-outline_secret_pass}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik_secret_pass}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-grafana_secret_pass}"

echo "[init-db] All shared databases provisioned successfully."
