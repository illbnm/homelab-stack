#!/usr/bin/env bash
# databases.test.sh — 数据库栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
ASSERT_TEST_NAME="PostgreSQL running"; assert_container_running "homelab-postgres"
ASSERT_TEST_NAME="PostgreSQL healthy"; assert_container_healthy "homelab-postgres" 30 || true
ASSERT_TEST_NAME="Redis running"; assert_container_running "homelab-redis"

# ─── Level 2: 端口检测 ────────────────────────────────────────
# PostgreSQL
ASSERT_TEST_NAME="PostgreSQL port 5432 accessible"
if docker exec homelab-postgres pg_isready -U postgres &>/dev/null; then
    ((PASS_COUNT++)); echo -e "[databases] ▶ PostgreSQL port 5432 accessible ${GREEN}✅ PASS${NC}"
else
    ((FAIL_COUNT++)); echo -e "[databases] ▶ PostgreSQL port 5432 accessible ${RED}❌ FAIL${NC}"
fi

# Redis
ASSERT_TEST_NAME="Redis port 6379 accessible"
if docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-password}" ping &>/dev/null; then
    ((PASS_COUNT++)); echo -e "[databases] ▶ Redis port 6379 accessible ${GREEN}✅ PASS${NC}"
else
    ((FAIL_COUNT++)); echo -e "[databases] ▶ Redis port 6379 accessible ${RED}❌ FAIL${NC}"
fi
