#!/usr/bin/env bash
# ai.test.sh — AI 栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
for container in ollama open-webui; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        ASSERT_TEST_NAME="$container running"; assert_container_running "$container"
        ASSERT_TEST_NAME="$container healthy"; assert_container_healthy "$container" 60 || true
    fi
done

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Ollama API version"; assert_http_status "http://localhost:11434/api/version" "200" 15 || true
