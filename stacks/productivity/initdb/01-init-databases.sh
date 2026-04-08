#!/bin/bash
# PostgreSQL Multi-Database Initialization Script
# Creates multiple databases and users for productivity stack

set -e

# Function to create database and user
create_db_and_user() {
    local db_name=$1
    local db_user=$2
    local db_password=$3
    
    echo "Creating database: $db_name"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE USER $db_user WITH PASSWORD '$db_password';
        CREATE DATABASE $db_name OWNER $db_user;
        GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
        \c $db_name;
        GRANT ALL ON SCHEMA public TO $db_user;
EOSQL
    echo "Database $db_name created successfully"
}

# Create Gitea database
if [ -n "$GITEA_DB_PASSWORD" ]; then
    create_db_and_user "gitea" "gitea" "$GITEA_DB_PASSWORD"
fi

# Create Outline database
if [ -n "$OUTLINE_DB_PASSWORD" ]; then
    create_db_and_user "outline" "outline" "$OUTLINE_DB_PASSWORD"
fi

echo "All databases initialized successfully"
