#!/usr/bin/env bash
# Notifications stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_ntfy_running() {
  assert_container_running "ntfy"
  assert_container_healthy "ntfy"
  assert_http_200 "http://localhost:80/v1/health"
}

test_gotify_running() {
  assert_container_running "gotify"
  assert_container_healthy "gotify"
  assert_http_200 "http://localhost:8080/health"
}

test_notify_script_exists() {
  assert_file_exists "scripts/notify.sh"
  assert_executable "scripts/notify.sh"
}

run_test test_ntfy_running
run_test test_gotify_running
run_test test_notify_script_exists
