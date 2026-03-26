#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
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

  -- Authentik
  CREATE USER authentik WITH PASSWORD '${AUTHENTIK_DB_PASSWORD:-changeme_authentik}';
  CREATE DATABASE authentik OWNER authentik ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

  -- BookStack
  CREATE USER bookstack WITH PASSWORD '${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}';
  CREATE DATABASE bookstack OWNER bookstack ENCODING 'UTF8';
  GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;
EOSQL

echo "[init-postgres] All databases created successfully"
