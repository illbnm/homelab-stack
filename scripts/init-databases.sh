#!/usr/bin/env bash
# HomeLab Shared Databases — 幂等初始化脚本
# 可在容器启动后任意时刻重复执行，不会报错、不会重置已有数据。
# 用法: ./scripts/init-databases.sh   (需先 docker compose up -d 启动数据库栈)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_DIR="$ROOT_DIR/stacks/databases"

# 优先从栈目录加载 .env，其次根目录 .env
if [ -f "$COMPOSE_DIR/.env" ]; then
  set -a; . "$COMPOSE_DIR/.env"; set +a
elif [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

CONTAINER="${CONTAINER:-homelab-postgres}"
PG_USER="${POSTGRES_ROOT_USER:-postgres}"

require_env() {
  local var="$1"
  if [ -z "${!var:-}" ] || [ "${!var:-}" = "CHANGE_ME" ]; then
    echo "[init-databases] 缺少必需环境变量: $var (请先在 .env 中设置)" >&2
    exit 1
  fi
}

require_env POSTGRES_ROOT_PASSWORD
require_env NEXTCLOUD_DB_PASSWORD
require_env GITEA_DB_PASSWORD
require_env OUTLINE_DB_PASSWORD
require_env AUTHENTIK_DB_PASSWORD

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "[init-databases] 容器 $CONTAINER 未运行，请先: docker compose -f $COMPOSE_DIR/docker-compose.yml up -d" >&2
  exit 1
fi

# 密码通过 psql 变量安全传入（避免拼接进 SQL 字符串）
create_db() {
  local db="$1" pwd="$2"
  if docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db'" | grep -q 1; then
    echo "[init-databases] role $db 已存在，跳过"
  else
    docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -c "CREATE ROLE $db LOGIN PASSWORD '$pwd';"
    echo "[init-databases] role $db 已创建"
  fi
  if docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1; then
    echo "[init-databases] database $db 已存在，跳过"
  else
    docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -c "CREATE DATABASE $db OWNER $db ENCODING 'UTF8';"
    echo "[init-databases] database $db 已创建"
  fi
  docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $db TO $db;" >/dev/null
}

create_db nextcloud  "$NEXTCLOUD_DB_PASSWORD"
create_db gitea      "$GITEA_DB_PASSWORD"
create_db outline    "$OUTLINE_DB_PASSWORD"
create_db authentik  "$AUTHENTIK_DB_PASSWORD"
create_db grafana    "${GRAFANA_DB_PASSWORD:-changeme_grafana}"
create_db vaultwarden "${VAULTWARDEN_DB_PASSWORD:-changeme_vaultwarden}"
create_db bookstack  "${BOOKSTACK_DB_PASSWORD:-changeme_bookstack}"

# Outline 需要 uuid-ossp
docker exec "$CONTAINER" psql -U "$PG_USER" -d outline -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' >/dev/null 2>&1 || true

echo "[init-databases] OK — 所有数据库/用户已就绪（幂等）"
