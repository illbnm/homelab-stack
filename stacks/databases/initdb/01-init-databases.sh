#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  -- Nextcloud
  CREATE USER nextcloud WITH PASSWORD '${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}';
  CREATE DATABASE nextcloud OWNER nextcloud ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;

  -- Gitea
  CREATE USER gitea WITH PASSWORD '${GITEA_DB_PASSWORD:-changeme_gitea}';
  CREATE DATABASE gitea OWNER gitea ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

  -- Outline
  CREATE USER outline WITH PASSWORD '${OUTLINE_DB_PASSWORD:-changeme_outline}';
  CREATE DATABASE outline OWNER outline ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE outline TO outline;
  -- Outline requires uuid-ossp extension
  \connect outline
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  \connect postgres

  -- Vaultwarden (uses SQLite by default, PostgreSQL optional)
  CREATE USER vaultwarden WITH PASSWORD '${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}';
  CREATE DATABASE vaultwarden OWNER vaultwarden ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;


EOSQL

echo "[init-postgres] All databases created successfully"
