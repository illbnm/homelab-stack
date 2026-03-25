#!/bin/bash
# =============================================================================
# storage.test.sh - Storage stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    docker compose -f stacks/storage/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_nextcloud_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "nextcloud" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Nextcloud running" "$result" $((end - start))
}

test_minio_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "minio" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "MinIO running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_nextcloud_running
test_minio_running
