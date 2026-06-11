#!/bin/bash
set -e
create_db() {
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE USER $1 WITH PASSWORD '$2';
    CREATE DATABASE $1;
    GRANT ALL PRIVILEGES ON DATABASE $1 TO $1;
EOSQL
}
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD:-nextcloud}"
create_db "gitea" "${GITEA_DB_PASSWORD:-gitea}"
create_db "outline" "${OUTLINE_DB_PASSWORD:-outline}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD:-authentik}"
create_db "grafana" "${GRAFANA_DB_PASSWORD:-grafana}"
