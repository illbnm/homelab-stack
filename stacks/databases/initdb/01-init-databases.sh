#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Idempotent — safe to re-run (CREATE USER/DATABASE IF NOT EXISTS)
# Runs on first container start. Creates per-service databases and users.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
-- Nextcloud
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nextcloud') THEN CREATE ROLE nextcloud WITH LOGIN PASSWORD '${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}'; END IF; END $$;
SELECT 'CREATE DATABASE nextcloud OWNER nextcloud ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nextcloud')\gexec
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;

-- Gitea
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gitea') THEN CREATE ROLE gitea WITH LOGIN PASSWORD '${GITEA_DB_PASSWORD:-changeme_gitea}'; END IF; END $$;
SELECT 'CREATE DATABASE gitea OWNER gitea ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea')\gexec
GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

-- Outline
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'outline') THEN CREATE ROLE outline WITH LOGIN PASSWORD '${OUTLINE_DB_PASSWORD:-changeme_outline}'; END IF; END $$;
SELECT 'CREATE DATABASE outline OWNER outline ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'outline')\gexec
GRANT ALL PRIVILEGES ON DATABASE outline TO outline;

-- Vaultwarden
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vaultwarden') THEN CREATE ROLE vaultwarden WITH LOGIN PASSWORD '${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}'; END IF; END $$;
SELECT 'CREATE DATABASE vaultwarden OWNER vaultwarden ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vaultwarden')\gexec
GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;

-- Authentik
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authentik') THEN CREATE ROLE authentik WITH LOGIN PASSWORD '${AUTHENTIK_DB_PASSWORD:-changeme_authentik}'; END IF; END $$;
SELECT 'CREATE DATABASE authentik OWNER authentik ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'authentik')\gexec
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

-- Grafana
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana') THEN CREATE ROLE grafana WITH LOGIN PASSWORD '${GRAFANA_DB_PASSWORD:-changeme_grafana}'; END IF; END $$;
SELECT 'CREATE DATABASE grafana OWNER grafana ENCODING ''UTF8''' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'grafana')\gexec
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;

-- Outline requires uuid-ossp extension
\connect outline
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\connect postgres

echo "[init-postgres] All databases created successfully (idempotent)"
EOSQL
