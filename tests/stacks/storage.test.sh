#!/usr/bin/env bash
# ==============================================================================
# Storage Stack Tests
# Tests for Nextcloud, MinIO, FileBrowser, Syncthing
# ==============================================================================

# Test: Nextcloud container is running
test_nextcloud_running() {
    assert_container_running "nextcloud" || \
    assert_container_running "nextcloud-web"
}

# Test: Nextcloud is healthy
test_nextcloud_healthy() {
    assert_container_healthy "nextcloud" 120 || \
    assert_container_healthy "nextcloud-web" 120
}

# Test: Nextcloud status endpoint
test_nextcloud_status() {
    assert_http_200 "http://localhost:80/status.php" 10
    assert_http_response "http://localhost:80/status.php" '"installed":true'
}

# Test: Nextcloud WebDAV
test_nextcloud_webdav() {
    assert_http_code "http://localhost:80/remote.php/dav/files/" 401 10  # Requires auth
}

# Test: MinIO container is running
test_minio_running() {
    assert_container_running "minio"
}

# Test: MinIO is healthy
test_minio_healthy() {
    assert_container_healthy "minio" 60
}

# Test: MinIO Console
test_minio_console() {
    assert_http_200 "http://localhost:9001" 10 || \
    assert_http_code "http://localhost:9001" 302 10  # May redirect
}

# Test: MinIO API health
test_minio_api() {
    assert_http_200 "http://localhost:9000/minio/health/live" 10
}

# Test: FileBrowser container (if configured)
test_filebrowser_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "filebrowser"; then
        assert_container_running "filebrowser"
        assert_http_200 "http://localhost:8080/health" 10
    else
        log_skip "FileBrowser not configured"
    fi
}

# Test: Syncthing container (if configured)
test_syncthing_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "syncthing"; then
        assert_container_running "syncthing"
        assert_http_200 "http://localhost:8384/rest/noauth/health" 10
    else
        log_skip "Syncthing not configured"
    fi
}

# Test: Storage compose syntax
test_storage_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/storage/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Storage compose file not found"
    fi
}

# Test: No :latest tags
test_storage_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/storage"
}

# Test: Storage directories exist
test_storage_directories() {
    begin_test
    local storage_root="${STORAGE_ROOT:-/mnt/storage}"
    
    if [[ -d "$storage_root" ]]; then
        log_pass "Storage root exists: $storage_root"
    else
        log_skip "Storage root not configured: $storage_root"
    fi
}

# Test: MinIO buckets (requires mc client)
test_minio_buckets() {
    begin_test
    local minio_alias="local"
    
    if command -v mc &>/dev/null; then
        # Try to list buckets
        if mc ls "$minio_alias" >/dev/null 2>&1; then
            local buckets=$(mc ls "$minio_alias" 2>/dev/null | wc -l)
            log_pass "MinIO has $buckets buckets configured"
        else
            log_skip "Cannot list MinIO buckets (mc not configured)"
        fi
    else
        log_skip "mc client not available for bucket check"
    fi
}

# Run all tests
run_tests() {
    test_nextcloud_running
    test_nextcloud_healthy
    test_nextcloud_status
    test_nextcloud_webdav
    test_minio_running
    test_minio_healthy
    test_minio_console
    test_minio_api
    test_filebrowser_running
    test_syncthing_running
    test_storage_compose_syntax
    test_storage_no_latest_tags
    test_storage_directories
    test_minio_buckets
}

# Execute tests
run_tests