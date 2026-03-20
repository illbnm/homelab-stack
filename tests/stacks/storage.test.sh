#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Storage Tests
# Services: Nextcloud, MinIO, FileBrowser
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/storage/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Storage — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Storage — Container Health"

  assert_container_running "nextcloud"
  assert_container_healthy "nextcloud"
  assert_container_not_restarting "nextcloud"

  assert_container_running "minio"
  assert_container_healthy "minio"
  assert_container_not_restarting "minio"

  assert_container_running "filebrowser"
  assert_container_healthy "filebrowser"
  assert_container_not_restarting "filebrowser"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Storage — HTTP Endpoints"

  # Nextcloud status page should report installed:true
  assert_http_ok "http://localhost:80/status.php" \
    "Nextcloud /status.php"

  if is_container_running "nextcloud"; then
    nc_status=$(curl -sf --connect-timeout 5 --max-time 10 "http://localhost:80/status.php" 2>/dev/null)
    if [[ -n "$nc_status" ]]; then
      assert_json_value "$nc_status" ".installed" "true" \
        "Nextcloud reports installed=true"
    else
      skip_test "Nextcloud reports installed=true" "could not reach status page"
    fi
  else
    skip_test "Nextcloud reports installed=true" "nextcloud not running"
  fi

  # MinIO health
  assert_http_ok "http://localhost:9000/minio/health/live" \
    "MinIO health/live"

  # MinIO console
  assert_http_ok "http://localhost:9001" \
    "MinIO console"

  # FileBrowser
  assert_http_ok "http://localhost:8080" \
    "FileBrowser web UI"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Storage — Interconnection"

  assert_container_in_network "nextcloud" "proxy"
  assert_container_in_network "nextcloud" "databases"
  assert_container_in_network "minio" "proxy"

  # Nextcloud → PostgreSQL connectivity
  if is_container_running "nextcloud" && is_container_running "homelab-postgres"; then
    assert_docker_exec "nextcloud" \
      "Nextcloud can reach PostgreSQL" \
      php -r "new PDO('pgsql:host=homelab-postgres;dbname=nextcloud', '${POSTGRES_USER:-homelab}', '${POSTGRES_PASSWORD:-changeme}');"
  else
    skip_test "Nextcloud can reach PostgreSQL" "nextcloud or postgres not running"
  fi

  # Nextcloud → Redis connectivity
  if is_container_running "nextcloud" && is_container_running "homelab-redis"; then
    assert_docker_exec "nextcloud" \
      "Nextcloud can reach Redis" \
      bash -c "echo PING | nc -w3 homelab-redis 6379"
  else
    skip_test "Nextcloud can reach Redis" "nextcloud or redis not running"
  fi
fi
