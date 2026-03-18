#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests — Nextcloud + MinIO + FileBrowser + Syncthing
# =============================================================================

# --- Level 1: Container Health ---

test_storage_nextcloud_running() {
  assert_container_running "homelab-nextcloud"
}

test_storage_nextcloud_healthy() {
  assert_container_healthy "homelab-nextcloud" 120
}

test_storage_nextcloud_nginx_running() {
  assert_container_running "homelab-nextcloud-nginx"
}

test_storage_nextcloud_nginx_healthy() {
  assert_container_healthy "homelab-nextcloud-nginx" 60
}

test_storage_nextcloud_cron_running() {
  assert_container_running "homelab-nextcloud-cron"
}

test_storage_minio_running() {
  assert_container_running "homelab-minio"
}

test_storage_minio_healthy() {
  assert_container_healthy "homelab-minio" 60
}

test_storage_filebrowser_running() {
  assert_container_running "homelab-filebrowser"
}

test_storage_filebrowser_healthy() {
  assert_container_healthy "homelab-filebrowser" 30
}

test_storage_syncthing_running() {
  assert_container_running "homelab-syncthing"
}

test_storage_syncthing_healthy() {
  assert_container_healthy "homelab-syncthing" 60
}

# --- Level 1: Configuration ---

test_storage_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/storage/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "storage compose syntax invalid: ${output}"
}

test_storage_no_latest_tags() {
  assert_no_latest_images "stacks/storage/"
}

# --- Level 2: Nextcloud ---

test_storage_nextcloud_installed() {
  # Nextcloud enforces trusted domains, so we curl from inside nginx container
  assert_docker_exec "homelab-nextcloud-nginx" \
    "curl -sf http://127.0.0.1:80/status.php 2>/dev/null" '"installed":true'
}

test_storage_nextcloud_version() {
  assert_docker_exec "homelab-nextcloud-nginx" \
    "curl -sf http://127.0.0.1:80/status.php 2>/dev/null" '"versionstring":"29'
}

test_storage_nextcloud_pg_connection() {
  assert_docker_exec "homelab-nextcloud" \
    "php -r \"new PDO('pgsql:host=homelab-postgres;dbname=nextcloud', 'nextcloud', getenv('POSTGRES_PASSWORD') ?: 'test'); echo 'OK';\"" "OK"
}

test_storage_nextcloud_fpm_not_on_proxy() {
  assert_container_not_on_network "homelab-nextcloud" "proxy"
}

test_storage_nextcloud_nginx_on_proxy() {
  assert_container_on_network "homelab-nextcloud-nginx" "proxy"
}

# --- Level 2: MinIO ---

test_storage_minio_health() {
  local minio_ip
  minio_ip=$(get_container_ip homelab-minio)
  assert_http_200 "http://${minio_ip}:9000/minio/health/live" 10
}

test_storage_minio_console() {
  local minio_ip
  minio_ip=$(get_container_ip homelab-minio)
  assert_http_200 "http://${minio_ip}:9001/" 10
}

test_storage_minio_init_completed() {
  assert_container_exited_ok "homelab-minio-init"
}

test_storage_minio_buckets_exist() {
  local logs
  logs=$(get_container_logs "homelab-minio-init" 20)
  assert_contains "${logs}" "Initialization complete"
}

# --- Level 2: FileBrowser ---

test_storage_filebrowser_http() {
  local fb_ip
  fb_ip=$(get_container_ip homelab-filebrowser)
  assert_http_200 "http://${fb_ip}:80/health" 10
}

# --- Level 2: Syncthing ---

test_storage_syncthing_api() {
  # Syncthing GUI binds to 127.0.0.1 by default, so test from inside container
  assert_docker_exec "homelab-syncthing" \
    "wget -qO- http://127.0.0.1:8384/rest/noauth/health 2>/dev/null" 'OK'
}

test_storage_syncthing_p2p_port() {
  assert_port_listening 22000
}

# --- Level 3: Network ---

test_storage_internal_network_exists() {
  assert_network_exists "storage-internal"
}
