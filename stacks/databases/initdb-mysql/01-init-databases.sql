-- =============================================================================
-- HomeLab MariaDB Init Script (Idempotent)
-- Creates databases for services that prefer MySQL/MariaDB
-- Safe to run multiple times - uses IF NOT EXISTS
-- =============================================================================

-- BookStack database
CREATE DATABASE IF NOT EXISTS `bookstack` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'bookstack'@'%' IDENTIFIED BY '${BOOKSTACK_DB_PASSWORD:-changeme}';
GRANT ALL PRIVILEGES ON `bookstack`.* TO 'bookstack'@'%';

-- Nextcloud MySQL database
CREATE DATABASE IF NOT EXISTS `nextcloud_mysql` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD:-changeme}';
GRANT ALL PRIVILEGES ON `nextcloud_mysql`.* TO 'nextcloud'@'%';

-- Apply changes
FLUSH PRIVILEGES;

-- Show created databases
SELECT 'Databases initialized successfully' AS status;