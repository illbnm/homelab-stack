#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Idempotent — safe to run multiple times without errors or data loss.
# Runs on first container start via /docker-entrypoint-initdb.d/
# =============================================================================
set -euo pipefail

# Helper: create database + user if they don't exist (idempotent)
create_db() {
  local db_name="$1"
  local db_password="$2"
  local extensions="${3:-}"

  echo "[init-postgres] Setting up database: $db_name"

  # Create user (idempotent)
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db_name') THEN
        CREATE ROLE "$db_name" WITH LOGIN PASSWORD '$db_password';
        RAISE NOTICE 'User $db_name created';
      ELSE
        ALTER ROLE "$db_name" WITH PASSWORD '$db_password';
        RAISE NOTICE 'User $db_name already exists, password updated';
      END IF;
    END
    \$\$;
EOSQL

  # Create database (idempotent)
  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tc \
    "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
      -c "CREATE DATABASE \"$db_name\" OWNER \"$db_name\" ENCODING 'UTF8';"
    echo "[init-postgres]   Database $db_name created"
  else
    echo "[init-postgres]   Database $db_name already exists"
  fi

  # Grant privileges
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "GRANT ALL PRIVILEGES ON DATABASE \"$db_name\" TO \"$db_name\";"

  # Create extensions if specified
  if [ -n "$extensions" ]; then
    IFS=',' read -ra EXTS <<< "$extensions"
    for ext in "${EXTS[@]}"; do
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" \
        -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";"
      echo "[init-postgres]   Extension $ext enabled in $db_name"
    done
  fi
}

# ── Create per-service databases ──────────────
create_db "nextcloud"   "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea"       "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline"     "${OUTLINE_DB_PASSWORD:-changeme_outline}"    "uuid-ossp"
create_db "authentik"   "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana"     "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_db "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_db "bookstack"   "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"

echo "[init-postgres] All databases initialized successfully"
