#!/bin/bash
# =============================================================================
# MariaDB Multi-tenant Initialization Script
# Creates databases and users for each service
# IDEMPOTENT: Safe to run multiple times
# =============================================================================

set -euo pipefail

echo "=== Initializing MariaDB Databases ==="

# Function to create database and user (idempotent)
create_mysql_db() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"

    if [ -z "$db_password" ]; then
        echo "Skipping $db_name: no password provided"
        return 0
    fi

    echo "Creating database: $db_name"

    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
        -- Create user if not exists
        CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';

        -- Create database if not exists
        CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

        -- Grant privileges
        GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
        FLUSH PRIVILEGES;
EOSQL

    echo "✓ Database $db_name ready"
}

# Create databases for services that prefer MySQL
create_mysql_db "nextcloud" "nextcloud" "${NEXTCLOUD_MYSQL_PASSWORD:-}"
create_mysql_db "bookstack" "bookstack" "${BOOKSTACK_DB_PASSWORD:-}"

echo ""
echo "=== MariaDB Initialization Complete ==="
echo "Databases created:"
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW DATABASES;" | grep -v -E "Database|information_schema|mysql|performance_schema"
