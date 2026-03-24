#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests
# =============================================================================

assert_container_running gitea
assert_container_running vaultwarden

# HTTP endpoints
assert_http_200 "http://localhost:3001/api/v1/version" 10
assert_http_200 "http://localhost:8080/alive" 10
