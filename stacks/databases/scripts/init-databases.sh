#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — PostgreSQL Multi-Tenant Initialization Script
# =============================================================================
# This script is mounted into the PostgreSQL container at:
#   /docker-entrypoint-initdb.d/10-init-databases.sh
#
# It creates isolated databases and users for each service.
# The script is IDEMPOTENT — safe to run multiple times without errors
# and without resetting existing data.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log_info()  { echo "[INIT-DB][INFO]  $*"; }
log_warn()  { echo "[INIT-DB][WARN]  $*"; }
log_error() { echo "[INIT-DB][ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# create_db — Idempotent function to create a database and user
# Usage: create_db <db_name> <db_password>
# ---------------------------------------------------------------------------
create_db() {
  local db_name="$1"
  local db_password="$2"
  local db_user="${db_name}"

  if [ -z "${db_name}" ] || [ -z "${db_password}" ]; then
    log_error "create_db requires <db_name> and <db_password>"
    return 1
  fi

  log_info "Setting up database '${db_name}' with user '${db_user}'..."

  # Create user if not exists (idempotent)
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
        CREATE ROLE "${db_user}" WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'Created user: ${db_user}';
      ELSE
        -- Update password in case it changed
        ALTER ROLE "${db_user}" WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'User already exists, updated password: ${db_user}';
      END IF;
    END
    \$\$;
EOSQL

  # Create database if not exists (idempotent)
  if psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -tAc "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" | grep -q 1; then
    log_info "Database '${db_name}' already exists, skipping creation."
  else
    psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
      CREATE DATABASE "${db_name}" OWNER "${db_user}" ENCODING 'UTF8';
EOSQL
    log_info "Created database '${db_name}'."
  fi

  # Grant privileges (idempotent)
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE "${db_name}" TO "${db_user}";
EOSQL

  # Grant schema privileges on the target database
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "${db_name}" <<-EOSQL
    GRANT ALL ON SCHEMA public TO "${db_user}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${db_user}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${db_user}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "${db_user}";
EOSQL

  log_info "Database '${db_name}' setup complete."
}

# =============================================================================
# Main — Create databases for each service
# =============================================================================
log_info "========================================"
log_info "Starting multi-tenant database initialization"
log_info "========================================"

# Create databases for all services
# Passwords are passed via environment variables from docker-compose
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud}"
create_db "gitea"     "${GITEA_DB_PASSWORD:-gitea}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:-outline}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-grafana}"

log_info "========================================"
log_info "Multi-tenant database initialization complete!"
log_info "========================================"
log_info "Databases created: nextcloud, gitea, outline, authentik, grafana"
log_info "Each database has a dedicated user with the same name."
log_info "========================================"
