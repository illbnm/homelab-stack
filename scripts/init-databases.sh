#!/bin/bash
# ==============================================================================
# Idempotent Multi-Tenant PostgreSQL Database Initializer
# Creates isolated databases and users with least-privilege permissions
# ==============================================================================

set -e

function create_db_user() {
  local database=$1
  local password=$2
  
  if [ -z "$password" ]; then
    echo "[!] Warning: No password set for database '$database', generating secure default..."
    password=$(head -c 16 /dev/urandom | xxd -p)
  fi

  echo "[*] Ensuring database and user exist for '$database'..."

  # Create user if it doesn't exist
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO
    \$do\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$database') THEN
        CREATE USER $database WITH ENCRYPTED PASSWORD '$password';
      ELSE
        ALTER USER $database WITH ENCRYPTED PASSWORD '$password';
      END IF;
    END
    \$do\$;
EOSQL

  # Create database if it doesn't exist
  local exists
  exists=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname = '$database'")
  if [ "$exists" != "1" ]; then
    echo "[*] Creating database '$database' owned by '$database'..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
      CREATE DATABASE $database OWNER $database;
EOSQL
  else
    echo "[*] Database '$database' already exists."
  fi

  # Grant all privileges on database and schema
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$database" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
    GRANT ALL ON SCHEMA public TO $database;
    ALTER SCHEMA public OWNER TO $database;
EOSQL

  echo "[+] Database and user '$database' configured successfully."
}

echo "=== Initializing Multi-Tenant PostgreSQL Databases ==="

create_db_user "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-}"
create_db_user "gitea"     "${GITEA_DB_PASSWORD:-}"
create_db_user "outline"   "${OUTLINE_DB_PASSWORD:-}"
create_db_user "authentik" "${AUTHENTIK_DB_PASSWORD:-}"
create_db_user "grafana"   "${GRAFANA_DB_PASSWORD:-}"

echo "=== Database Initialization Complete ==="
