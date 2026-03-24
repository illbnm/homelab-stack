#!/usr/bin/env bash
# =============================================================================
# Idempotent Database Init Script
# Run manually or on stack deploy. Safe to re-run — does not reset existing data.
# Usage: ./init-databases.sh [--postgres|--redis|--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

init_postgres() {
  log_info "Initializing PostgreSQL databases..."
  
  # shellcheck disable=SC2086
  docker exec homelab-postgres psql -v ON_ERROR_STOP=1 \
    --username "${POSTGRES_ROOT_USER:-postgres}" --dbname postgres <<-EOSQL
    -- Nextcloud
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nextcloud') THEN
        CREATE USER nextcloud WITH PASSWORD '\${NEXTCLOUD_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nextcloud') THEN
        CREATE DATABASE nextcloud OWNER nextcloud ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;

    -- Gitea
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea') THEN
        CREATE USER gitea WITH PASSWORD '\${GITEA_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea') THEN
        CREATE DATABASE gitea OWNER gitea ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

    -- Outline
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'outline') THEN
        CREATE USER outline WITH PASSWORD '\${OUTLINE_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'outline') THEN
        CREATE DATABASE outline OWNER outline ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    -- Enable uuid-ossp extension
    \\c outline
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    \\c postgres

    -- Authentik
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authentik') THEN
        CREATE USER authentik WITH PASSWORD '\${AUTHENTIK_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'authentik') THEN
        CREATE DATABASE authentik OWNER authentik ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

    -- Grafana
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'grafana') THEN
        CREATE USER grafana WITH PASSWORD '\${GRAFANA_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'grafana') THEN
        CREATE DATABASE grafana OWNER grafana ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;

    -- Vaultwarden
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden') THEN
        CREATE USER vaultwarden WITH PASSWORD '\${VAULTWARDEN_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vaultwarden') THEN
        CREATE DATABASE vaultwarden OWNER vaultwarden ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;

    -- BookStack
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bookstack') THEN
        CREATE USER bookstack WITH PASSWORD '\${BOOKSTACK_DB_PASSWORD:-changeme}';
      END IF;
    END
    \$\$;
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bookstack') THEN
        CREATE DATABASE bookstack OWNER bookstack ENCODING 'UTF8';
      END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;
EOSQL

  log_info "PostgreSQL databases initialized successfully"
}

init_redis() {
  log_info "Configuring Redis multi-database allocation..."
  log_info "Redis DB allocation:"
  log_info "  DB 0 — Authentik"
  log_info "  DB 1 — Outline"
  log_info "  DB 2 — Gitea"
  log_info "  DB 3 — Nextcloud"
  log_info "  DB 4 — Grafana sessions"
  log_info "Configure services to use ?db=N query parameter"
}

case "${1:-all}" in
  --postgres) init_postgres ;;
  --redis)    init_redis ;;
  --all)
    init_postgres
    init_redis
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--all]"; exit 1 ;;
esac

log_info "Database initialization complete"
