#!/bin/bash
# ============================================================
#  Homelab Stack — 数据库层健康检查脚本
#  验证三个数据库服务是否正常运行
# ============================================================

set -e

source .env 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Homelab DB Layer — Health Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# PostgreSQL 检查
echo -n "PostgreSQL ... "
if docker exec homelab-postgres pg_isready -U ${PG_USER:-homelab} >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    FAIL=1
fi

# Redis 检查
echo -n "Redis ........ "
if docker exec homelab-redis redis-cli --raw incr ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    FAIL=1
fi

# MariaDB 检查
echo -n "MariaDB ...... "
if docker exec homelab-mariadb mysqladmin ping -u root -p${MARIADB_ROOT_PASSWORD} >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    FAIL=1
fi

echo "=========================================="

if [ -n "$FAIL" ]; then
    echo -e "${RED}❌ 部分服务异常，请检查日志${NC}"
    exit 1
else
    echo -e "${GREEN}✅ 所有数据库服务运行正常${NC}"
    exit 0
fi
