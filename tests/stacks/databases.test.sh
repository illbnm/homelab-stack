#!/bin/bash
# =============================================================================
# databases.test.sh - Databases stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    
    docker compose -f stacks/databases/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_postgres_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "homelab-postgres" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "PostgreSQL running" "$result" $((end - start))
}

test_postgres_healthy() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_healthy "homelab-postgres" 60 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "PostgreSQL healthy" "$result" $((end - start))
}

test_redis_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "homelab-redis" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Redis running" "$result" $((end - start))
}

test_redis_healthy() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_healthy "homelab-redis" 60 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Redis healthy" "$result" $((end - start))
}

test_mariadb_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "homelab-mariadb" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "MariaDB running" "$result" $((end - start))
}

test_mariadb_healthy() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_healthy "homelab-mariadb" 60 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "MariaDB healthy" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_postgres_running
test_postgres_healthy
test_redis_running
test_redis_healthy
test_mariadb_running
test_mariadb_healthy
