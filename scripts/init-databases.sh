#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Initialization Script
# Creates per-service databases and users in PostgreSQL.
# IDEMPOTENT — safe to run multiple times, won't reset existing data.
#
# Usage: ./scripts/init-databases.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log_ok()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[SKIP]${RESET} $*"; }
log_error() { echo -e "${RED}[ERR]${RESET} $*" >&2; }

PGHOST="${DB_HOST:-homelab-postgres}"
PGPORT="${DB_PORT:-5432}"
PGUSER="${POSTGRES_ROOT_USER:-postgres}"
PGPASSWORD="${POSTGRES_ROOT_PASSWORD:-}"
export PGPASSWORD

# ------------------------------------------------------------------
# Helper: execute SQL if DB/user don't exist
# ------------------------------------------------------------------
create_db_user() {
  local db="$1" user="$2" pass="$3"

  # Check if database exists
  if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$db"; then
    log_warn "Database '$db' already exists"
  else
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE DATABASE \"$db\";" 2>/dev/null
    log_ok "Created database: $db"
  fi

  # Check if user exists
  if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$user';" 2>/dev/null | grep -q 1; then
    log_warn "User '$user' already exists"
  else
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE USER \"$user\" WITH PASSWORD '$pass';" 2>/dev/null
    log_ok "Created user: $user"
  fi

  # Grant privileges (idempotent — won't error if already granted)
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "GRANT ALL PRIVILEGES ON DATABASE \"$db\" TO \"$user\";" 2>/dev/null
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$db" -c "GRANT ALL ON SCHEMA public TO \"$user\";" 2>/dev/null
  log_ok "Granted privileges: $user → $db"
}

# ------------------------------------------------------------------
# Wait for PostgreSQL
# ------------------------------------------------------------------
echo "Waiting for PostgreSQL..."
for i in $(seq 1 20); do
  if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "SELECT 1;" > /dev/null 2>&1; then
    echo ""
    log_ok "PostgreSQL is ready"
    break
  fi
  if [ "$i" -eq 20 ]; then
    log_error "PostgreSQL did not become ready"
    exit 1
  fi
  echo -n "."
  sleep 3
done

# ------------------------------------------------------------------
# Create databases and users
# ------------------------------------------------------------------
echo ""
echo "Creating databases and users..."

create_db_user "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db_user "gitea" "gitea" "${GITEA_DB_PASSWORD:-}"
create_db_user "outline" "outline" "${OUTLINE_DB_PASSWORD:-}"
create_db_user "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db_user "grafana" "grafana" "${GRAFANA_DB_PASSWORD:-}"

echo ""
log_ok "All databases initialized."