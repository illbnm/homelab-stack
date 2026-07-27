#!/usr/bin/env bash
# scripts/init-databases.sh - Idempotent Multi-Tenant Database Initialization
# Usage: ./scripts/init-databases.sh

set -euo pipefail

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-homelab-postgres}"
POSTGRES_USER="${POSTGRES_ROOT_USER:-postgres}"

# Load environment variables if .env exists
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

create_db_user() {
    local db_name="$1"
    local db_pass="$2"

    echo "[DB Init] Processing database and user: '${db_name}'..."

    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 <<EOSQL
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}') THEN
      CREATE ROLE ${db_name} WITH LOGIN PASSWORD '${db_pass}';
   END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${db_name} OWNER ${db_name}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL

    echo "[DB Init] Database '${db_name}' verified."
}

create_db_user "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud_pass}"
create_db_user "gitea"     "${GITEA_DB_PASSWORD:-gitea_pass}"
create_db_user "outline"   "${OUTLINE_DB_PASSWORD:-outline_pass}"
create_db_user "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik_pass}"
create_db_user "grafana"   "${GRAFANA_DB_PASSWORD:-grafana_pass}"

echo "[DB Init] All databases and users initialized successfully."
