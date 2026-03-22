#!/usr/bin/env bash
# Productivity stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_gitea_running() {
  assert_container_running "gitea"
  assert_container_healthy "gitea"
  assert_http_200 "http://localhost:3000/api/v1/version"
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
  assert_http_200 "http://localhost:80"
}

test_outline_running() {
  assert_container_running "outline"
  assert_http_200 "http://localhost:3000"
}

test_stirling_running() {
  assert_container_running "stirling-pdf"
  assert_http_200 "http://localhost:8080"
}

run_test test_gitea_running
run_test test_vaultwarden_running
run_test test_outline_running
run_test test_stirling_running
