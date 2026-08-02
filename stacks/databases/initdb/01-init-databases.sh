#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# =============================================================================
set -euo pipefail

create_db() {
    local db_name=$1
    local db_pass=$2
    
    echo "[init-postgres] Initializing database and user: $db_name"

    # Create user if not exists
    local user_exists
    user_exists=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db_name'")
    if [ "$user_exists" != "1" ]; then
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE USER $db_name WITH PASSWORD '$db_pass';"
    fi
    
    # Create database if not exists
    local db_exists
    db_exists=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'")
    if [ "$db_exists" != "1" ]; then
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE DATABASE $db_name OWNER $db_name ENCODING 'UTF8';"
    fi
    
    # Grant privileges
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_name;"
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea"     "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline"   "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD:-changeme_grafana}"

# Outline requires uuid-ossp extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outline" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

echo "[init-postgres] All databases created successfully (Idempotent run complete)"
