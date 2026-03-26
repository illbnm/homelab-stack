-- HomeLab MariaDB init
-- Creates databases for services that prefer MySQL/MariaDB
-- Note: The 'mariadb' application user is created automatically by MariaDB image.
-- This script creates additional per-service databases.

CREATE DATABASE IF NOT EXISTS `nextcloud_mysql` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD:-changeme}';
GRANT ALL PRIVILEGES ON `nextcloud_mysql`.* TO 'nextcloud'@'%';

FLUSH PRIVILEGES;
