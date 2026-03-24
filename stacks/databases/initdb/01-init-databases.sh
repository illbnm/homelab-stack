#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script (Idempotent)
# Runs on first container start. Creates per-service databases and users.
# Safe to re-run: skips existing objects without error.
# =============================================================================
set -euo pipefail

echo "[init-postgres] Starting database initialization..."

# -----------------------------------------------------------------------------
# Helper: create user if not exists
# -----------------------------------------------------------------------------
create_user_if_missing() {
  local user="$1"
  local password="$2"
  # Check if user exists
  if ! psql -Atc "SELECT 1 FROM pg_roles WHERE rolname='${user}'" | grep -q 1; then
    echo "[init-postgres] Creating user: ${user}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
      CREATE USER ${user} WITH PASSWORD '${password}';
EOSQL
  else
    echo "[init-postgres] User already exists, skipping: ${user}"
  fi
}

# -----------------------------------------------------------------------------
# Helper: create database if not exists
# -----------------------------------------------------------------------------
create_db_if_missing() {
  local db="$1"
  local owner="$2"
  local encoding="${3:-UTF8}"
  # Check if database exists
  if ! psql -Atc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
    echo "[init-postgres] Creating database: ${db}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
      CREATE DATABASE ${db} OWNER ${owner} ENCODING '${encoding}';
      GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${owner};
EOSQL
  else
    echo "[init-postgres] Database already exists, skipping: ${db}"
  fi
}

# -----------------------------------------------------------------------------
# Services: Nextcloud
# -----------------------------------------------------------------------------
USER="nextcloud"
PASS="${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

# -----------------------------------------------------------------------------
# Services: Gitea
# -----------------------------------------------------------------------------
USER="gitea"
PASS="${GITEA_DB_PASSWORD:-changeme_gitea}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

# -----------------------------------------------------------------------------
# Services: Outline
# -----------------------------------------------------------------------------
USER="outline"
PASS="${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"
# Outline requires uuid-ossp extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" <<EOSQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
echo "[init-postgres] Outline uuid-ossp extension ensured"

# -----------------------------------------------------------------------------
# Services: Vaultwarden
# -----------------------------------------------------------------------------
USER="vaultwarden"
PASS="${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

# -----------------------------------------------------------------------------
# Services: BookStack
# -----------------------------------------------------------------------------
USER="bookstack"
PASS="${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

# -----------------------------------------------------------------------------
# Services: Authentik
# -----------------------------------------------------------------------------
USER="authentik"
PASS="${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

# -----------------------------------------------------------------------------
# Services: Grafana
# -----------------------------------------------------------------------------
USER="grafana"
PASS="${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_user_if_missing "$USER" "$PASS"
create_db_if_missing "$USER" "$USER" "UTF8"

echo "[init-postgres] All databases created successfully"
