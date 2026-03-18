#!/bin/bash

set -e

# Database configuration
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_ADMIN_USER="${POSTGRES_ADMIN_USER:-postgres}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD:-}"

# Application databases and users
DATABASES=(
    "bounty_db:bounty_user"
    "issues_db:issues_user"
    "analytics_db:analytics_user"
    "notifications_db:notifications_user"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

check_postgres_connection() {
    log "Checking PostgreSQL connection..."
    
    if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
        PGPASSWORD="" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -c "SELECT version();" > /dev/null 2>&1
    else
        PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -c "SELECT version();" > /dev/null 2>&1
    fi
    
    if [ $? -ne 0 ]; then
        error "Cannot connect to PostgreSQL server at $POSTGRES_HOST:$POSTGRES_PORT"
    fi
    
    log "PostgreSQL connection successful"
}

database_exists() {
    local db_name=$1
    
    if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
        PGPASSWORD="" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name';" 2>/dev/null | grep -q 1
    else
        PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name';" 2>/dev/null | grep -q 1
    fi
}

user_exists() {
    local user_name=$1
    
    if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
        PGPASSWORD="" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_user WHERE usename='$user_name';" 2>/dev/null | grep -q 1
    else
        PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_user WHERE usename='$user_name';" 2>/dev/null | grep -q 1
    fi
}

execute_sql() {
    local sql_command=$1
    
    if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
        PGPASSWORD="" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -c "$sql_command"
    else
        PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -c "$sql_command"
    fi
}

create_user() {
    local user_name=$1
    local user_password=$2
    
    if user_exists "$user_name"; then
        warn "User '$user_name' already exists, skipping creation"
        return 0
    fi
    
    log "Creating user: $user_name"
    
    local sql="CREATE USER $user_name WITH PASSWORD '$user_password';"
    execute_sql "$sql"
    
    if [ $? -eq 0 ]; then
        log "User '$user_name' created successfully"
    else
        error "Failed to create user '$user_name'"
    fi
}

create_database() {
    local db_name=$1
    local db_owner=$2
    
    if database_exists "$db_name"; then
        warn "Database '$db_name' already exists, skipping creation"
        return 0
    fi
    
    log "Creating database: $db_name"
    
    local sql="CREATE DATABASE $db_name WITH OWNER = $db_owner ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8' TABLESPACE = pg_default CONNECTION LIMIT = -1;"
    execute_sql "$sql"
    
    if [ $? -eq 0 ]; then
        log "Database '$db_name' created successfully"
    else
        error "Failed to create database '$db_name'"
    fi
}

grant_privileges() {
    local db_name=$1
    local user_name=$2
    
    log "Granting privileges to user '$user_name' on database '$db_name'"
    
    local sql="GRANT ALL PRIVILEGES ON DATABASE $db_name TO $user_name;"
    execute_sql "$sql"
    
    if [ $? -eq 0 ]; then
        log "Privileges granted successfully"
    else
        error "Failed to grant privileges to user '$user_name' on database '$db_name'"
    fi
}

create_extensions() {
    local db_name=$1
    
    log "Creating extensions for database: $db_name"
    
    local extensions=("uuid-ossp" "pgcrypto" "pg_stat_statements")
    
    for ext in "${extensions[@]}"; do
        local sql="CREATE EXTENSION IF NOT EXISTS \"$ext\";"
        
        if [ -z "$POSTGRES_ADMIN_PASSWORD" ]; then
            PGPASSWORD="" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d "$db_name" -c "$sql" 2>/dev/null
        else
            PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d "$db_name" -c "$sql" 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            log "Extension '$ext' created/verified for database '$db_name'"
        else
            warn "Failed to create extension '$ext' for database '$db_name' (may not be available)"
        fi
    done
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

main() {
    log "Starting database initialization script"
    
    # Check PostgreSQL connection
    check_postgres_connection
    
    # Process each database configuration
    for db_config in "${DATABASES[@]}"; do
        IFS=':' read -r db_name user_name <<< "$db_config"
        
        log "Processing configuration: $db_name -> $user_name"
        
        # Generate password for user
        user_password=$(generate_password)
        
        # Create user
        create_user "$user_name" "$user_password"
        
        # Create database
        create_database "$db_name" "$user_name"
        
        # Grant privileges
        grant_privileges "$db_name" "$user_name"
        
        # Create extensions
        create_extensions "$db_name"
        
        # Output connection details
        log "Database setup complete for $db_name"
        log "Connection details:"
        log "  Host: $POSTGRES_HOST"
        log "  Port: $POSTGRES_PORT"
        log "  Database: $db_name"
        log "  Username: $user_name"
        log "  Password: $user_password"
        log "  Connection URL: postgresql://$user_name:$user_password@$POSTGRES_HOST:$POSTGRES_PORT/$db_name"
        echo ""
    done
    
    log "All databases initialized successfully!"
    log "Remember to securely store the generated passwords and update your application configuration."
}

# Check for required tools
command -v psql >/dev/null 2>&1 || error "psql is not installed or not in PATH"
command -v openssl >/dev/null 2>&1 || error "openssl is not installed or not in PATH"

# Run main function
main "$@"