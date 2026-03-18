#!/usr/bin/env bash
# storage.test.sh — Storage Stack Tests (Nextcloud, MinIO, FileBrowser)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/storage/docker-compose.yml}"

test_nextcloud_running() { test_start "Nextcloud running"; assert_container_running "nextcloud"; test_end; }
test_nextcloud_healthy() { test_start "Nextcloud healthy"; assert_container_healthy "nextcloud" 120; test_end; }
test_nextcloud_http() { test_start "Nextcloud /status.php"; assert_http_200 "http://localhost/status.php" 15; test_end; }

test_minio_running() { test_start "MinIO running"; assert_container_running "minio"; test_end; }
test_minio_healthy() { test_start "MinIO healthy"; assert_container_healthy "minio" 60; test_end; }
test_minio_http() { test_start "MinIO Console HTTP"; assert_http_200 "http://localhost:9001" 15; test_end; }

test_filebrowser_running() { test_start "FileBrowser running"; assert_container_running "filebrowser"; test_end; }
test_filebrowser_healthy() { test_start "FileBrowser healthy"; assert_container_healthy "filebrowser" 60; test_end; }

test_compose_syntax() { test_start "Storage compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
