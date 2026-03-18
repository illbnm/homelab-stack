#!/bin/bash
# =============================================================================
# HomeLab MariaDB Init Script (Idempotent)
# Runs on first container start via /docker-entrypoint-initdb.d/
# Safe to re-run: uses IF NOT EXISTS throughout.
#
# Creates databases for services that prefer MySQL/MariaDB:
#   - BookStack (primary MySQL consumer)
#   - Nextcloud (alternative to PostgreSQL — use one or the other, not both)
#
# NOTE: This must be a .sh file (not .sql) so environment variables
#       like BOOKSTACK_DB_PASSWORD are expanded by the shell.
# =============================================================================
set -euo pipefail

mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
  -- BookStack (primary MySQL consumer)
  CREATE DATABASE IF NOT EXISTS \`bookstack\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS 'bookstack'@'%'
    IDENTIFIED BY '${BOOKSTACK_DB_PASSWORD:?BOOKSTACK_DB_PASSWORD is required}';
  GRANT ALL PRIVILEGES ON \`bookstack\`.* TO 'bookstack'@'%';

  -- Nextcloud (alternative to PostgreSQL)
  CREATE DATABASE IF NOT EXISTS \`nextcloud\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS 'nextcloud'@'%'
    IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD:?NEXTCLOUD_DB_PASSWORD is required}';
  GRANT ALL PRIVILEGES ON \`nextcloud\`.* TO 'nextcloud'@'%';

  FLUSH PRIVILEGES;
EOSQL

echo "[init-mariadb] All databases initialized successfully"
