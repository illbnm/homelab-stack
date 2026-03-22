#!/usr/bin/env bash
# storage.test.sh — Tests for the storage stack

STACK_DIR="${REPO_ROOT}/stacks/storage"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

NEXTCLOUD_HOST="${NEXTCLOUD_HOST:-localhost}"
MINIO_HOST="${MINIO_HOST:-localhost}"
FILEBROWSER_HOST="${FILEBROWSER_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "storage: compose syntax valid"
else
  assert_fail "storage: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "storage: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in nextcloud minio filebrowser; do
  if docker_container_exists "$container"; then
    assert_container_running "storage: ${container} is running" "$container"
  else
    assert_skip "storage: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "nextcloud"; then
  status_json=$(curl -s --max-time 10 \
    "http://${NEXTCLOUD_HOST}:80/status.php" 2>/dev/null || echo '{}')
  assert_json_value "storage: Nextcloud installed" \
    "$status_json" '.installed' "true"
else
  assert_skip "storage: Nextcloud installed" "container not deployed"
fi

if docker_container_exists "minio"; then
  assert_http_200 "storage: MinIO health" \
    "http://${MINIO_HOST}:9000/minio/health/live"
else
  assert_skip "storage: MinIO health" "container not deployed"
fi

if docker_container_exists "filebrowser"; then
  assert_http_200 "storage: FileBrowser web UI" \
    "http://${FILEBROWSER_HOST}:80/"
else
  assert_skip "storage: FileBrowser web UI" "container not deployed"
fi
