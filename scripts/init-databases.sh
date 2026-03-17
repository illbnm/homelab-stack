#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Initialization Wrapper
# =============================================================================
# Convenience wrapper that triggers the PostgreSQL and MariaDB init scripts
# inside their running containers. Useful for re-running initialization
# after the first boot.
#
# Usage:
#   ./scripts/init-databases.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source .env if available
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# ---------------------------------------------------------------------------
# Check containers
# ---------------------------------------------------------------------------
check_container() {
  local name="$1"
  if ! docker inspect --format='{{.State.Health.Status}}' "${name}" 2>/dev/null | grep -q healthy; then
    log_error "Container '${name}' is not healthy. Start the databases stack first:"
    log_error "  docker compose -f stacks/databases/docker-compose.yml --env-file .env up -d"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_step "HomeLab Database Initialization"

# Check PostgreSQL
log_step "Initializing PostgreSQL databases..."
if check_container "homelab-postgres"; then
  docker exec \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_DB=postgres \
    -e NEXTCLOUD_DB_PASSWORD="${NEXTCLOUD_DB_PASSWORD:-}" \
    -e GITEA_DB_PASSWORD="${GITEA_DB_PASSWORD:-}" \
    -e OUTLINE_DB_PASSWORD="${OUTLINE_DB_PASSWORD:-}" \
    -e AUTHENTIK_DB_PASSWORD="${AUTHENTIK_DB_PASSWORD:-}" \
    -e GRAFANA_DB_PASSWORD="${GRAFANA_DB_PASSWORD:-}" \
    homelab-postgres bash /docker-entrypoint-initdb.d/10-init-databases.sh
  log_info "PostgreSQL initialization complete."
else
  log_error "PostgreSQL initialization skipped."
fi

# Check MariaDB
log_step "Initializing MariaDB databases..."
if check_container "homelab-mariadb"; then
  docker exec \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}" \
    -e NEXTCLOUD_MARIADB_PASSWORD="${NEXTCLOUD_MARIADB_PASSWORD:-}" \
    homelab-mariadb bash /docker-entrypoint-initdb.d/10-init-mariadb.sh
  log_info "MariaDB initialization complete."
else
  log_error "MariaDB initialization skipped."
fi

log_step "All database initialization complete!"
log_info ""
log_info "Verify with:"
log_info "  docker exec homelab-postgres psql -U postgres -c '\\l'"
log_info "  docker exec homelab-mariadb mysql -u root -p\"\${MARIADB_ROOT_PASSWORD}\" -e 'SHOW DATABASES;'"
