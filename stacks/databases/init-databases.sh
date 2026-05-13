#!/usr/bin/env bash
# Initialize multi-tenant PostgreSQL databases
# This script is idempotent - safe to run multiple times
set -euo pipefail

create_db() {
  local db_name="$1"
  local db_password="$2"
  local db_user="${db_name}"

  echo "Setting up database: $db_name"

  # Create user if not exists
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
        CREATE ROLE ${db_user} WITH LOGIN PASSWORD '${db_password}';
      ELSE
        ALTER ROLE ${db_user} WITH PASSWORD '${db_password}';
      END IF;
    END
    \$\$;
EOSQL

  # Create database if not exists
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" <<-EOSQL
    SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL

  # Grant privileges
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOSQL

  echo "✓ Database '$db_name' ready"
}

echo "=== Initializing multi-tenant databases ==="

create_db "nextcloud"  "${NEXTCLOUD_DB_PASSWORD:-nextcloud_pass}"
create_db "gitea"      "${GITEA_DB_PASSWORD:-gitea_pass}"
create_db "outline"    "${OUTLINE_DB_PASSWORD:-outline_pass}"
create_db "authentik"  "${AUTHENTIK_DB_PASSWORD:-authentik_pass}"
create_db "grafana"    "${GRAFANA_DB_PASSWORD:-grafana_pass}"

echo "=== All databases initialized ==="
