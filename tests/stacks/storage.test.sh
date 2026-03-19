#!/bin/bash
# storage.test.sh - Storage Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_nextcloud_running() {
    echo "[storage] Testing Nextcloud running..."
    assert_container_running "nextcloud"
}

test_nextcloud_http() {
    echo "[storage] Testing Nextcloud HTTP..."
    local response=$(curl -s --max-time 30 "http://localhost:8081/status.php" 2>/dev/null)
    if echo "$response" | grep -q '"installed":true'; then
        echo -e "${GREEN}✅ PASS${NC} Nextcloud installed"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Nextcloud not properly installed"
        return 1
    fi
}

test_samba_running() {
    echo "[storage] Testing Samba running..."
    assert_container_running "samba"
}

test_nfs_running() {
    echo "[storage] Testing NFS running..."
    assert_container_running "nfs" || return 0  # Optional
}

test_syncthing_running() {
    echo "[storage] Testing Syncthing running..."
    assert_container_running "syncthing"
}

test_syncthing_http() {
    echo "[storage] Testing Syncthing HTTP..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:8384/rest/noauth" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Syncthing API returned $http_code"
        return 1
    fi
}

test_compose_exists() {
    echo "[storage] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/storage/docker-compose.yml"
}

run_storage_tests() {
    print_header "HomeLab Stack — Storage Tests"
    
    test_compose_exists || true
    test_nextcloud_running || true
    test_nextcloud_http || true
    test_samba_running || true
    test_nfs_running || true
    test_syncthing_running || true
    test_syncthing_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_storage_tests
fi
