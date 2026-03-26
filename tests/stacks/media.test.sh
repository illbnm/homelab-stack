#!/usr/bin/env bash
# media.test.sh — 媒体栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
for container in jellyfin prowlarr sonarr radarr bazarr; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        ASSERT_TEST_NAME="$container running"; assert_container_running "$container"
        ASSERT_TEST_NAME="$container healthy"; assert_container_healthy "$container" 60 || true
    fi
done

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Jellyfin health"; assert_http_status "http://localhost:8097/health" "200" 15 || true
ASSERT_TEST_NAME="Prowlarr API"; assert_http_status "http://localhost:9696/api/v3/health" "200" 10 || true
ASSERT_TEST_NAME="Sonarr API"; assert_http_status "http://localhost:8989/api/v3/system/status" "200" 10 || true
ASSERT_TEST_NAME="Radarr API"; assert_http_status "http://localhost:7878/api/v3/system/status" "200" 10 || true
