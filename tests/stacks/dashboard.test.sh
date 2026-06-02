#!/usr/bin/env bash
# =============================================================================
# Dashboard Stack Tests
# =============================================================================

test_homepage_running() {
  assert_container_running "homepage"
}

test_homepage_http() {
  assert_http_200 "http://localhost:3010" 10
}

run_test_with_timing "dashboard" test_homepage_running "Homepage running"
run_test_with_timing "dashboard" test_homepage_http "Homepage HTTP 200"
