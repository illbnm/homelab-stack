#!/usr/bin/env bash
# productivity.test.sh — 生产力栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
for container in gitea vaultwarden; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        ASSERT_TEST_NAME="$container running"; assert_container_running "$container"
        ASSERT_TEST_NAME="$container healthy"; assert_container_healthy "$container" 60 || true
    fi
done

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Gitea API version"; assert_http_status "http://localhost:3000/api/v1/version" "200" 15 || true
