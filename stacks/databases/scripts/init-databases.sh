#!/usr/bin/env bash
# Usage: ./scripts/init-databases.sh
# Idempotently creates dedicated PostgreSQL users and databases for Nextcloud, Gitea, Outline, Authentik, and Grafana.
set -euo pipefail

create_db() {
  local db_name="$1"
  local db_pass="$2"
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER:-postgres}" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}') THEN
        CREATE ROLE ${db_name} LOGIN PASSWORD '${db_pass}';
      END IF;
    END
    \$\$;
    SELECT 'CREATE DATABASE ${db_name} OWNER ${db_name}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
    GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_name};
EOSQL
  echo "[OK] Database & role ensured: ${db_name}"
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:?NEXTCLOUD_DB_PASSWORD is required}"
create_db "gitea"     "${GITEA_DB_PASSWORD:?GITEA_DB_PASSWORD is required}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:?OUTLINE_DB_PASSWORD is required}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:?AUTHENTIK_DB_PASSWORD is required}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-change_me_grafana_db_password}"
