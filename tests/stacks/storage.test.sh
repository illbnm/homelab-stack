#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests
# =============================================================================

assert_container_running nextcloud
assert_container_running minio
assert_container_running filebrowser

# HTTP endpoints
assert_http_200 "http://localhost:9001" 10
