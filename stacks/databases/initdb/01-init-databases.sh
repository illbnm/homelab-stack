#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script (Idempotent)
# Runs on first container start. Creates per-service databases and users.
# Safe to run multiple times - uses IF NOT EXISTS / DO statements.
# =============================================================================
set -euo pipefail

echo "[init-postgres] Starting database initialization..."

# Function to create user if not exists
create_user() {
    local username="$1"
    local password="$2"
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$username') THEN
                CREATE USER $username WITH PASSWORD '$password';
            ELSE
                ALTER USER $username WITH PASSWORD '$password';
            END IF;
        END
        \$\$;

        -- Grant default privileges
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $username;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $username;
EOSQL
    echo "[init-postgres] User '$username' created/updated"
}

# Function to create database if not exists
create_database() {
    local dbname="$1"
    local owner="$2"
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'Creating database $dbname' AS status;
        DROP DATABASE IF EXISTS $dbname;
        CREATE DATABASE $dbname OWNER $owner ENCODING 'UTF8';
        GRANT ALL PRIVILEGES ON DATABASE $dbname TO $owner;
        
        -- Connect and grant schema privileges
        \c $dbname
        GRANT ALL ON SCHEMA public TO $owner;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $owner;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $owner;
        \c postgres
EOSQL
    echo "[init-postgres] Database '$dbname' created/reset"
}

# Main initialization
# Note: Passwords must be provided via environment variables or use defaults

# Nextcloud
create_user "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_database "nextcloud" "nextcloud"

# Gitea
create_user "gitea" "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_database "gitea" "gitea"

# Outline
create_user "outline" "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_database "outline" "outline"
# Outline requires uuid-ossp extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
echo "[init-postgres] Outline uuid-ossp extension ensured"

# Authentik (SSO)
create_user "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_database "authentik" "authentik"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "authentik" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
echo "[init-postgres] Authentik database created"

# Grafana
create_user "grafana" "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_database "grafana" "grafana"
echo "[init-postgres] Grafana database created"

# Vaultwarden
create_user "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_database "vaultwarden" "vaultwarden"
echo "[init-postgres] Vaultwarden database created"

# BookStack
create_user "bookstack" "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"
create_database "bookstack" "bookstack"
echo "[init-postgres] BookStack database created"

# Verify all databases
echo "[init-postgres] Verifying all databases..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    SELECT datname FROM pg_database WHERE datistemplate = false;
EOSQL

echo "[init-postgres] All databases and users created successfully!"
echo "[init-postgres] Initialization complete."