-- SPDX-License-Identifier: MIT
-- Create databases for productivity stack services

-- Create Gitea database and user
CREATE DATABASE IF NOT EXISTS gitea;
CREATE USER IF NOT EXISTS 'gitea'@'%' IDENTIFIED BY 'gitea_password';
GRANT ALL PRIVILEGES ON gitea.* TO 'gitea'@'%';

-- Create Vaultwarden database and user
CREATE DATABASE IF NOT EXISTS vaultwarden;
CREATE USER IF NOT EXISTS 'vaultwarden'@'%' IDENTIFIED BY 'vaultwarden_password';
GRANT ALL PRIVILEGES ON vaultwarden.* TO 'vaultwarden'@'%';

-- Create Outline database and user
CREATE DATABASE IF NOT EXISTS outline;
CREATE USER IF NOT EXISTS 'outline'@'%' IDENTIFIED BY 'outline_password';
GRANT ALL PRIVILEGES ON outline.* TO 'outline'@'%';

FLUSH PRIVILEGES;
