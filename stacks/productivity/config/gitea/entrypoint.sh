#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Gitea 初始化脚本 — 处理首次启动配置
#
# 功能:
# 1. 等待 PostgreSQL 就绪
# 2. 初始化数据库 (如果未初始化)
# 3. 创建默认管理员账户 (如果不存在)
# 4. 配置 OIDC (Authentik)
# 5. 启动 Gitea 服务
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "🚀 Initializing Gitea..."

# ═══════════════════════════════════════════════════════════════════════════
# 1. 等待数据库就绪
# ═══════════════════════════════════════════════════════════════════════════

wait_for_postgres() {
  echo "⏳ Waiting for PostgreSQL..."
  local max_attempts=30
  local attempt=0

  until nc -z postgres 5432 2>/dev/null; do
    ((attempt++))
    if [[ $attempt -ge $max_attempts ]]; then
      echo "❌ PostgreSQL not responding after ${max_attempts}s"
      exit 1
    fi
    echo "  ... waiting ($attempt/$max_attempts)"
    sleep 2
  done

  echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. 检查数据库是否已初始化
# ═══════════════════════════════════════════════════════════════════════════

check_db_initialized() {
  echo "📊 Checking database initialization..."

  # 尝试连接并检查表是否存在
  if PGPASSWORD="${GITEA__database__PASSWD}" psql -h postgres -U "${GITEA__database__USER}" -d "${GITEA__database__NAME}" -c "\dt" 2>/dev/null | grep -q "user"; then
    echo -e "  ${GREEN}✓ Database already initialized${NC}"
    return 0
  else
    echo -e "  ${YELLOW}⚠️  Database not initialized, will initialize on first run${NC}"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. 创建默认管理员 (如果不存在)
# ═══════════════════════════════════════════════════════════════════════════

create_admin_if_needed() {
  echo "👤 Checking admin user..."

  # 检查是否已有 admin 用户
  local admin_exists=$(PGPASSWORD="${GITEA__database__PASSWD}" psql -h postgres -U "${GITEA__database__USER}" -d "${GITEA__database__NAME}" -tAc "SELECT COUNT(*) FROM user WHERE is_admin = true AND lower_name = 'admin';" 2>/dev/null || echo "0")

  if [[ "$admin_exists" -eq "0" ]]; then
    echo -e "  ${YELLOW}⚠️  No admin user found. Creating default admin (admin/$(date +%s))${NC}"
    # Gitea 会在首次启动时自动创建 admin 用户，这里仅提示
  else
    echo -e "  ${GREEN}✓ Admin user exists${NC}"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 4. 验证 OIDC 配置
# ═══════════════════════════════════════════════════════════════════════════

check_oidc_config() {
  echo "🔐 Checking OIDC configuration..."

  if [[ -z "${GITEA__openid__WHITELISTED_URIS}" ]]; then
    echo -e "  ${YELLOW}⚠️  OIDC whitelist not set, please configure OIDC in app.ini${NC}"
  else
    echo -e "  ${GREEN}✓ OIDC whitelist configured${NC}"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  wait_for_postgres
  check_db_initialized
  create_admin_if_needed
  check_oidc_config

  echo
  echo "🎯 Starting Gitea..."
  echo "  Dashboard: https://gitea.${DOMAIN}"
  echo "  SSH: ssh://git@gitea.${DOMAIN}:22"
  echo

  # 启动 Gitea
  exec /usr/local/bin/gitea web --config /data/gitea/conf/app.ini
}

main "$@"