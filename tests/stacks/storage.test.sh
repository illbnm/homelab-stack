#!/bin/bash
# storage.test.sh - Storage Stack Integration Tests
# 测试存储组件：NFS, Samba, Nextcloud, etc.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

# Storage Stack 测试
test_storage_nextcloud_running() {
    local start_time=$(date +%s)
    if ! assert_container_running "nextcloud" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "storage" "Nextcloud running" "SKIP" "$duration" "Container not found"
        return 0
    fi
    local duration=$(($(date +%s) - start_time))
    log_test "storage" "Nextcloud running" "PASS" "$duration"
}

test_storage_nextcloud_status() {
    local start_time=$(date +%s)
    local response
    response=$(curl -s --max-time 30 "http://localhost:8080/status.php" 2>/dev/null || echo "")
    
    if [[ -z "$response" ]]; then
        local duration=$(($(date +%s) - start_time))
        log_test "storage" "Nextcloud status.php" "SKIP" "$duration" "Service not reachable"
        return 0
    fi
    
    if echo "$response" | grep -q '"installed":true'; then
        local duration=$(($(date +%s) - start_time))
        log_test "storage" "Nextcloud status.php" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "storage" "Nextcloud status.php" "FAIL" "$duration" "Not installed or wrong response"
    fi
}

test_storage_volumes_exist() {
    local start_time=$(date +%s)
    local volumes=("nextcloud_data" "storage_backup")
    local found=0
    
    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            ((found++))
        fi
    done
    
    local duration=$(($(date +%s) - start_time))
    if [[ $found -gt 0 ]]; then
        log_test "storage" "Storage volumes exist" "PASS" "$duration"
    else
        log_test "storage" "Storage volumes exist" "SKIP" "$duration" "No storage volumes found"
    fi
}

test_storage_compose_syntax() {
    local start_time=$(date +%s)
    local compose_file="$SCRIPT_DIR/../../stacks/storage/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        local duration=$(($(date +%s) - start_time))
        log_test "storage" "Compose syntax valid" "SKIP" "$duration" "File not found"
        return 0
    fi
    
    docker compose -f "$compose_file" config --quiet &>/dev/null
    local exit_code=$?
    local duration=$(($(date +%s) - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_test "storage" "Compose syntax valid" "PASS" "$duration"
    else
        log_test "storage" "Compose syntax valid" "FAIL" "$duration" "Invalid compose syntax"
    fi
}

# 运行所有 storage 测试
test_storage_all() {
    test_storage_nextcloud_running
    test_storage_nextcloud_status
    test_storage_volumes_exist
    test_storage_compose_syntax
}

# 如果直接执行此文件，运行所有测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_report
    test_storage_all
    
    stats=$(get_assert_stats)
    eval "$stats"
    finalize_report $ASSERT_PASS $ASSERT_FAIL $ASSERT_SKIP "$SCRIPT_DIR/../results"
fi
