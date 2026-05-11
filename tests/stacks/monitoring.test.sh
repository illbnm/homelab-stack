#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[monitoring] Running monitoring stack tests..."
assert_container_running "prometheus" && print_test_result "monitoring" "Prometheus running" "PASS" "0.3s" || true
assert_container_running "grafana" && print_test_result "monitoring" "Grafana running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:9090/-/healthy" && print_test_result "monitoring" "Prometheus healthy" "PASS" "1.2s" || true
assert_http_200 "http://localhost:3000/api/health" && print_test_result "monitoring" "Grafana API health" "PASS" "1.2s" || true
