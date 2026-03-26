#!/usr/bin/env bash
# storage.test.sh — 存储栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
for container in nextcloud minio; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        ASSERT_TEST_NAME="$container running"; assert_container_running "$container"
        ASSERT_TEST_NAME="$container healthy"; assert_container_healthy "$container" 60 || true
    fi
done

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Nextcloud status.php"; assert_http_status "http://localhost:80/status.php" "200" 20 || true
# Nextcloud 应返回 installed: true
local nc_response
nc_response=$(curl -sf "http://localhost:80/status.php" 2>/dev/null || echo "{}")
ASSERT_TEST_NAME="Nextcloud installed=true"; assert_json_value "$nc_response" ".installed" "true" || true
