#!/bin/bash
#
# init-databases.sh - Initialize databases for homelab services
# This script is idempotent - safe to run multiple times
#

set -e

PSQL="psql -v ON_ERROR_STOP=1 -U postgres"

echo "=== Database Initialization ==="

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until $PSQL -c '\q' 2>/dev/null; do
    sleep 1
done
echo "PostgreSQL is ready!"

# Create databases and users (idempotent)
# Format: create_db "dbname" "password"

create_db() {
    local db_name="$1"
    local db_password="$2"
    
    echo "Creating database: $db_name"
    
    # Create user if not exists
    $PSQL -c "DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db_name') THEN
            CREATE USER $db_name WITH PASSWORD '$db_password';
        END IF;
    END
    \$\$;" || true
    
    # Create database if not exists
    $PSQL -c "SELECT 'CREATE DATABASE $db_name' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db_name')\gexec" || true
    
    # Grant privileges
    $PSQL -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_name;" || true
    $PSQL -c "ALTER DATABASE $db_name OWNER TO $db_name;" || true
    
    # Connect and grant schema privileges
    $PSQL -d "$db_name" -c "GRANT ALL ON SCHEMA public TO $db_name;" || true
    
    echo "✓ Database $db_name created/verified"
}

# Create databases from environment variables
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud_pass}"
create_db "gitea" "${GITEA_DB_PASSWORD:-gitea_pass}"
create_db "outline" "${OUTLINE_DB_PASSWORD:-outline_pass}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik_pass}"
create_db "grafana" "${GRAFANA_DB_PASSWORD:-grafana_pass}"

echo ""
echo "=== PostgreSQL Initialization Complete ==="
echo ""
echo "Database connection strings:"
echo "  Host: postgres (from internal network)"
echo "  Port: 5432"
echo ""
echo "To connect from other stacks, use:"
echo "  postgresql://nextcloud:<password>@postgres:5432/nextcloud"
echo "  postgresql://gitea:<password>@postgres:5432/gitea"
echo "  postgresql://outline:<password>@postgres:5432/outline"
echo "  postgresql://authentik:<password>@postgres:5432/authentik"
echo "  postgresql://grafana:<password>@postgres:5432/grafana"
