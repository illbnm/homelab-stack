#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Initialization Script
# Creates roles, users, and databases for all services.
# Idempotent: safe to run multiple times.
#
# Usage: ./scripts/init-databases.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env if present
if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

# Required variables check
: "${POSTGRES_ROOT_PASSWORD:?POSTGRES_ROOT_PASSWORD not set}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD not set}"
: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD not set}"
: "${NEXTCLOUD_DB_PASSWORD:?NEXTCLOUD_DB_PASSWORD not set}"
: "${GITEA_DB_PASSWORD:?GITEA_DB_PASSWORD not set}"
: "${OUTLINE_DB_PASSWORD:?OUTLINE_DB_PASSWORD not set}"
: "${VAULTWARDEN_DB_PASSWORD:?VAULTWARDEN_DB_PASSWORD not set}"
: "${BOOKSTACK_DB_PASSWORD:?BOOKSTACK_DB_PASSWORD not set}"
: "${AUTHENTIK_DB_PASSWORD:?AUTHENTIK_DB_PASSWORD not set}"
: "${GRAFANA_DB_PASSWORD:?GRAFANA_DB_PASSWORD not set}"

log() {
  echo -e "\033[1;34m[INIT-DB]\033[0m $*"
}

# -------------------------- PostgreSQL --------------------------

create_pg_user() {
  local user="$1"
  local password="$2"
  # Check if role exists
  if docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='$user'" | grep -q 1; then
    log "PostgreSQL user '$user' exists, skipping"
  else
    log "Creating PostgreSQL user: $user"
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -d postgres -c "CREATE ROLE $user LOGIN PASSWORD '$password';" >/dev/null
  fi
}

create_pg_db() {
  local db="$1"
  local owner="$2"
  # Check if database exists
  if docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt | cut -d'|' -f1 | grep -qw "$db"; then
    log "PostgreSQL database '$db' exists, skipping"
  else
    log "Creating PostgreSQL database: $db (owner: $owner)"
    docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" -c "CREATE DATABASE $db OWNER $owner;"
  fi
}

# PostgreSQL databases and users
log "Initializing PostgreSQL databases..."
create_pg_user nextcloud "$NEXTCLOUD_DB_PASSWORD"
create_pg_db nextcloud nextcloud

create_pg_user gitea "$GITEA_DB_PASSWORD"
create_pg_db gitea gitea

create_pg_user outline "$OUTLINE_DB_PASSWORD"
create_pg_db outline outline

create_pg_user vaultwarden "$VAULTWARDEN_DB_PASSWORD"
create_pg_db vaultwarden vaultwarden

create_pg_user authentik "$AUTHENTIK_DB_PASSWORD"
create_pg_db authentik authentik

create_pg_user grafana "$GRAFANA_DB_PASSWORD"
create_pg_db grafana grafana

# -------------------------- MariaDB --------------------------

create_mariadb_db() {
  local db="$1"
  local user="$2"
  local password="$3"
  # Check if database exists
  if docker exec homelab-mariadb mysql -u root -p"$MARIADB_ROOT_PASSWORD" -e "USE $db;" >/dev/null 2>&1; then
    log "MariaDB database '$db' exists, skipping"
  else
    log "Creating MariaDB database and user: $db"
    docker exec homelab-mariadb mysql -u root -p"$MARIADB_ROOT_PASSWORD" -e "CREATE DATABASE $db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    docker exec homelab-mariadb mysql -u root -p"$MARIADB_ROOT_PASSWORD" -e "CREATE USER '$user'@'%' IDENTIFIED BY '$password';"
    docker exec homelab-mariadb mysql -u root -p"$MARIADB_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $db.* TO '$user'@'%'; FLUSH PRIVILEGES;"
  fi
}

log "Initializing MariaDB..."
# BookStack uses MariaDB
create_mariadb_db bookstack bookstack "$BOOKSTACK_DB_PASSWORD"

log "Database initialization complete."
