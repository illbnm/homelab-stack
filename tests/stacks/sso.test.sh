#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO (Authentik) Tests
# Services: authentik-server, authentik-worker, authentik-postgres, authentik-redis
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/sso/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "SSO — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "SSO — Container Health"

  assert_container_running "authentik-server"
  assert_container_healthy "authentik-server"
  assert_container_not_restarting "authentik-server"

  assert_container_running "authentik-worker"
  assert_container_not_restarting "authentik-worker"

  assert_container_running "authentik-postgres"
  assert_container_healthy "authentik-postgres"

  assert_container_running "authentik-redis"
  assert_container_healthy "authentik-redis"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "SSO — HTTP Endpoints"

  # Authentik server health
  assert_http_ok "http://localhost:9000/if/flow/default-authentication-flow/" \
    "Authentik authentication flow page"

  # Authentik API
  assert_http_ok "http://localhost:9000/-/health/live/" \
    "Authentik health live endpoint"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "SSO — Interconnection"

  assert_docker_network_exists "sso"
  assert_container_in_network "authentik-server" "sso"
  assert_container_in_network "authentik-server" "proxy"
  assert_container_in_network "authentik-postgres" "sso"
  assert_container_in_network "authentik-redis" "sso"

  # Authentik can reach its PostgreSQL
  assert_docker_exec "authentik-server" \
    "Authentik → PostgreSQL connectivity" \
    ak healthcheck

  # Verify OIDC discovery endpoint
  assert_http_ok "http://localhost:9000/application/o/.well-known/openid-configuration" \
    "Authentik OIDC discovery endpoint"
fi
