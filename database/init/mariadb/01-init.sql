-- Homelab Stack — MariaDB 初始化脚本
-- 在数据库首次启动时自动执行

CREATE DATABASE IF NOT EXISTS homelab CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
