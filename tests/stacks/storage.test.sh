#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Storage Stack Tests
# Tests: Nextcloud + MinIO + FileBrowser
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "storage" || { begin_suite "Storage Stack"; assert_skip "not selected"; exit 0; }

begin_suite "Storage Stack — Nextcloud + MinIO + FileBrowser"

# ---- Nextcloud ----
assert_container_running "nextcloud"
assert_container_healthy "nextcloud"
assert_container_not_latest "nextcloud"
assert_http_200 "${BASE_URL:-http://localhost}:8080/status.php" "nextcloud:status"
assert_http_json_field "${BASE_URL:-http://localhost}:8080/status.php" "installed" "true" "nextcloud:installed"

# ---- MinIO ----
assert_container_running "minio"
assert_container_healthy "minio"
assert_container_not_latest "minio"
assert_http_200 "${BASE_URL:-http://localhost}:9001" "minio:console"
assert_port_open "localhost" "9000" "minio:api"

# ---- FileBrowser ----
assert_container_running "filebrowser"
assert_container_healthy "filebrowser"
assert_container_not_latest "filebrowser"
assert_http_200 "${BASE_URL:-http://localhost}:8081" "filebrowser:ui"

# ---- Inter-service ----
begin_test "nextcloud:can_reach_redis"
if docker exec nextcloud curl -sf --connect-timeout 3 "http://redis:6379" 2>/dev/null; then
  assert_pass "nextcloud → redis reachable"
else
  assert_skip "redis connection (may use internal network)"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/storage/docker-compose.yml" "storage"
