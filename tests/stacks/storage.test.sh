test_nextcloud_running() { assert_container_running "homelab-nextcloud"; }
test_nextcloud_nginx_running() { assert_container_running "homelab-nextcloud-nginx"; }
test_nextcloud_api() { assert_http_response "http://localhost:80/status.php" "installed"; }
test_minio_running() { assert_container_running "homelab-minio"; }
test_minio_api() { assert_http_200 "http://localhost:9000/minio/health/live" 10; }
test_filebrowser_running() { assert_container_running "homelab-filebrowser"; }
test_syncthing_running() { assert_container_running "homelab-syncthing"; }
