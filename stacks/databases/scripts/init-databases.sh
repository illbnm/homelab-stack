#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — PostgreSQL Multi-Tenant Initialization Script
# =============================================================================
# This script is mounted into the PostgreSQL container at:
#   /docker-entrypoint-initdb.d/10-init-databases.sh
#
# It creates isolated databases and users for each service following the
# principle of LEAST PRIVILEGE:
#   - Each service gets a dedicated user (<service>_user) and database
#   - Users can only access their own database
#   - PUBLIC access is revoked from each database
#   - Only necessary privileges are granted (CONNECT, CRUD, schema usage)
#
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
# create_db — Idempotent function to create an isolated database and user
# Usage: create_db <db_name> <db_password>
# Creates: database "<db_name>" with user "<db_name>_user"
# ---------------------------------------------------------------------------
create_db() {
  local db_name="$1"
  local db_password="$2"
  local db_user="${db_name}_user"

  if [ -z "${db_name}" ] || [ -z "${db_password}" ]; then
    log_error "create_db requires <db_name> and <db_password>"
    return 1
  fi

  log_info "Setting up database '${db_name}' with user '${db_user}'..."

  # -------------------------------------------------------------------------
  # Step 1: Create user if not exists (idempotent)
  # -------------------------------------------------------------------------
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
        CREATE ROLE "${db_user}" WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'Created user: ${db_user}';
      ELSE
        -- Update password in case it changed (idempotent)
        ALTER ROLE "${db_user}" WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'User already exists, updated password: ${db_user}';
      END IF;
    END
    \$\$;
EOSQL

  # -------------------------------------------------------------------------
  # Step 2: Create database if not exists (idempotent)
  # -------------------------------------------------------------------------
  if psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -tAc "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" | grep -q 1; then
    log_info "Database '${db_name}' already exists, skipping creation."
  else
    psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
      CREATE DATABASE "${db_name}" OWNER "${db_user}" ENCODING 'UTF8';
EOSQL
    log_info "Created database '${db_name}'."
  fi

  # -------------------------------------------------------------------------
  # Step 3: Revoke public access and grant minimal privileges (least privilege)
  # -------------------------------------------------------------------------

  # Revoke all default public access on this database
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    REVOKE ALL ON DATABASE "${db_name}" FROM PUBLIC;
    GRANT CONNECT ON DATABASE "${db_name}" TO "${db_user}";
EOSQL

  # Grant scoped privileges on the target database's public schema
  psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "${db_name}" <<-EOSQL
    -- Schema access
    GRANT USAGE, CREATE ON SCHEMA public TO "${db_user}";

    -- Table privileges (SELECT, INSERT, UPDATE, DELETE only — no TRUNCATE, REFERENCES, TRIGGER)
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${db_user}";

    -- Sequence privileges
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO "${db_user}";

    -- Function privileges
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO "${db_user}";
EOSQL

  log_info "Database '${db_name}' setup complete. User '${db_user}' has scoped access only."
}

# =============================================================================
# Main — Create databases for each service
# =============================================================================
log_info "========================================"
log_info "Starting multi-tenant database initialization"
log_info "========================================"

# Create isolated databases for all services
# Each gets: database "<name>" + user "<name>_user" with minimal privileges
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
log_info "Users created: nextcloud_user, gitea_user, outline_user, authentik_user, grafana_user"
log_info "Each user has minimal privileges scoped to their own database only."
log_info "========================================"
