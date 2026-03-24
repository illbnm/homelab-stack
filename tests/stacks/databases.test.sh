#!/usr/bin/env bash
# ==============================================================================
# Database Layer Stack Tests
# Tests for PostgreSQL, Redis, MariaDB, pgAdmin, Redis Commander
# ==============================================================================

# Test: PostgreSQL container is running
test_postgres_running() {
    assert_container_running "homelab-postgres"
}

# Test: PostgreSQL is healthy
test_postgres_healthy() {
    assert_container_healthy "homelab-postgres" 60
}

# Test: PostgreSQL accepts connections
test_postgres_connection() {
    begin_test
    local result=$(docker exec homelab-postgres pg_isready -U postgres 2>/dev/null || echo "failed")
    if [[ "$result" == *"accepting connections"* ]]; then
        log_pass "PostgreSQL accepting connections"
    else
        log_fail "PostgreSQL not accepting connections: $result"
    fi
}

# Test: PostgreSQL databases exist
test_postgres_databases() {
    begin_test
    local expected_dbs=("nextcloud" "gitea" "outline" "authentik" "grafana" "vaultwarden")
    local all_found=true
    
    for db in "${expected_dbs[@]}"; do
        if docker exec homelab-postgres psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$db"; then
            : # database exists
        else
            all_found=false
            break
        fi
    done
    
    if [[ "$all_found" == true ]]; then
        log_pass "All expected PostgreSQL databases exist"
    else
        log_skip "Some PostgreSQL databases not yet created"
    fi
}

# Test: Redis container is running
test_redis_running() {
    assert_container_running "homelab-redis"
}

# Test: Redis is healthy
test_redis_healthy() {
    assert_container_healthy "homelab-redis" 60
}

# Test: Redis accepts connections
test_redis_connection() {
    begin_test
    local result=$(docker exec homelab-redis redis-cli ping 2>/dev/null || echo "failed")
    if [[ "$result" == "PONG" ]]; then
        log_pass "Redis responding to ping"
    else
        log_fail "Redis not responding: $result"
    fi
}

# Test: MariaDB container (if configured)
test_mariadb_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "homelab-mariadb"; then
        assert_container_running "homelab-mariadb"
        assert_container_healthy "homelab-mariadb" 60
    else
        log_skip "MariaDB not configured"
    fi
}

# Test: pgAdmin (if configured)
test_pgadmin_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pgadmin"; then
        assert_container_running "pgadmin"
        assert_http_200 "http://localhost:5050" 10
    else
        log_skip "pgAdmin not configured"
    fi
}

# Test: Redis Commander (if configured)
test_redis_commander_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "redis-commander"; then
        assert_container_running "redis-commander"
        assert_http_200 "http://localhost:8081" 10
    else
        log_skip "Redis Commander not configured"
    fi
}

# Test: Database not exposed externally
test_databases_not_exposed() {
    begin_test
    local exposed=false
    
    # Check if any DB ports are bound to host
    if docker port homelab-postgres 5432 >/dev/null 2>&1; then
        exposed=true
    fi
    if docker port homelab-redis 6379 >/dev/null 2>&1; then
        exposed=true
    fi
    
    if [[ "$exposed" == false ]]; then
        log_pass "Database ports not exposed to host"
    else
        log_fail "Database ports are exposed to host (security risk)"
    fi
}

# Test: Docker Compose syntax
test_databases_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/databases/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Databases compose file not found"
    fi
}

# Run all tests
run_tests() {
    test_postgres_running
    test_postgres_healthy
    test_postgres_connection
    test_postgres_databases
    test_redis_running
    test_redis_healthy
    test_redis_connection
    test_mariadb_running
    test_pgadmin_running
    test_redis_commander_running
    test_databases_not_exposed
    test_databases_compose_syntax
}

# Execute tests
run_tests