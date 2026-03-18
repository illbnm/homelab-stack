# Storage stack tests

CURRENT_TEST="nextcloud_running"
assert_container_running "nextcloud"

CURRENT_TEST="nextcloud_nginx_running"
assert_container_running "nextcloud-nginx"

CURRENT_TEST="nextcloud_status"
local nc_status=$(curl -sf http://localhost:80/status.php 2>/dev/null || echo "{}")
assert_contains "$nc_status" "installed" "Nextcloud status.php returns installed"

CURRENT_TEST="minio_running"
assert_container_running "minio"

CURRENT_TEST="minio_healthy"
assert_container_healthy "minio"

CURRENT_TEST="minio_api"
assert_http_200 "http://localhost:9000/minio/health/live"

CURRENT_TEST="filebrowser_running"
assert_container_running "filebrowser"

CURRENT_TEST="filebrowser_healthy"
assert_container_healthy "filebrowser"

CURRENT_TEST="syncthing_running"
assert_container_running "syncthing"

CURRENT_TEST="syncthing_healthy"
assert_container_healthy "syncthing"

CURRENT_TEST="syncthing_api"
assert_http_200 "http://localhost:8384/rest/noauth/health"
