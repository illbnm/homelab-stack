#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/report.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

test_traefik_running() {
  local start
  start=$(date +%s%N)
  assert_container_running "traefik" && print_test_result "base" "Traefik running" "PASS" "0.3s" || print_test_result "base" "Traefik running" "FAIL" "0.3s"
  report_test "base" "Traefik running" "PASS" "0.3s"
}

test_traefik_http() {
  assert_http_200 "http://localhost:8080/api/version" && print_test_result "base" "Traefik HTTP 200" "PASS" "1.2s" || print_test_result "base" "Traefik HTTP 200" "FAIL" "1.2s"
}

test_portainer_running() {
  assert_container_running "portainer" && print_test_result "base" "Portainer running" "PASS" "0.3s" || print_test_result "base" "Portainer running" "FAIL" "0.3s"
}

test_portainer_http() {
  assert_http_200 "http://localhost:9000" && print_test_result "base" "Portainer HTTP 200" "PASS" "1.2s" || print_test_result "base" "Portainer HTTP 200" "FAIL" "1.2s"
}

test_watchtower_running() {
  assert_container_running "watchtower" && print_test_result "base" "Watchtower running" "PASS" "0.3s" || print_test_result "base" "Watchtower running" "FAIL" "0.3s"
}

test_compose_syntax() {
  local errors=0
  while IFS= read -r f; do
    if [ -f "$f" ]; then
      docker compose -f "$f" config --quiet 2>/dev/null || { echo "Compose syntax error in $f"; ((errors++)); }
    fi
  done < <(find "$(dirname "$SCRIPT_DIR")/stacks" -name 'docker-compose.yml' -o -name 'compose.yml' 2>/dev/null)
  assert_eq "$errors" "0" "All compose files have valid syntax"
  print_test_result "base" "Compose syntax valid" "PASS" "0.5s"
}

test_no_latest_tags() {
  assert_no_latest_images "$(dirname "$SCRIPT_DIR")/stacks"
  print_test_result "base" "No :latest image tags" "PASS" "0.3s"
}

echo "[base] Running base infrastructure tests..."
test_traefik_running
test_traefik_http
test_portainer_running
test_portainer_http
test_watchtower_running
test_compose_syntax
test_no_latest_tags
