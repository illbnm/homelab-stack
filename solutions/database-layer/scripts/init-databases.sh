#!/bin/bash
set -e

# Idempotent database and user initialization script
# Safe to run multiple times - will not reset existing data

# Function to create database and user
create_db() {
    local db_name=$1
    local db_password=$2
    
    if [ -z "$db_name" ] || [ -z "$db_password" ]; then
        echo "Warning: Skipping $db_name - missing name or password"
        return 0
    fi
    
    echo "Initializing database: $db_name"
    
    # Check if user exists
    if psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db_name'" | grep -q 1; then
        echo "  User '$db_name' already exists, skipping creation"
    else
        echo "  Creating user '$db_name'"
        psql -U postgres -c "CREATE USER \"$db_name\" WITH PASSWORD '$db_password';"
    fi
    
    # Check if database exists
    if psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo "  Database '$db_name' already exists, skipping creation"
    else
        echo "  Creating database '$db_name'"
        psql -U postgres -c "CREATE DATABASE \"$db_name\" OWNER \"$db_name\";"
    fi
    
    # Grant privileges (idempotent)
    psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$db_name\" TO \"$db_name\";"
    
    echo "  Database '$db_name' ready"
}

echo "=========================================="
echo "Database Initialization Script"
echo "=========================================="
echo ""

# Create databases for each service
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea"     "${GITEA_DB_PASSWORD}"
create_db "outline"   "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD}"

echo ""
echo "=========================================="
echo "Initialization complete!"
echo "=========================================="
echo ""
echo "Connection strings:"
echo "  PostgreSQL: postgresql://<user>:<password>@postgres:5432/<database>"
echo "  Redis:      redis://:${REDIS_PASSWORD}@redis:6379/<db_number>"
echo ""
echo "Redis database allocation:"
echo "  DB 0 — Authentik"
echo "  DB 1 — Outline"
echo "  DB 2 — Gitea"
echo "  DB 3 — Nextcloud"
echo "  DB 4 — Grafana sessions"
echo ""
