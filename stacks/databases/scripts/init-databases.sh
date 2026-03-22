#!/bin/bash
# =============================================================================
# init-databases.sh — Idempotent multi-tenant PostgreSQL initializer
# Runs on first container start via docker-entrypoint-initdb.d
# =============================================================================
set -e

create_db() {
  local db=$1
  local user=$2
  local password=$3

  echo "Ensuring database: $db (user: $user)"

  # Create user if not exists
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres << EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$user') THEN
    CREATE ROLE "$user" LOGIN PASSWORD '$password';
    RAISE NOTICE 'Created user: $user';
  ELSE
    RAISE NOTICE 'User already exists: $user';
  END IF;
END
\$\$;
EOF

  # Create database if not exists
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres << EOF
SELECT 'CREATE DATABASE "$db" OWNER "$user"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
GRANT ALL PRIVILEGES ON DATABASE "$db" TO "$user";
EOF
}

# Create all service databases
create_db "nextcloud" "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme}"
create_db "gitea"     "gitea"     "${GITEA_DB_PASSWORD:-changeme}"
create_db "outline"   "outline"   "${OUTLINE_DB_PASSWORD:-changeme}"
create_db "grafana"   "grafana"   "${GRAFANA_DB_PASSWORD:-changeme}"

echo "✅ All databases initialized successfully"
