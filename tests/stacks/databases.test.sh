#!/bin/bash
# =============================================================================
# Databases Stack Tests — HomeLab Stack
# =============================================================================
# Tests: PostgreSQL, Redis, MariaDB, pgAdmin, Redis Commander
# Level: 1 (container health) + 2 (HTTP endpoints) + 5 (config)
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

suite_start "Databases Stack"

# Level 1 — Container Health
test_postgres_running()     { assert_container_running "homelab-postgres"; }
test_redis_running()        { assert_container_running "homelab-redis"; }
test_mariadb_running()      { assert_container_running "homelab-mariadb"; }
test_pgadmin_running()      { assert_container_running "homelab-pgadmin" || true; }
test_redis_commander_running() { assert_container_running "homelab-redis-commander" || true; }

# Level 1 — Health Check
test_postgres_healthy()     { assert_container_healthy "homelab-postgres" 60; }
test_mariadb_healthy()      { assert_container_healthy "homelab-mariadb" 60; }

# Level 2 — HTTP Endpoints
test_pgadmin_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://localhost:8081/" 20 || true
    else
        assert_http_200 "http://pgadmin.${domain}" 20
    fi
}

test_redis_commander_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://localhost:8082/" 20 || true
    else
        assert_http_200 "http://redis-commander.${domain}" 20
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

test_init_script_exists() {
    assert_file_contains "$ROOT_DIR/scripts/init-databases.sh" "#!/bin/bash"
    assert_file_contains "$ROOT_DIR/scripts/init-databases.sh" "create_pg_db"
}

test_backup_combined_script_exists() {
    assert_file_contains "$ROOT_DIR/scripts/backup-databases.sh" "backup_postgres"
}

test_env_example_has_pgadmin_vars() {
    assert_file_contains "$ROOT_DIR/stacks/databases/.env.example" "PGADMIN_EMAIL"
    assert_file_contains "$ROOT_DIR/stacks/databases/.env.example" "PGADMIN_PASSWORD"
}

# Run tests
tests=(
    test_postgres_running
    test_redis_running
    test_mariadb_running
    test_pgadmin_running
    test_redis_commander_running
    test_postgres_healthy
    test_mariadb_healthy
    test_pgadmin_http
    test_redis_commander_http
    test_compose_syntax
    test_no_latest_tags
    test_backup_scripts_exist
    test_init_script_exists
    test_backup_combined_script_exists
    test_env_example_has_pgadmin_vars
)

for test in "${tests[@]}"; do
    $test
done

summary
