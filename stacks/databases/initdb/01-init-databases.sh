#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Creates per-service databases and users for multi-tenant PostgreSQL.
#
# IDEMPOTENT: Safe to run multiple times — will not drop or reset existing
# databases/users. Only creates what doesn't already exist.
#
# Called automatically by PostgreSQL on first container start via
# /docker-entrypoint-initdb.d/
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Helper: create a database + user pair (idempotent)
# Usage: create_db "service_name" "password" ["extra_setup_sql"]
# ---------------------------------------------------------------------------
create_db() {
  local db_name="$1"
  local db_password="$2"
  local extra_sql="${3:-}"

  echo "[init-postgres] Setting up database: ${db_name}"

  # Create user if not exists (PostgreSQL has no CREATE USER IF NOT EXISTS)
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}') THEN
        CREATE ROLE ${db_name} WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'Created user: ${db_name}';
      ELSE
        -- Update password in case it changed
        ALTER ROLE ${db_name} WITH PASSWORD '${db_password}';
        RAISE NOTICE 'User already exists (password updated): ${db_name}';
      END IF;
    END
    \$\$;
EOSQL

  # Create database if not exists
  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
       -tAc "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
      CREATE DATABASE ${db_name} OWNER ${db_name} ENCODING 'UTF8';
EOSQL
    echo "[init-postgres] Created database: ${db_name}"
  else
    echo "[init-postgres] Database already exists: ${db_name}"
  fi

  # Grant privileges (idempotent by nature)
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_name};
EOSQL

  # Run any extra setup SQL on the service database
  if [ -n "$extra_sql" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${db_name}" <<-EOSQL
      ${extra_sql}
EOSQL
  fi
}

# ---------------------------------------------------------------------------
# Create all service databases
# ---------------------------------------------------------------------------

create_db "nextcloud"   "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea"       "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline"     "${OUTLINE_DB_PASSWORD:-changeme_outline}" \
  "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
create_db "authentik"   "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana"     "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_db "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_db "bookstack"   "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"

echo "[init-postgres] All databases initialized successfully"
