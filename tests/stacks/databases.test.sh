#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Databases Stack Tests
# =============================================================================
# Tests: PostgreSQL, Redis, MariaDB, pgAdmin, Redis Commander
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_postgres_running() {
  assert_container_running "homelab-postgres"
}

test_postgres_healthy() {
  assert_container_healthy "homelab-postgres" 60
}

test_redis_running() {
  assert_container_running "homelab-redis"
}

test_redis_healthy() {
  assert_container_healthy "homelab-redis" 60
}

test_mariadb_running() {
  assert_container_running "homelab-mariadb"
}

test_mariadb_healthy() {
  assert_container_healthy "homelab-mariadb" 60
}

test_pgadmin_running() {
  assert_container_running "homelab-pgadmin"
}

test_pgadmin_healthy() {
  assert_container_healthy "homelab-pgadmin" 90
}

test_redis_commander_running() {
  assert_container_running "homelab-redis-commander"
}

test_redis_commander_healthy() {
  assert_container_healthy "homelab-redis-commander" 60
}

# ---------------------------------------------------------------------------
# Level 1 — Network Isolation
# ---------------------------------------------------------------------------

test_postgres_no_host_ports() {
  assert_no_host_ports "homelab-postgres"
}

test_redis_no_host_ports() {
  assert_no_host_ports "homelab-redis"
}

test_mariadb_no_host_ports() {
  assert_no_host_ports "homelab-mariadb"
}

test_postgres_on_internal_network() {
  assert_container_on_network "homelab-postgres" "internal"
}

test_postgres_not_on_proxy_network() {
  assert_container_not_on_network "homelab-postgres" "proxy"
}

test_redis_on_internal_network() {
  assert_container_on_network "homelab-redis" "internal"
}

test_redis_not_on_proxy_network() {
  assert_container_not_on_network "homelab-redis" "proxy"
}

test_mariadb_on_internal_network() {
  assert_container_on_network "homelab-mariadb" "internal"
}

test_mariadb_not_on_proxy_network() {
  assert_container_not_on_network "homelab-mariadb" "proxy"
}

test_pgadmin_on_both_networks() {
  assert_container_on_network "homelab-pgadmin" "internal"
  assert_container_on_network "homelab-pgadmin" "proxy"
}

