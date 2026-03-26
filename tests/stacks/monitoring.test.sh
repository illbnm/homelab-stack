#!/usr/bin/env bash
# monitoring.test.sh — 监控栈测试

set -euo pipefail

# ─── Level 1: 容器运行 ───────────────────────────────────────
ASSERT_TEST_NAME="Prometheus running"; assert_container_running "prometheus"
ASSERT_TEST_NAME="Prometheus healthy"; assert_container_healthy "prometheus" 60 || true
ASSERT_TEST_NAME="Grafana running"; assert_container_running "grafana"
ASSERT_TEST_NAME="cAdvisor running"; assert_container_running "cadvisor" || true

# ─── Level 2: HTTP 端点 ──────────────────────────────────────
ASSERT_TEST_NAME="Prometheus healthy endpoint"; assert_http_status "http://localhost:9090/-/healthy" "200" 15 || true
ASSERT_TEST_NAME="Prometheus API version"; assert_http_status "http://localhost:9090/api/v1/status/config" "200" 15 || true
ASSERT_TEST_NAME="Grafana healthy"; assert_http_status "http://localhost:3000/api/health" "200" 15 || true

# ─── Level 3: 服务间互通 ─────────────────────────────────────
# Prometheus 必须能抓取到 cAdvisor 指标
if docker ps --format '{{.Names}}' | grep -q "^cadvisor$"; then
    sleep 5  # 等待 scrape
    ASSERT_TEST_NAME="Prometheus scrapes cAdvisor"
    local result=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null || echo '{"status":"error"}')
    assert_json_key_exists "$result" ".data.result[0]" || true
fi

# Grafana 必须有 Prometheus 数据源
ASSERT_TEST_NAME="Grafana has Prometheus datasource"
local ds_result
ds_result=$(curl -sS -u "admin:${GF_ADMIN_PASSWORD:-admin}" "http://localhost:3000/api/datasources" 2>/dev/null || echo "[]")
assert_json_key_exists "$ds_result" ".[0]" || true
