#!/bin/bash
# =============================================================================
# Databases Stack Tests — HomeLab Stack
# =============================================================================
# Tests: PostgreSQL, Redis, MariaDB, phpMyAdmin
# Level: 1 (container health) + 2 (HTTP endpoints) + 5 (config)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    if [[ -f "$ROOT_DIR/.env" ]]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    fi
}
load_env

suite_start "Databases Stack"

# Level 1 — Container Health
test_postgres_running() {
    assert_container_running "homelab-postgres"
}

test_redis_running() {
    assert_container_running "homelab-redis"
}

test_mariadb_running() {
    assert_container_running "homelab-mariadb"
}

test_phpmyadmin_running() {
    assert_container_running "homelab-phpmyadmin" || true
}

# Level 1 — Container Health (with wait)
test_postgres_healthy() {
    assert_container_healthy "homelab-postgres" 60
}

test_mariadb_healthy() {
    assert_container_healthy "homelab-mariadb" 60
}

# Level 2 — HTTP Endpoint
test_phpmyadmin_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        # CI environment — use port mapping
        assert_http_200 "http://localhost:8081/" 15 || true
    else
        assert_http_200 "http://phpmyadmin.${domain}" 15
    fi
}

# Level 5 — Configuration Integrity
test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/databases" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || {
            echo "Invalid compose: $f"
            failed=1
        }
    done
    [[ $failed -eq 0 ]]
}

test_no_latest_tags() {
    assert_no_latest_images "stacks/databases"
}

test_backup_scripts_exist() {
    assert_file_contains "$ROOT_DIR/config/databases/backup-postgres.sh" "#!/bin/bash"
    assert_file_contains "$ROOT_DIR/config/databases/backup-mariadb.sh" "#!/bin/bash"
}

test_env_example_has_backup_vars() {
    assert_file_contains "$ROOT_DIR/stacks/databases/.env.example" "POSTGRES_BACKUP_PASSWORD"
    assert_file_contains "$ROOT_DIR/stacks/databases/.env.example" "MARIADB_BACKUP_PASSWORD"
}

# Run tests
tests=(
    test_postgres_running
    test_redis_running
    test_mariadb_running
    test_phpmyadmin_running
    test_postgres_healthy
    test_mariadb_healthy
    test_phpmyadmin_http
    test_compose_syntax
    test_no_latest_tags
    test_backup_scripts_exist
    test_env_example_has_backup_vars
)

for test in "${tests[@]}"; do
    $test
done

summary
