#!/bin/bash

# Database Stack Integration Tests
# Tests PostgreSQL, Redis, MariaDB containers and management UIs

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"

STACK_NAME="databases"
COMPOSE_FILE="stacks/databases/docker-compose.yml"

test_postgres_container_health() {
    echo "Testing PostgreSQL container health..."
    assert_container_running "postgres"
    assert_container_healthy "postgres"

    # Test database connectivity
    local result=$(docker exec postgres psql -U postgres -d postgres -c "SELECT 1;" 2>/dev/null | grep -c "1 row")
    assert_eq "$result" "1" "PostgreSQL connection test failed"
}

test_redis_container_health() {
    echo "Testing Redis container health..."
    assert_container_running "redis"
    assert_container_healthy "redis"

    # Test Redis connectivity
    local pong=$(docker exec redis redis-cli ping)
    assert_eq "$pong" "PONG" "Redis ping test failed"
}

test_mariadb_container_health() {
    echo "Testing MariaDB container health..."
    assert_container_running "mariadb"
    assert_container_healthy "mariadb"

    # Test MariaDB connectivity
    local result=$(docker exec mariadb mysql -u root -pchangeme -e "SELECT 1;" 2>/dev/null | grep -c "1")
    assert_eq "$result" "1" "MariaDB connection test failed"
}

test_pgadmin_ui_accessibility() {
    echo "Testing pgAdmin UI accessibility..."
    assert_container_running "pgadmin"
    assert_container_healthy "pgadmin"

    # Wait for pgAdmin to fully start
    sleep 10

    # Test HTTP endpoint through Traefik
    assert_http_200 "http://pgadmin.homelab.local" "pgAdmin UI not accessible"
}

test_redis_commander_ui_accessibility() {
    echo "Testing Redis Commander UI accessibility..."
    assert_container_running "redis-commander"
    assert_container_healthy "redis-commander"

    # Test HTTP endpoint through Traefik
    assert_http_200 "http://redis.homelab.local" "Redis Commander UI not accessible"
}

test_database_tenant_initialization() {
    echo "Testing database tenant initialization..."

    # Run init script
    bash scripts/init-databases.sh
    local init_exit_code=$?
    assert_eq "$init_exit_code" "0" "Database initialization script failed"

    # Verify tenant databases exist
    local nextcloud_db=$(docker exec postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -w nextcloud | wc -l)
    assert_eq "$nextcloud_db" "1" "Nextcloud database not created"

    local gitea_db=$(docker exec postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -w gitea | wc -l)
    assert_eq "$gitea_db" "1" "Gitea database not created"

    local outline_db=$(docker exec postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -w outline | wc -l)
    assert_eq "$outline_db" "1" "Outline database not created"
}

test_backup_script_functionality() {
    echo "Testing database backup script..."

    # Create test data
    docker exec postgres psql -U postgres -d nextcloud -c "CREATE TABLE IF NOT EXISTS test_backup (id int, data text);"
    docker exec postgres psql -U postgres -d nextcloud -c "INSERT INTO test_backup VALUES (1, 'backup_test_data');"

    # Run backup script
    bash scripts/backup-databases.sh
    local backup_exit_code=$?
    assert_eq "$backup_exit_code" "0" "Database backup script failed"

    # Verify backup files exist
    assert_file_exists "backups/postgres_*.sql" "PostgreSQL backup file not created"
    assert_file_exists "backups/redis_*.rdb" "Redis backup file not created"
    assert_file_exists "backups/mariadb_*.sql" "MariaDB backup file not created"
}

test_init_script_idempotency() {
    echo "Testing initialization script idempotency..."

    # Run init script twice
    bash scripts/init-databases.sh
    local first_run=$?
    bash scripts/init-databases.sh
    local second_run=$?

    assert_eq "$first_run" "0" "First init run failed"
    assert_eq "$second_run" "0" "Second init run failed (not idempotent)"

    # Verify no duplicate databases
    local db_count=$(docker exec postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -E "(nextcloud|gitea|outline)" | wc -l)
    assert_eq "$db_count" "3" "Duplicate databases created during second init"
}

test_network_isolation() {
    echo "Testing database network isolation..."

    # Core DB containers should only be on internal network
    local postgres_networks=$(docker inspect postgres --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
    assert_contains "$postgres_networks" "internal" "PostgreSQL not on internal network"
    assert_not_contains "$postgres_networks" "proxy" "PostgreSQL incorrectly exposed to proxy network"

    local redis_networks=$(docker inspect redis --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
    assert_contains "$redis_networks" "internal" "Redis not on internal network"
    assert_not_contains "$redis_networks" "proxy" "Redis incorrectly exposed to proxy network"

    # Management UIs should be on both networks
    local pgadmin_networks=$(docker inspect pgadmin --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
    assert_contains "$pgadmin_networks" "internal" "pgAdmin not on internal network"
    assert_contains "$pgadmin_networks" "proxy" "pgAdmin not on proxy network"
}

test_database_connection_failure_recovery() {
    echo "Testing database connection failure recovery..."

    # Stop postgres temporarily
    docker stop postgres
    sleep 5

    # Restart postgres
    docker start postgres

    # Wait for health check to pass
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec postgres pg_isready -U postgres > /dev/null 2>&1; then
            break
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    assert_lt "$attempt" "$max_attempts" "PostgreSQL failed to recover after restart"

    # Test connection works after recovery
    local result=$(docker exec postgres psql -U postgres -d postgres -c "SELECT 1;" 2>/dev/null | grep -c "1 row")
    assert_eq "$result" "1" "PostgreSQL connection failed after recovery"
}

# Run all tests
run_tests() {
    echo "Starting database stack integration tests..."

    # Ensure stack is running
    docker-compose -f "$COMPOSE_FILE" up -d
    sleep 30

    test_postgres_container_health
    test_redis_container_health
    test_mariadb_container_health
    test_pgadmin_ui_accessibility
    test_redis_commander_ui_accessibility
    test_database_tenant_initialization
    test_backup_script_functionality
    test_init_script_idempotency
    test_network_isolation
    test_database_connection_failure_recovery

    echo "Database stack tests completed successfully!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
