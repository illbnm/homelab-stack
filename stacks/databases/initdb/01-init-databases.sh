#!/bin/bash
# HomeLab PostgreSQL Init Script (幂等)
# 在容器首次启动时执行；可安全重复运行，不重置已有数据。
set -euo pipefail

create_db() {
  local db="$1" pwd="${2:-changeme}"

  # 幂等创建角色（PostgreSQL 无 CREATE ROLE IF NOT EXISTS，需先探测）
  if ! psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE ROLE $db LOGIN PASSWORD '$pwd';"
  fi

  # 幂等创建数据库
  if ! psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $db OWNER $db ENCODING 'UTF8';"
  fi

  # 确保 owner 有全部权限（重跑时也同步权限）
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $db TO $db;"
}

# 多租户数据库分配
create_db "nextcloud"  "${NEXTCLOUD_DB_PASSWORD:-changeme_nextcloud}"
create_db "gitea"      "${GITEA_DB_PASSWORD:-changeme_gitea}"
create_db "outline"    "${OUTLINE_DB_PASSWORD:-changeme_outline}"
create_db "authentik"  "${AUTHENTIK_DB_PASSWORD:-changeme_authentik}"
create_db "grafana"    "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_db "vaultwarden" "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_db "bookstack"  "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"

# Outline 需要 uuid-ossp 扩展
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d outline -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

echo "[init-postgres] All databases created successfully (idempotent)"
