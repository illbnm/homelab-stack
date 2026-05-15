#!/bin/bash
# =============================================================================
# HomeLab PostgreSQL Init Script (Idempotent)
# Runs on first container start. Creates per-service databases and users.
# Safe to re-run: skips already-existing users/databases.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  -- Nextcloud
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nextcloud') THEN
      CREATE USER nextcloud WITH PASSWORD '${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}';
    END IF;
  END
  \$\$;
  SELECT pg_catalog.pg_database.datname FROM pg_catalog.pg_database WHERE datname = 'nextcloud'
  \gset
  \if :{?datname}
  \else
    CREATE DATABASE nextcloud OWNER nextcloud ENCODING 'UTF8';
  \endif
  GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;

  -- Gitea
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea') THEN
      CREATE USER gitea WITH PASSWORD '${GITEA_DB_PASSWORD:-changeme_gitea}';
    END IF;
  END
  \$\$;
  SELECT pg_catalog.pg_database.datname FROM pg_catalog.pg_database WHERE datname = 'gitea'
  \gset
  \if :{?datname}
  \else
    CREATE DATABASE gitea OWNER gitea ENCODING 'UTF8';
  \endif
  GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

  -- Outline
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'outline') THEN
      CREATE USER outline WITH PASSWORD '${OUTLINE_DB_PASSWORD:-changeme_outline}';
    END IF;
  END
  \$\$;
  SELECT pg_catalog.pg_database.datname FROM pg_catalog.pg_database WHERE datname = 'outline'
  \gset
  \if :{?datname}
  \else
    CREATE DATABASE outline OWNER outline ENCODING 'UTF8';
  \endif
  GRANT ALL PRIVILEGES ON DATABASE outline TO outline;
  \connect outline
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  \connect postgres

  -- Vaultwarden
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden') THEN
      CREATE USER vaultwarden WITH PASSWORD '${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}';
    END IF;
  END
  \$\$;
  SELECT pg_catalog.pg_database.datname FROM pg_catalog.pg_database WHERE datname = 'vaultwarden'
  \gset
  \if :{?datname}
  \else
    CREATE DATABASE vaultwarden OWNER vaultwarden ENCODING 'UTF8';
  \endif
  GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;

  -- BookStack
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'bookstack') THEN
      CREATE USER bookstack WITH PASSWORD '${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}';
    END IF;
  END
  \$\$;
  SELECT pg_catalog.pg_database.datname FROM pg_catalog.pg_database WHERE datname = 'bookstack'
  \gset
  \if :{?datname}
  \else
    CREATE DATABASE bookstack OWNER bookstack ENCODING 'UTF8';
  \endif
  GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;
EOSQL

echo "[init-postgres] All databases created successfully (idempotent)"
