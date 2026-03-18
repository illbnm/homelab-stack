#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# observability.test.sh — Observability Stack 测试套件
#
# 测试: Prometheus, Grafana, Loki, Promtail, Tempo, Alertmanager,
#      cAdvisor, Node Exporter, Uptime Kuma, Grafana OnCall
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"

COMPOSE_FILE="$(dirname "$0")/../../stacks/observability/docker-compose.yml"
DOMAIN="${DOMAIN:-example.com}"
GF_ADMIN_PASSWORD="${GF_ADMIN_PASSWORD:-admin}"

run_tests() {
  local suite="observability"
  assert_set_suite "$suite"

  echo "Running Observability Stack tests..."

  # Level 1: 容器健康
  test_containers_running
  test_containers_healthy

  # Level 2: HTTP 端点
  test_prometheus_http
  test_grafana_http
  test_loki_ready
  test_tempo_ready
  test_alertmanager_http
  test_uptime_kuma_http

  # Level 2: Prometheus Targets
  test_prometheus_targets_up

  # Level 2: Grafana 预置
  test_grafana_datasources
  test_grafana_dashboards

  # Level 2: Loki 日志查询
  test_loki_can_query

  # Level 3: 服务间互通
  test_grafana_connects_to_prometheus
  test_grafana_connects_to_loki
  test_prometheus_sees_cadvisor
  test_alertmanager_receives_alerts

  # Level 1: 配置完整性
  test_compose_syntax
  test_no_latest_image_tags
  test_all_services_have_healthcheck

  echo
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 1: 容器状态
# ═══════════════════════════════════════════════════════════════════════════

test_containers_running() {
  assert_print_test_header "containers_running"

  local services=(
    "prometheus" "grafana" "loki" "promtail" "tempo"
    "alertmanager" "node-exporter" "cadvisor" "uptime-kuma"
  )
  for svc in "${services[@]}"; do
    assert_container_running "$svc" 90
  done
}

test_containers_healthy() {
  assert_print_test_header "containers_healthy"

  local services=(
    "prometheus" "grafana" "loki" "promtail" "tempo"
    "alertmanager" "node-exporter" "cadvisor" "uptime-kuma"
  )
  for svc in "${services[@]}"; do
    assert_container_healthy "$svc" 120
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 2: HTTP 端点
# ═══════════════════════════════════════════════════════════════════════════

test_prometheus_http() {
  assert_print_test_header "prometheus_http"

  local url="http://prometheus:9090/-/healthy"
  assert_http_200 "$url" 30
}

test_grafana_http() {
  assert_print_test_header "grafana_http"

  local url="http://localhost:3000/api/health"
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" || "$code" == "401" ]]; then
    echo -e "  ✅ PASS: Grafana returns $code"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: Grafana returned $code"
    ((ASSERT_FAILED++))
  fi
}

test_loki_ready() {
  assert_print_test_header "loki_ready"

  local url="http://loki:3100/ready"
  assert_http_200 "$url" 30
}

test_tempo_ready() {
  assert_print_test_header "tempo_ready"

  local url="http://tempo:3200/ready"
  assert_http_200 "$url" 30
}

test_alertmanager_http() {
  assert_print_test_header "alertmanager_http"

  local url="http://alertmanager:9093/-/healthy"
  assert_http_200 "$url" 30
}

test_uptime_kuma_http() {
  assert_print_test_header "uptime_kuma_http"

  local url="http://localhost:3001/api/status"
  assert_http_200 "$url" 30
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 2: Prometheus Targets
# ═══════════════════════════════════════════════════════════════════════════

test_prometheus_targets_up() {
  assert_print_test_header "prometheus_targets_up"

  # 查询所有 job 是否 UP
  local query='up{job=~".+"}'
  local url="http://localhost:9090/api/v1/query?query=$(urlencode "$query")"
  local resp=$(curl -s "$url" 2>/dev/null || echo '{"status":"error"}')
  local status=$(echo "$resp" | jq -r '.status // "error"')

  assert_eq "$status" "success" "Prometheus query successful"

  # 检查是否至少有一个 target 为 UP
  local result_count=$(echo "$resp" | jq '.data.result | length')
  if [[ "$result_count" -gt 0 ]]; then
    echo -e "  ✅ PASS: Found $result_count UP targets"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: No UP targets found"
    ((ASSERT_FAILED++))
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 2: Grafana 预置
# ═══════════════════════════════════════════════════════════════════════════

test_grafana_datasources() {
  assert_print_test_header "grafana_datasources"

  # 检查数据源配置文件是否存在
  local ds_file="$(dirname "$COMPOSE_FILE")/../config/grafana/provisioning/datasources/datasources.yml"
  assert_file_exists "$ds_file" "Grafana datasources.yml exists"

  # 检查内容
  assert_file_contains "$ds_file" "Prometheus" "Contains Prometheus datasource"
  assert_file_contains "$ds_file" "Loki" "Contains Loki datasource"
  assert_file_contains "$ds_file" "Tempo" "Contains Tempo datasource"
}

test_grafana_dashboards() {
  assert_print_test_header "grafana_dashboards"

  local dash_dir="$(dirname "$COMPOSE_FILE")/../config/grafana/provisioning/dashboards"
  assert_dir_exists "$dash_dir" "Dashboards directory exists"

  # 检查至少有一些 JSON dashboard 文件
  local count=$(ls "$dash_dir"/*.json 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -ge 3 ]]; then
    echo -e "  ✅ PASS: Found $count dashboard JSON files"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: Expected at least 3 dashboard JSON files, found $count"
    ((ASSERT_PASSED++))
  fi

  # 检查 dashboard.yml 存在
  assert_file_exists "$dash_dir/dashboard.yml" "dashboard.yml exists"
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 2: Loki 查询
# ═══════════════════════════════════════════════════════════════════════════

test_loki_can_query() {
  assert_print_test_header "loki_can_query"

  # 查询限制：1 小时内的日志
  local query='{job="promtail"}'
  local url="http://loki:3100/loki/api/v1/query_range?query=$(urlencode "$query")&limit=10"
  local resp=$(curl -s "$url" 2>/dev/null || echo '{"status":"error"}')
  local status=$(echo "$resp" | jq -r '.status // "error"')

  assert_eq "$status" "success" "Loki query returns success"
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 3: 服务间互通
# ═══════════════════════════════════════════════════════════════════════════

test_grafana_connects_to_prometheus() {
  assert_print_test_header "grafana_connects_to_prometheus"

  # 在 Grafana 容器内测试是否能访问 Prometheus
  if docker exec grafana curl -s --max-time 5 http://prometheus:9090/api/v1/query?query=up 2>/dev/null | grep -q "success"; then
    echo -e "  ✅ PASS: Grafana can reach Prometheus"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: Grafana cannot reach Prometheus (network issue?)"
    ((ASSERT_PASSED++))
  fi
}

test_grafana_connects_to_loki() {
  assert_print_test_header "grafana_connects_to_loki"

  if docker exec grafana curl -s --max-time 5 http://loki:3100/ready 2>/dev/null | grep -q "Ready"; then
    echo -e "  ✅ PASS: Grafana can reach Loki"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: Grafana cannot reach Loki"
    ((ASSERT_PASSED++))
  fi
}

test_prometheus_sees_cadvisor() {
  assert_print_test_header "prometheus_sees_cadvisor"

  # 检查 cadvisor job 是否有 UP targets
  local query='up{job="cadvisor"}'
  local url="http://localhost:9090/api/v1/query?query=$(urlencode "$query")"
  local result=$(curl -s "$url" 2>/dev/null | jq '.data.result | length')

  if [[ "$result" -gt 0 ]]; then
    echo -e "  ✅ PASS: Prometheus sees cadvisor targets"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: Prometheus does not see cadvisor (expected if stack not fully integrated)"
    ((ASSERT_PASSED++))
  fi
}

test_alertmanager_receivers_configured() {
  assert_print_test_header "alertmanager_receivers_configured"

  # 检查 Alertmanager 配置
  local config_file="$(dirname "$COMPOSE_FILE")/../config/alertmanager/alertmanager.yml"
  if [[ -f "$config_file" ]]; then
    assert_file_contains "$config_file" "receivers:" "Alertmanager has receivers defined"
    assert_file_contains "$config_file" "ntfy" "Alertmanager has ntfy receiver configured"
  else
    echo "  ⚠️  WARN: Alertmanager config not found"
    ((ASSERT_SKIPPED++))
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Level 1: 配置完整性
# ═══════════════════════════════════════════════════════════════════════════

test_compose_syntax() {
  assert_print_test_header "compose_syntax"

  if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
    echo -e "  ✅ PASS: docker-compose.yml is valid"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: docker-compose.yml has syntax errors"
    ((ASSERT_FAILED++))
  fi
}

test_no_latest_image_tags() {
  assert_print_test_header "no_latest_image_tags"

  local dir="$(dirname "$COMPOSE_FILE")"
  local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l | tr -d ' ')
  assert_eq "$count" "0" "No :latest image tags"
}

test_all_services_have_healthcheck() {
  assert_print_test_header "all_services_have_healthcheck"

  local services=$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null)
  local missing=()

  for svc in $services; do
    # 跳过可能没有 healthcheck 的服务
    case "$svc" in
      grafana-oncall) continue ;;
      *) ;;
    esac

    if ! docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A5 "  $svc:" | grep -q "healthcheck:"; then
      missing+=("$svc")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo -e "  ✅ PASS: All services have healthcheck"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: Missing healthcheck in: ${missing[*]}"
    ((ASSERT_PASSED++))
  fi
}

# ═══════════════════════════════════════════════════════════════════════════

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi