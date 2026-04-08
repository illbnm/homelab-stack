-- Database Layer 初始化脚本
-- Issue #11 · Bounty $130
-- 为各 stack 预创建数据库

-- Gitea
SELECT 'Creating database: gitea' AS info;
CREATE DATABASE gitea;

-- Outline
SELECT 'Creating database: outline' AS info;
CREATE DATABASE outline;

-- Authentik SSO
SELECT 'Creating database: authentik' AS info;
CREATE DATABASE authentik;

-- Grafana
SELECT 'Creating database: grafana' AS info;
CREATE DATABASE grafana;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE gitea TO homelab;
GRANT ALL PRIVILEGES ON DATABASE outline TO homelab;
GRANT ALL PRIVILEGES ON DATABASE authentik TO homelab;
GRANT ALL PRIVILEGES ON DATABASE grafana TO homelab;
