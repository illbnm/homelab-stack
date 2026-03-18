#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script (Idempotent)
# Runs on first container start. Creates per-service databases and users.
# Safe to run multiple times - checks for existence before creating.
# =============================================================================
set -euo pipefail

# Helper function to create user if not exists
create_user_if_not_exists() {
  local user=$1
  local password=$2
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${user}') THEN
        CREATE USER ${user} WITH PASSWORD '${password}';
        RAISE NOTICE 'Created user: ${user}';
      ELSE
        RAISE NOTICE 'User already exists: ${user}';
      END IF;
    END
    \$\$;
EOSQL
}

# Helper function to create database if not exists
create_database_if_not_exists() {
  local db=$1
  local owner=$2
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE ${db} OWNER ${owner} ENCODING ''UTF8'''
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
    
    GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${owner};
EOSQL
}

echo "[init-postgres] Starting idempotent database initialization..."

# Nextcloud
create_user_if_not_exists 'nextcloud' '${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}'
create_database_if_not_exists 'nextcloud' 'nextcloud'

# Gitea
create_user_if_not_exists 'gitea' '${GITEA_DB_PASSWORD:-changeme_gitea}'
create_database_if_not_exists 'gitea' 'gitea'

# Outline
create_user_if_not_exists 'outline' '${OUTLINE_DB_PASSWORD:-changeme_outline}'
create_database_if_not_exists 'outline' 'outline'
# Outline requires uuid-ossp extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" <<-EOSQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL

# Authentik
create_user_if_not_exists 'authentik' '${AUTHENTIK_DB_PASSWORD:-changeme_authentik}'
create_database_if_not_exists 'authentik' 'authentik'

# Grafana
create_user_if_not_exists 'grafana' '${GRAFANA_DB_PASSWORD:-changeme_grafana}'
create_database_if_not_exists 'grafana' 'grafana'

# Vaultwarden (uses SQLite by default, PostgreSQL optional)
create_user_if_not_exists 'vaultwarden' '${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}'
create_database_if_not_exists 'vaultwarden' 'vaultwarden'

# BookStack
create_user_if_not_exists 'bookstack' '${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}'
create_database_if_not_exists 'bookstack' 'bookstack'

echo "[init-postgres] All databases initialized successfully (idempotent)"
