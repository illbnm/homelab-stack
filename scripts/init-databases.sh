#!/bin/bash
set -e

echo "Running init-databases.sh script..."

# Function to create a PostgreSQL database and user if they don't exist
create_db() {
    local DB_NAME=$1
    local DB_USER=$1 # User name is same as DB name for simplicity
    local DB_PASSWORD=$2

    echo "Checking for database '$DB_NAME' and user '$DB_USER'..."

    # Check if database exists
    if ! psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
        echo "Database '$DB_NAME' does not exist. Creating..."
        psql -U postgres -c "CREATE DATABASE $DB_NAME;"
        echo "Database '$DB_NAME' created."
    else
        echo "Database '$DB_NAME' already exists."
    fi

    # Check if user exists
    if ! psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'" | grep -q 1; then
        echo "User '$DB_USER' does not exist. Creating..."
        psql -U postgres -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
        echo "User '$DB_USER' created."
    else
        echo "User '$DB_USER' already exists."
    fi

    # Grant privileges to the user on the database
    # This is idempotent as granting existing privileges doesn't error.
    echo "Granting privileges for user '$DB_USER' on database '$DB_NAME'..."
    psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    echo "Privileges granted."
}

# Wait for PostgreSQL to be ready
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done
echo "PostgreSQL is ready."

# Load environment variables from the .env file if not already set
# This is crucial for the script to pick up passwords when run manually or via docker-compose exec
if [ -f /run/secrets/.env ]; then # Check for secrets mounted by Docker Compose
    echo "Loading environment variables from /run/secrets/.env"
    export $(grep -v '^#' /run/secrets/.env | xargs -d '\n')
elif [ -f ./.env ]; then # Fallback for local testing if .env is in current dir
    echo "Loading environment variables from ./.env"
    export $(grep -v '^#' ./.env | xargs -d '\n')
fi

# Ensure all required environment variables are set
if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then echo "NEXTCLOUD_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${GITEA_DB_PASSWORD}" ]; then echo "GITEA_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${OUTLINE_DB_PASSWORD}" ]; then echo "OUTLINE_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${AUTHENTIK_DB_PASSWORD}" ]; then echo "AUTHENTIK_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${GRAFANA_DB_PASSWORD}" ]; then echo "GRAFANA_DB_PASSWORD not set!"; exit 1; fi

# Create databases and users for each service
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea" "${GITEA_DB_PASSWORD}"
create_db "outline" "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana" "${GRAFANA_DB_PASSWORD}"

echo "All specified PostgreSQL databases and users are configured."
