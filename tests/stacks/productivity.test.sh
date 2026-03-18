#!/usr/bin/env bash
# =============================================================================
# productivity.test.sh — Productivity stack tests
# Services: Gitea, Vaultwarden, Outline, BookStack
# =============================================================================

# --- Gitea ---

test_gitea_running() {
  assert_container_running "gitea"
}

test_gitea_healthy() {
  assert_container_healthy "gitea"
}

test_gitea_api() {
  assert_http_200 "http://localhost:3000/api/v1/version" 15
}

test_gitea_api_version_json() {
  assert_http_body_contains "http://localhost:3000/api/v1/version" '"version"' 10
}

test_gitea_no_crash_loop() {
  assert_no_crash_loop "gitea" 3
}

test_gitea_in_proxy_network() {
  assert_container_in_network "gitea" "proxy"
}

# --- Vaultwarden ---

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}

test_vaultwarden_healthy() {
  assert_container_healthy "vaultwarden"
}

test_vaultwarden_alive() {
  assert_http_200 "http://localhost:8080/alive" 10
}

test_vaultwarden_no_crash_loop() {
  assert_no_crash_loop "vaultwarden" 3
}

test_vaultwarden_in_proxy_network() {
  assert_container_in_network "vaultwarden" "proxy"
}

# --- Outline ---

test_outline_running() {
  assert_container_running "outline"
}

test_outline_healthy() {
  assert_container_healthy "outline"
}

test_outline_ui() {
  # Outline may redirect to login
  assert_http_status "http://localhost:3001" 200 15
}

test_outline_no_crash_loop() {
  assert_no_crash_loop "outline" 3
}

# --- BookStack ---

test_bookstack_running() {
  assert_container_running "bookstack"
}

test_bookstack_healthy() {
  assert_container_healthy "bookstack"
}

test_bookstack_ui() {
  assert_http_status "http://localhost:6875" 200 15
}

test_bookstack_no_crash_loop() {
  assert_no_crash_loop "bookstack" 3
}
