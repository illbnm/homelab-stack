#!/usr/bin/env bash
# =============================================================================
# productivity.test.sh — Productivity stack tests (gitea, vaultwarden, outline, bookstack)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Productivity — Containers"

test_gitea_running() {
  assert_container_running "gitea"
  assert_container_healthy "gitea"
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
  assert_container_healthy "vaultwarden"
}

test_outline_running() {
  assert_container_running "outline"
  assert_container_healthy "outline"
}

test_bookstack_running() {
  assert_container_running "bookstack"
  assert_container_healthy "bookstack"
}

test_gitea_running
test_vaultwarden_running
test_outline_running
test_bookstack_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Productivity — HTTP Endpoints"

  test_gitea_api() {
    assert_http_200 "http://localhost:3000/api/v1/version" "Gitea /api/v1/version"
  }

  test_vaultwarden_health() {
    assert_http_200 "http://localhost:80/alive" "Vaultwarden /alive"
  }

  test_outline_health() {
    assert_http_200 "http://localhost:3000/_health" "Outline /_health"
  }

  test_bookstack_ui() {
    assert_http_status "http://localhost:80/login" "200" "BookStack /login"
  }

  test_gitea_api
  test_vaultwarden_health
  test_outline_health
  test_bookstack_ui
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Productivity — Interconnection"

  test_gitea_db_connection() {
    local result
    result=$(docker_run_in "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt 2>/dev/null | grep -c "gitea" || echo "0")
    if [[ "$result" -gt 0 ]]; then
      test_pass "Gitea database exists in PostgreSQL"
    else
      test_skip "Gitea database check" "database not found"
    fi
  }

  test_vaultwarden_db_connection() {
    local result
    result=$(docker_run_in "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt 2>/dev/null | grep -c "vaultwarden" || echo "0")
    if [[ "$result" -gt 0 ]]; then
      test_pass "Vaultwarden database exists in PostgreSQL"
    else
      test_skip "Vaultwarden database check" "database not found"
    fi
  }

  test_outline_db_connection() {
    local result
    result=$(docker_run_in "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt 2>/dev/null | grep -c "outline" || echo "0")
    if [[ "$result" -gt 0 ]]; then
      test_pass "Outline database exists in PostgreSQL"
    else
      test_skip "Outline database check" "database not found"
    fi
  }

  test_gitea_db_connection
  test_vaultwarden_db_connection
  test_outline_db_connection
fi
