#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# IDEMPOTENT: safe to re-run — skips existing users/databases.
# =============================================================================
set -euo pipefail

log() { echo "[init-postgres] $*"; }

# Helper: create user if not exists
create_user() {
  local user="$1" pass="$2"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -tc "SELECT 1 FROM pg_roles WHERE rolname = '${user}'" | grep -q 1 || {
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
      -c "CREATE USER ${user} WITH PASSWORD '${pass}';"
    log "Created user: ${user}"
  }
}

# Helper: create database if not exists, grant privileges
create_db() {
  local db="$1" owner="$2"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -tc "SELECT 1 FROM pg_database WHERE datname = '${db}'" | grep -q 1 || {
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
      -c "CREATE DATABASE ${db} OWNER ${owner} ENCODING 'UTF8';"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
      -c "GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${owner};"
    log "Created database: ${db} (owner: ${owner})"
  }
}

# --- Per-service databases ---

create_user "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db  "nextcloud" "nextcloud"

create_user "gitea" "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db  "gitea" "gitea"

create_user "outline" "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_db  "outline" "outline"

create_user "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db  "authentik" "authentik"

create_user "grafana" "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_db  "grafana" "grafana"

create_user "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_db  "vaultwarden" "vaultwarden"

create_user "bookstack" "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"
create_db  "bookstack" "bookstack"

# --- Extensions ---
# Outline requires uuid-ossp
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" \
  -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

# Grafana benefits from pg_trgm
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "grafana" \
  -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";" 2>/dev/null || true

log "All databases initialized successfully"
