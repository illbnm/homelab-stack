#!/bin/bash
set -euo pipefail

# Runs only on first PostgreSQL container initialization.
# Keeps idempotent SQL style so script can be safely reused.

create_db() {
  local db="$1"
  local password="$2"

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
DO \
\$\$\
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$db') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '$db', '$password');
  END IF;
END
\$\$;
DO \
\$\$\
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$db') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I ENCODING ''UTF8''', '$db', '$db');
  END IF;
END
\$\$;
GRANT ALL PRIVILEGES ON DATABASE "$db" TO "$db";
SQL

  if [[ "$db" == "outline" ]]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
  fi
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea" "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline" "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana" "${GRAFANA_DB_PASSWORD:-changeme_grafana}"

echo "[init-postgres] All databases ensured"