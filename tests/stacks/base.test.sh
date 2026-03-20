#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Infrastructure Tests
# Services: Traefik, Portainer, Watchtower
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/base/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Base — Configuration"

  assert_compose_valid "$COMPOSE_FILE"

  assert_file_exists "$BASE_DIR/config/traefik/traefik.yml" \
    "Traefik main config exists"

  assert_file_exists "$BASE_DIR/config/traefik/dynamic/middlewares.yml" \
    "Traefik dynamic middleware config exists"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Base — Container Health"

  assert_container_running "traefik"
  assert_container_healthy "traefik"
  assert_container_not_restarting "traefik"

  assert_container_running "portainer"
  assert_container_healthy "portainer"
  assert_container_not_restarting "portainer"

  assert_container_running "watchtower"
  assert_container_healthy "watchtower"
  assert_container_not_restarting "watchtower"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Base — HTTP Endpoints"

  # Traefik should be listening on 80 and 443
  assert_port_open "localhost" 80 "Traefik HTTP port 80"
  assert_port_open "localhost" 443 "Traefik HTTPS port 443"

  # Traefik API (requires dashboard enabled)
  assert_http_ok "http://localhost:8080/api/version" \
    "Traefik API /api/version"

  # Portainer
  assert_http_ok "http://localhost:9000" \
    "Portainer web UI"
  assert_http_ok "http://localhost:9000/api/status" \
    "Portainer API /api/status"
fi

# ===========================================================================
# Level 3 — Network & Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Base — Network"

  assert_docker_network_exists "proxy"
  assert_container_in_network "traefik" "proxy"
  assert_container_in_network "portainer" "proxy"
fi
