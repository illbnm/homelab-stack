-- =============================================================================
-- HomeLab MariaDB Init Script (Idempotent)
-- Runs on first container start via /docker-entrypoint-initdb.d/.
-- Safe to re-run: uses IF NOT EXISTS throughout.
--
-- Creates databases for services that prefer MySQL/MariaDB:
--   - BookStack (primary), Nextcloud (alternative to PostgreSQL)
-- =============================================================================

-- BookStack (primary MySQL consumer)
CREATE DATABASE IF NOT EXISTS `bookstack`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'bookstack'@'%'
  IDENTIFIED BY '${BOOKSTACK_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `bookstack`.* TO 'bookstack'@'%';

-- Nextcloud (alternative to PostgreSQL — use one or the other)
CREATE DATABASE IF NOT EXISTS `nextcloud`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'%'
  IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `nextcloud`.* TO 'nextcloud'@'%';

FLUSH PRIVILEGES;
