#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests
# =============================================================================

test_gitea_running() {
  assert_container_running "gitea"
}

test_gitea_http() {
  assert_http_200 "http://localhost:3001" 10
}

test_gitea_api() {
  assert_http_200 "http://localhost:3001/api/v1/version" 10
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}

test_vaultwarden_http() {
  assert_http_200 "http://localhost:8080" 10
}

run_test_with_timing "productivity" test_gitea_running "Gitea running"
run_test_with_timing "productivity" test_gitea_http "Gitea HTTP 200"
run_test_with_timing "productivity" test_gitea_api "Gitea API v1/version 200"
run_test_with_timing "productivity" test_vaultwarden_running "Vaultwarden running"
run_test_with_timing "productivity" test_vaultwarden_http "Vaultwarden HTTP 200"
