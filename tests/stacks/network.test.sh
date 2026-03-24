#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests
# =============================================================================

assert_container_running adguardhome
assert_container_running wg-easy

# HTTP endpoints
assert_http_200 "http://localhost:3000" 10
