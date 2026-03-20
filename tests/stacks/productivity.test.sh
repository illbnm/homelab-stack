#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests — Gitea, Vaultwarden, Outline, BookStack
# =============================================================================

log_group "Productivity"

# --- Level 1: Container health ---

PRODUCTIVITY_CONTAINERS=(gitea vaultwarden outline bookstack)

for c in "${PRODUCTIVITY_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_gitea_http() {
    require_container "gitea" || return
    assert_http_ok "http://localhost:3000" "Gitea Web UI"
    assert_http_200 "http://localhost:3000/api/v1/version" "Gitea API /api/v1/version"
  }

  test_vaultwarden_http() {
    require_container "vaultwarden" || return
    assert_http_200 "http://localhost:80/alive" "Vaultwarden /alive"
  }

  test_outline_http() {
    require_container "outline" || return
    assert_http_ok "http://localhost:3000/_health" "Outline /_health"
  }

  test_bookstack_http() {
    require_container "bookstack" || return
    assert_http_ok "http://localhost:80/login" "BookStack /login"
  }

  test_gitea_http
  test_vaultwarden_http
  test_outline_http
  test_bookstack_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Gitea connects to shared PostgreSQL
  test_gitea_db_connection() {
    require_container "gitea" || return
    require_container "homelab-postgres" || return
    assert_container_on_network "gitea" "databases"
    # Verify Gitea can reach its database
    local result
    result=$(docker_exec "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -d gitea -c "SELECT 1;" 2>/dev/null)
    assert_contains "$result" "1" "Gitea database query succeeds"
  }

  # Vaultwarden connects to shared PostgreSQL
  test_vaultwarden_db_connection() {
    require_container "vaultwarden" || return
    require_container "homelab-postgres" || return
    assert_container_on_network "vaultwarden" "databases"
    local result
    result=$(docker_exec "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -d vaultwarden -c "SELECT 1;" 2>/dev/null)
    assert_contains "$result" "1" "Vaultwarden database query succeeds"
  }

  # Outline connects to shared PostgreSQL and Redis
  test_outline_db_connection() {
    require_container "outline" || return
    require_container "homelab-postgres" || return
    assert_container_on_network "outline" "databases"
    local result
    result=$(docker_exec "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -d outline -c "SELECT 1;" 2>/dev/null)
    assert_contains "$result" "1" "Outline database query succeeds"
  }

  # BookStack connects to shared MariaDB
  test_bookstack_db_connection() {
    require_container "bookstack" || return
    require_container "homelab-mariadb" || return
    assert_container_on_network "bookstack" "databases"
  }

  test_gitea_db_connection
  test_vaultwarden_db_connection
  test_outline_db_connection
  test_bookstack_db_connection
fi

# --- Image tags ---
for c in "${PRODUCTIVITY_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
