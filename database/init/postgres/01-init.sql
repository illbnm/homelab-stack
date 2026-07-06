-- Homelab Stack — PostgreSQL 初始化脚本
-- 在数据库首次启动时自动执行

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- 创建应用表空间
-- (按需启用)
-- CREATE TABLESPACE homelab_ts LOCATION '/var/lib/postgresql/data/homelab_ts';
