#!/bin/bash

set -e

create_db() {
    local db_name=$1
    local db_password=$2

    PGPASSWORD=$POSTGRES_ROOT_PASSWORD psql -h postgres -U postgres -c "CREATE DATABASE $db_name;" || true
    PGPASSWORD=$POSTGRES_ROOT_PASSWORD psql -h postgres -U postgres -c "CREATE USER $db_name WITH ENCRYPTED PASSWORD '$db_password';" || true
    PGPASSWORD=$POSTGRES_ROOT_PASSWORD psql -h postgres -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_name;" || true
}

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea"     "${GITEA_DB_PASSWORD}"
create_db "outline"   "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD}"

echo "Databases and users created successfully."

exit 0