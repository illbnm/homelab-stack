#!/usr/bin/env bash
# monitoring.test.sh - Monitoring Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="monitoring"

test_prometheus() {
    test_start "Prometheus - 容器运行"
    if assert_container_running "prometheus"; then test_end "Prometheus - 容器运行" "PASS"
    else test_end "Prometheus - 容器运行" "FAIL"; return 1; fi
    test_start "Prometheus - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9090/"; then test_end "Prometheus - HTTP 端点可达" "PASS"
    else test_end "Prometheus - HTTP 端点可达" "SKIP"; fi
    test_start "Prometheus - API 可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9090/api/v1/status/config"; then test_end "Prometheus - API 可达" "PASS"
    else test_end "Prometheus - API 可达" "SKIP"; fi
}

test_grafana() {
    test_start "Grafana - 容器运行"
    if assert_container_running "grafana"; then test_end "Grafana - 容器运行" "PASS"
    else test_end "Grafana - 容器运行" "FAIL"; return 1; fi
    test_start "Grafana - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3000/"; then test_end "Grafana - HTTP 端点可达" "PASS"
    else test_end "Grafana - HTTP 端点可达" "SKIP"; fi
}

test_loki() {
    test_start "Loki - 容器运行"
    if assert_container_running "loki"; then test_end "Loki - 容器运行" "PASS"
    else test_end "Loki - 容器运行" "FAIL"; return 1; fi
    test_start "Loki - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3100/"; then test_end "Loki - HTTP 端点可达" "PASS"
    else test_end "Loki - HTTP 端点可达" "SKIP"; fi
}

test_alertmanager() {
    test_start "Alertmanager - 容器运行"
    if assert_container_running "alertmanager"; then test_end "Alertmanager - 容器运行" "PASS"
    else test_end "Alertmanager - 容器运行" "FAIL"; return 1; fi
    test_start "Alertmanager - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9093/"; then test_end "Alertmanager - HTTP 端点可达" "PASS"
    else test_end "Alertmanager - HTTP 端点可达" "SKIP"; fi
}

test_cadvisor() {
    test_start "cAdvisor - 容器运行"
    if assert_container_running "cadvisor"; then test_end "cAdvisor - 容器运行" "PASS"
    else test_end "cAdvisor - 容器运行" "FAIL"; return 1; fi
    test_start "cAdvisor - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "cAdvisor - HTTP 端点可达" "PASS"
    else test_end "cAdvisor - HTTP 端点可达" "SKIP"; fi
    test_start "cAdvisor - Metrics 端点"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/metrics"; then test_end "cAdvisor - Metrics 端点" "PASS"
    else test_end "cAdvisor - Metrics 端点" "SKIP"; fi
}

test_node_exporter() {
    test_start "Node Exporter - 容器运行"
    if assert_container_running "node-exporter"; then test_end "Node Exporter - 容器运行" "PASS"
    else test_end "Node Exporter - 容器运行" "FAIL"; return 1; fi
    test_start "Node Exporter - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9100/"; then test_end "Node Exporter - HTTP 端点可达" "PASS"
    else test_end "Node Exporter - HTTP 端点可达" "SKIP"; fi
}

test_uptime_kuma() {
    test_start "Uptime Kuma - 容器运行"
    if assert_container_running "uptime-kuma"; then test_end "Uptime Kuma - 容器运行" "PASS"
    else test_end "Uptime Kuma - 容器运行" "FAIL"; return 1; fi
    test_start "Uptime Kuma - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3001/"; then test_end "Uptime Kuma - HTTP 端点可达" "PASS"
    else test_end "Uptime Kuma - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_prometheus || true; test_grafana || true; test_loki || true; test_alertmanager || true
    test_cadvisor || true; test_node_exporter || true; test_uptime_kuma || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
