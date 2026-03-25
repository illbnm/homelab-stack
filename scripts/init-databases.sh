#!/bin/bash
set -e

# Wait for postgres to be ready if running externally, but when mounted in docker-entrypoint-initdb.d, 
# it runs during startup when postgres is already accepting local connections.

create_db() {
    local db_name=$1
    local db_pass=$2

    if [ -z "$db_name" ] || [ -z "$db_pass" ]; then
        echo "Usage: create_db <dbname> <password>"
        return 1
    fi

    echo "Creating database '$db_name' and user..."
    
    # Check if user exists
    user_exists=$(psql -v ON_ERROR_STOP=1 --username "postgres" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db_name'")
    if [ "$user_exists" != "1" ]; then
        psql -v ON_ERROR_STOP=1 --username "postgres" <<-EOSQL
            CREATE USER $db_name WITH PASSWORD '$db_pass';
EOSQL
        echo "User '$db_name' created."
    else
        echo "User '$db_name' already exists."
    fi

    # Check if database exists
    db_exists=$(psql -v ON_ERROR_STOP=1 --username "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'")
    if [ "$db_exists" != "1" ]; then
        psql -v ON_ERROR_STOP=1 --username "postgres" <<-EOSQL
            CREATE DATABASE $db_name;
            GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_name;
EOSQL
        # Alter owner
        psql -v ON_ERROR_STOP=1 --username "postgres" -c "ALTER DATABASE $db_name OWNER TO $db_name;"
        echo "Database '$db_name' created and privileges granted."
    else
        echo "Database '$db_name' already exists."
    fi
}

echo "Initializing multitenant databases..."

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea"     "${GITEA_DB_PASSWORD}"
create_db "outline"   "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD}"

echo "Database initialization complete."
