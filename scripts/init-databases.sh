#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Initialization Script (Idempotent)
# Creates databases + users for all services.
# Safe to run multiple times — uses CREATE IF NOT EXISTS.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

PG_HOST="${PG_HOST:-homelab-postgres}"
PG_USER="${POSTGRES_ROOT_USER:-postgres}"
PG_PASS="${POSTGRES_ROOT_PASSWORD}"
REDIS_PASS="${REDIS_PASSWORD}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERR]${RESET} $*" >&2; }

SQL_CMD="docker exec $PG_HOST psql -U $PG_USER"

create_db() {
  local db="$1" user="$2" pass="$3"
  
  if $SQL_CMD -lqt 2>/dev/null | cut -d\| -f1 | grep -qw "$db"; then
    log_warn "Database '$db' exists, skipping"
  else
    $SQL_CMD -c "CREATE DATABASE $db;" 2>/dev/null
    log_info "Created database: $db"
  fi

  if $SQL_CMD -tAc "SELECT 1 FROM pg_roles WHERE rolname='$user'" 2>/dev/null | grep -q 1; then
    log_warn "User '$user' exists"
  else
    $SQL_CMD -c "CREATE USER $user WITH ENCRYPTED PASSWORD '$pass';" 2>/dev/null
    $SQL_CMD -c "GRANT ALL PRIVILEGES ON DATABASE $db TO $user;" 2>/dev/null
    log_info "Created user: $user"
  fi

  # Grant schema permissions
  $SQL_CMD -d "$db" -c "GRANT ALL ON SCHEMA public TO $user;" 2>/dev/null || true
}

echo "Initializing databases..."
echo ""

# Service databases
create_db "authentik" "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db "gitea"     "gitea"     "${GITEA_DB_PASSWORD:-}"
create_db "outline"   "outline"   "${OUTLINE_DB_PASSWORD:-}"
create_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db "grafana"   "grafana"   "${GRAFANA_DB_PASSWORD:-}"

echo ""
log_info "Database initialization complete!"
echo ""
echo "Redis DB allocation:"
echo "  DB 0 — Authentik"
echo "  DB 1 — Outline"
echo "  DB 2 — Gitea"
echo "  DB 3 — Nextcloud"
echo "  DB 4 — Grafana sessions"
echo ""
echo "Connection strings:"
echo "  PostgreSQL: postgresql://<user>:<pass>@homelab-postgres:5432/<db>"
echo "  Redis:      redis://:${REDIS_PASS}@homelab-redis:6379/<db>"
echo "  MariaDB:    mysql://root:${MARIADB_ROOT_PASSWORD}@homelab-mariadb:3306/"
