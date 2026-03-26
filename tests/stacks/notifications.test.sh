#!/usr/bin/env bash
# notifications.test.sh — 通知栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
ASSERT_TEST_NAME="ntfy running"; assert_container_running "ntfy"
ASSERT_TEST_NAME="ntfy healthy"; assert_container_healthy "ntfy" 30 || true
ASSERT_TEST_NAME="apprise running"; assert_container_running "apprise" || true

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="ntfy health"; assert_http_status "http://localhost:80/v1/health" "200" 10 || true
