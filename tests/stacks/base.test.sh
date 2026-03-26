#!/usr/bin/env bash
# base.test.sh — 基础设施 stack 测试
# Level 1: 容器运行 + healthcheck
# Level 2: HTTP 端点

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
ASSERT_TEST_NAME="Traefik running"; assert_container_running "traefik"
ASSERT_TEST_NAME="Traefik healthy"; assert_container_healthy "traefik" 30 || true
ASSERT_TEST_NAME="Portainer running"; assert_container_running "portainer"
# 注意：portainer 可能没有 healthcheck，手动检查端口
ASSERT_TEST_NAME="Watchtower running"; assert_container_running "watchtower"

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Traefik API version"; assert_http_status "http://localhost:8080/api/version" "200" 10 || true
ASSERT_TEST_NAME="Portainer API status"; assert_http_status "http://localhost:9000/api/status" "200" 10 || true
