#!/usr/bin/env bash
set -euo pipefail

# Idempotent PostgreSQL tenant bootstrap for HomeLab stack.
# Usage: ./scripts/init-databases.sh

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-homelab-postgres}"
POSTGRES_SUPERUSER="${POSTGRES_ROOT_USER:-postgres}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERR] docker not found" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$POSTGRES_CONTAINER"; then
  echo "[ERR] container '$POSTGRES_CONTAINER' is not running" >&2
  exit 1
fi

sql_escape_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

create_db() {
  local db="$1"
  local password_raw="$2"
  local password
  password="$(sql_escape_literal "$password_raw")"

  docker exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_SUPERUSER" -d postgres <<SQL
DO \
\$\$\
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$db') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '$db', '$password');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '$db', '$password');
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
    docker exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_SUPERUSER" -d outline \
      -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' >/dev/null
  fi

  echo "[OK] ensured DB+ROLE: $db"
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea" "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline" "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana" "${GRAFANA_DB_PASSWORD:-changeme_grafana}"

echo "[OK] PostgreSQL tenant bootstrap complete (idempotent)"
