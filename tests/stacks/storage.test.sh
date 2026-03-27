#!/bin/bash
# =============================================================================
# Storage Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Nextcloud, MinIO, FileBrowser
# Level: 1 + 2 + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "Storage Stack"

test_nextcloud_running()    { assert_container_running "nextcloud"; }
test_minio_running()         { assert_container_running "minio"; }
test_filebrowser_running()   { assert_container_running "filebrowser"; }

test_nextcloud_http()        { assert_http_200 "http://nextcloud:80/status.php" 20; }
test_minio_http()            { assert_http_200 "http://minio:9000/minio/health/live" 15; }
test_filebrowser_http()      { assert_http_200 "http://filebrowser:80" 10 || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/storage" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()        { assert_no_latest_images "stacks/storage"; }

tests=(test_nextcloud_running test_minio_running test_filebrowser_running
       test_nextcloud_http test_minio_http test_filebrowser_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
