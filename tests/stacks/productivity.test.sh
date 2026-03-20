#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Productivity Tests
# Services: Gitea, Vaultwarden, Outline, BookStack
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/productivity/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Productivity — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Productivity — Container Health"

  assert_container_running "gitea"
  assert_container_healthy "gitea"
  assert_container_not_restarting "gitea"

  assert_container_running "vaultwarden"
  assert_container_healthy "vaultwarden"
  assert_container_not_restarting "vaultwarden"

  assert_container_running "outline"
  assert_container_healthy "outline"
  assert_container_not_restarting "outline"

  assert_container_running "bookstack"
  assert_container_healthy "bookstack"
  assert_container_not_restarting "bookstack"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Productivity — HTTP Endpoints"

  # Gitea API
  assert_http_ok "http://localhost:3001/api/v1/version" \
    "Gitea /api/v1/version"

  # Vaultwarden alive check
  assert_http_200 "http://localhost:8080/alive" \
    "Vaultwarden /alive"

  # Outline health
  assert_http_ok "http://localhost:3000/_health" \
    "Outline /_health"

  # BookStack login page
  assert_http_ok "http://localhost:80/login" \
    "BookStack /login"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Productivity — Interconnection"

  assert_container_in_network "gitea" "proxy"
  assert_container_in_network "gitea" "databases"
  assert_container_in_network "vaultwarden" "databases"
  assert_container_in_network "outline" "databases"
  assert_container_in_network "bookstack" "databases"

  # Gitea → PostgreSQL
  if is_container_running "gitea" && is_container_running "homelab-postgres"; then
    assert_docker_exec "gitea" \
      "Gitea can reach PostgreSQL" \
      bash -c "echo QUIT | nc -w3 homelab-postgres 5432"
  else
    skip_test "Gitea can reach PostgreSQL" "gitea or postgres not running"
  fi

  # BookStack → MariaDB
  if is_container_running "bookstack" && is_container_running "homelab-mariadb"; then
    assert_docker_exec "bookstack" \
      "BookStack can reach MariaDB" \
      bash -c "echo QUIT | nc -w3 homelab-mariadb 3306"
  else
    skip_test "BookStack can reach MariaDB" "bookstack or mariadb not running"
  fi

  # Outline → Redis
  if is_container_running "outline" && is_container_running "homelab-redis"; then
    assert_docker_exec "outline" \
      "Outline can reach Redis" \
      bash -c "echo PING | nc -w3 homelab-redis 6379"
  else
    skip_test "Outline can reach Redis" "outline or redis not running"
  fi
fi
