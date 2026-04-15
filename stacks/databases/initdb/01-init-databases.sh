#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script
# Runs on first container start. Creates per-service databases and users.
# Idempotent: safe to run multiple times.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  -- Nextcloud
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nextcloud') THEN
      CREATE USER nextcloud WITH PASSWORD '${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nextcloud') THEN
      CREATE DATABASE nextcloud OWNER nextcloud ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;

  -- Gitea
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea') THEN
      CREATE USER gitea WITH PASSWORD '${GITEA_DB_PASSWORD:-changeme_gitea}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea') THEN
      CREATE DATABASE gitea OWNER gitea ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

  -- Outline
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'outline') THEN
      CREATE USER outline WITH PASSWORD '${OUTLINE_DB_PASSWORD:-changeme_outline}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'outline') THEN
      CREATE DATABASE outline OWNER outline ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE outline TO outline;
  \connect outline
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  \connect postgres

  -- Vaultwarden
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden') THEN
      CREATE USER vaultwarden WITH PASSWORD '${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vaultwarden') THEN
      CREATE DATABASE vaultwarden OWNER vaultwarden ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;

  -- BookStack
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bookstack') THEN
      CREATE USER bookstack WITH PASSWORD '${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bookstack') THEN
      CREATE DATABASE bookstack OWNER bookstack ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;

  -- Authentik
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authentik') THEN
      CREATE USER authentik WITH PASSWORD '${AUTHENTIK_DB_PASSWORD:-changeme_authentik}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'authentik') THEN
      CREATE DATABASE authentik OWNER authentik ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

  -- Grafana
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'grafana') THEN
      CREATE USER grafana WITH PASSWORD '${GRAFANA_DB_PASSWORD:-changeme_grafana}';
    END IF;
  END \$\$;
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'grafana') THEN
      CREATE DATABASE grafana OWNER grafana ENCODING 'UTF8';
    END IF;
  END \$\$;
  GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
EOSQL

echo "[init-postgres] All 7 databases created successfully (idempotent)"