test_redis_commander_on_both_networks() {
  assert_container_on_network "homelab-redis-commander" "internal"
  assert_container_on_network "homelab-redis-commander" "proxy"
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints (Management UIs)
# ---------------------------------------------------------------------------

test_pgadmin_webui() {
  # pgAdmin runs inside the container on port 80, accessed via Traefik.
  # For direct testing, use docker exec.
  local result
  result=$(docker exec homelab-pgadmin wget -q --spider http://localhost:80/misc/ping 2>&1 && echo "OK" || echo "FAIL")

  if [[ "${result}" == *"OK"* ]]; then
    _assert_pass "pgAdmin web UI is accessible"
  else
    _assert_fail "pgAdmin web UI is not accessible"
  fi
}

test_redis_commander_webui() {
  local result
  result=$(docker exec homelab-redis-commander wget -q --spider http://localhost:8081/ 2>&1 && echo "OK" || echo "FAIL")

  if [[ "${result}" == *"OK"* ]]; then
    _assert_pass "Redis Commander web UI is accessible"
  else
    _assert_fail "Redis Commander web UI is not accessible"
  fi
}

# ---------------------------------------------------------------------------
# Level 3 — PostgreSQL Multi-Tenant Databases
# ---------------------------------------------------------------------------

test_postgres_database_nextcloud() {
  local result
  result=$(docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'nextcloud'" 2>/dev/null || echo "")

  if echo "${result}" | grep -q "1"; then
    _assert_pass "PostgreSQL database 'nextcloud' exists"
  else
    _assert_fail "PostgreSQL database 'nextcloud' not found"
  fi
}

test_postgres_database_gitea() {
  local result
  result=$(docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'gitea'" 2>/dev/null || echo "")

  if echo "${result}" | grep -q "1"; then
    _assert_pass "PostgreSQL database 'gitea' exists"
  else
    _assert_fail "PostgreSQL database 'gitea' not found"
  fi
}

test_postgres_database_outline() {
  local result
  result=$(docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'outline'" 2>/dev/null || echo "")

  if echo "${result}" | grep -q "1"; then
    _assert_pass "PostgreSQL database 'outline' exists"
  else
    _assert_fail "PostgreSQL database 'outline' not found"
  fi
}

test_postgres_database_authentik() {
  local result
  result=$(docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'authentik'" 2>/dev/null || echo "")

  if echo "${result}" | grep -q "1"; then
    _assert_pass "PostgreSQL database 'authentik' exists"
  else
    _assert_fail "PostgreSQL database 'authentik' not found"
  fi
}

test_postgres_database_grafana() {
  local result
  result=$(docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = 'grafana'" 2>/dev/null || echo "")

  if echo "${result}" | grep -q "1"; then
    _assert_pass "PostgreSQL database 'grafana' exists"
  else
    _assert_fail "PostgreSQL database 'grafana' not found"
  fi
}

# PostgreSQL users
test_postgres_users_exist() {
  local all_exist=true

  for user in nextcloud gitea outline authentik grafana; do
    local result
    result=$(docker exec homelab-postgres psql -U postgres -tAc \
      "SELECT 1 FROM pg_roles WHERE rolname = '${user}'" 2>/dev/null || echo "")

    if ! echo "${result}" | grep -q "1"; then
      _assert_fail "PostgreSQL user '${user}' not found"
      all_exist=false
    fi
  done

  if [[ "${all_exist}" == true ]]; then
    _assert_pass "All PostgreSQL users exist (nextcloud, gitea, outline, authentik, grafana)"
  fi
}

# PostgreSQL connectivity per user
test_postgres_user_nextcloud_connects() {
  local pw="${NEXTCLOUD_DB_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "NEXTCLOUD_DB_PASSWORD not set"
    return 0
  fi

  if docker exec -e PGPASSWORD="${pw}" homelab-postgres \
    psql -U nextcloud -d nextcloud -c "SELECT 1;" &>/dev/null; then
    _assert_pass "User 'nextcloud' can connect to database 'nextcloud'"
  else
    _assert_fail "User 'nextcloud' cannot connect to database 'nextcloud'"
  fi
}

test_postgres_user_gitea_connects() {
  local pw="${GITEA_DB_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "GITEA_DB_PASSWORD not set"
    return 0
  fi

  if docker exec -e PGPASSWORD="${pw}" homelab-postgres \
    psql -U gitea -d gitea -c "SELECT 1;" &>/dev/null; then
    _assert_pass "User 'gitea' can connect to database 'gitea'"
  else
    _assert_fail "User 'gitea' cannot connect to database 'gitea'"
  fi
}

# ---------------------------------------------------------------------------
# Level 3 — Redis Multi-DB
# ---------------------------------------------------------------------------

test_redis_ping() {
  local pw="${REDIS_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "REDIS_PASSWORD not set"
    return 0
  fi

  local result
  result=$(docker exec homelab-redis redis-cli -a "${pw}" ping 2>/dev/null || echo "")

  if echo "${result}" | grep -q "PONG"; then
    _assert_pass "Redis responds to PING"
  else
    _assert_fail "Redis does not respond to PING"
  fi
}

test_redis_db0_accessible() {
  local pw="${REDIS_PASSWORD:-}"
  [[ -z "${pw}" ]] && { _assert_skip "REDIS_PASSWORD not set"; return 0; }

  if docker exec homelab-redis redis-cli -a "${pw}" -n 0 \
    SET "homelab_test_0" "ok" EX 5 &>/dev/null; then
    docker exec homelab-redis redis-cli -a "${pw}" -n 0 DEL "homelab_test_0" &>/dev/null || true
    _assert_pass "Redis DB 0 (Authentik) is accessible"
  else
    _assert_fail "Redis DB 0 is not accessible"
  fi
}

test_redis_db1_accessible() {
  local pw="${REDIS_PASSWORD:-}"
  [[ -z "${pw}" ]] && { _assert_skip "REDIS_PASSWORD not set"; return 0; }

  if docker exec homelab-redis redis-cli -a "${pw}" -n 1 \
    SET "homelab_test_1" "ok" EX 5 &>/dev/null; then
    docker exec homelab-redis redis-cli -a "${pw}" -n 1 DEL "homelab_test_1" &>/dev/null || true
    _assert_pass "Redis DB 1 (Outline) is accessible"
  else
    _assert_fail "Redis DB 1 is not accessible"
  fi
}

test_redis_db2_accessible() {
  local pw="${REDIS_PASSWORD:-}"
  [[ -z "${pw}" ]] && { _assert_skip "REDIS_PASSWORD not set"; return 0; }

  if docker exec homelab-redis redis-cli -a "${pw}" -n 2 \
    SET "homelab_test_2" "ok" EX 5 &>/dev/null; then
    docker exec homelab-redis redis-cli -a "${pw}" -n 2 DEL "homelab_test_2" &>/dev/null || true
    _assert_pass "Redis DB 2 (Gitea) is accessible"
  else
    _assert_fail "Redis DB 2 is not accessible"
  fi
}

test_redis_db3_accessible() {
  local pw="${REDIS_PASSWORD:-}"
  [[ -z "${pw}" ]] && { _assert_skip "REDIS_PASSWORD not set"; return 0; }

  if docker exec homelab-redis redis-cli -a "${pw}" -n 3 \
    SET "homelab_test_3" "ok" EX 5 &>/dev/null; then
    docker exec homelab-redis redis-cli -a "${pw}" -n 3 DEL "homelab_test_3" &>/dev/null || true
    _assert_pass "Redis DB 3 (Nextcloud) is accessible"
  else
    _assert_fail "Redis DB 3 is not accessible"
  fi
}

test_redis_db4_accessible() {
  local pw="${REDIS_PASSWORD:-}"
  [[ -z "${pw}" ]] && { _assert_skip "REDIS_PASSWORD not set"; return 0; }

  if docker exec homelab-redis redis-cli -a "${pw}" -n 4 \
    SET "homelab_test_4" "ok" EX 5 &>/dev/null; then
    docker exec homelab-redis redis-cli -a "${pw}" -n 4 DEL "homelab_test_4" &>/dev/null || true
    _assert_pass "Redis DB 4 (Grafana sessions) is accessible"
  else
    _assert_fail "Redis DB 4 is not accessible"
  fi
}

# ---------------------------------------------------------------------------
# Level 3 — MariaDB
# ---------------------------------------------------------------------------

test_mariadb_root_login() {
  local pw="${MARIADB_ROOT_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "MARIADB_ROOT_PASSWORD not set"
    return 0
  fi

  if docker exec homelab-mariadb mysql -u root -p"${pw}" \
    -e "SELECT 1;" &>/dev/null; then
    _assert_pass "MariaDB root login works"
  else
    _assert_fail "MariaDB root login failed"
  fi
}

test_mariadb_nextcloud_db_exists() {
  local pw="${MARIADB_ROOT_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "MARIADB_ROOT_PASSWORD not set"
    return 0
  fi

  if docker exec homelab-mariadb mysql -u root -p"${pw}" \
    -e "SHOW DATABASES;" 2>/dev/null | grep -q "nextcloud"; then
    _assert_pass "MariaDB database 'nextcloud' exists"
  else
    _assert_fail "MariaDB database 'nextcloud' not found"
  fi
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_databases_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/databases/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Databases compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}

test_databases_no_latest_tags() {
  local compose_file="${PROJECT_ROOT}/stacks/databases/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Databases compose file not found"
    return 0
  fi

  assert_no_latest_images "${PROJECT_ROOT}/stacks/databases"
}

test_databases_init_script_exists() {
  local script="${PROJECT_ROOT}/stacks/databases/scripts/init-databases.sh"

  if [[ -f "${script}" ]]; then
    _assert_pass "init-databases.sh exists"
  else
    _assert_skip "init-databases.sh not found"
  fi
}

test_databases_backup_script_exists() {
  local script="${PROJECT_ROOT}/stacks/databases/scripts/backup-databases.sh"

  if [[ -f "${script}" ]]; then
    _assert_pass "backup-databases.sh exists"
  else
    _assert_skip "backup-databases.sh not found"
  fi
}
