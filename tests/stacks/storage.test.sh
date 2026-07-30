#!/usr/bin/env bash
# Storage Stack Tests — Nextcloud + MinIO + FileBrowser + Syncthing
test_nextcloud_running() { assert_eq "$(container_status nextcloud)" "running" "Nextcloud should be running"; }
test_nextcloud_status() { assert_http_200 "http://localhost:80/status.php" "Nextcloud status endpoint"; }
test_nextcloud_installed() { assert_http_contains "http://localhost:80/status.php" '"installed":true' "Nextcloud should report installed"; }
test_minio_running() { assert_eq "$(container_status minio)" "running" "MinIO should be running"; }
test_minio_console() { assert_http_status "http://localhost:9001" "200" "MinIO console should respond"; }
test_filebrowser_running() { assert_eq "$(container_status filebrowser)" "running" "FileBrowser should be running"; }
test_syncthing_running() { assert_eq "$(container_status syncthing)" "running" "Syncthing should be running"; }
test_syncthing_webui() { assert_http_status "http://localhost:8384" "200" "Syncthing WebUI should respond"; }