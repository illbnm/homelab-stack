#!/usr/bin/env bash
# =============================================================================
# init-databases.sh — 多租户 PostgreSQL 初始化脚本
# 为每个服务创建独立 database + user（幂等，重复执行不报错）
#
# 由 docker-entrypoint-initdb.d 自动调用，或手动执行：
#   docker exec postgres bash /docker-entrypoint-initdb.d/init-databases.sh
# =============================================================================

set -euo pipefail

# ── Helper ───────────────────────────────────────────────────────────────────

create_db() {
  local db_name="$1"
  local db_password="$2"

  echo "[init-databases] Creating database and user: ${db_name}"

  # Create user (idempotent)
  psql -v ON_ERROR_STOP=0 -U postgres <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}') THEN
        CREATE ROLE ${db_name} WITH LOGIN PASSWORD '${db_password}';
        RAISE NOTICE 'Created user: ${db_name}';
      ELSE
        ALTER ROLE ${db_name} WITH PASSWORD '${db_password}';
        RAISE NOTICE 'Updated password for existing user: ${db_name}';
      END IF;
    END
    \$\$;
EOSQL

  # Create database (idempotent)
  psql -v ON_ERROR_STOP=0 -U postgres <<-EOSQL
    SELECT 'CREATE DATABASE ${db_name} OWNER ${db_name}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL

  # Ensure ownership
  psql -v ON_ERROR_STOP=0 -U postgres <<-EOSQL
    ALTER DATABASE ${db_name} OWNER TO ${db_name};
    GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_name};
EOSQL

  echo "[init-databases] ✅ ${db_name} ready"
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo "=============================================="
echo "[init-databases] Starting multi-tenant setup"
echo "=============================================="

create_db "nextcloud"  "${NEXTCLOUD_DB_PASSWORD:-changeme}"
create_db "gitea"      "${GITEA_DB_PASSWORD:-changeme}"
create_db "outline"    "${OUTLINE_DB_PASSWORD:-changeme}"
create_db "authentik"  "${AUTHENTIK_DB_PASSWORD:-changeme}"
create_db "grafana"    "${GRAFANA_DB_PASSWORD:-changeme}"

echo "=============================================="
echo "[init-databases] ✅ All databases initialized"
echo "=============================================="
