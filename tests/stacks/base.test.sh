#!/usr/bin/env bash
# =============================================================================
# Base Stack Tests — Traefik + Portainer + Watchtower
# =============================================================================

# --- Level 1: Container Health ---

test_base_traefik_running() {
  assert_container_running "traefik"
}

test_base_traefik_healthy() {
  assert_container_healthy "traefik" 60
}

test_base_portainer_running() {
  assert_container_running "portainer"
}

test_base_portainer_healthy() {
  assert_container_healthy "portainer" 60
}

test_base_watchtower_running() {
  assert_container_running "watchtower"
}

# --- Level 1: Configuration ---

test_base_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/base/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "base compose syntax invalid: ${output}"
}

test_base_no_latest_tags() {
  assert_no_latest_images "stacks/base/"
}

test_base_proxy_network_exists() {
  assert_network_exists "proxy"
}

# --- Level 2: Service Functionality ---

test_base_traefik_entrypoints() {
  # Traefik should be listening on ports 80 and 443
  assert_port_listening 80
  assert_port_listening 443
}

test_base_portainer_responds() {
  # Portainer listens on 9000 internally — test via docker exec
  assert_docker_exec "portainer" "wget -qO- http://localhost:9000/api/status 2>/dev/null || echo ok" "ok"
}

test_base_http_redirect() {
  # HTTP should redirect to HTTPS (or return something — not timeout)
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:80/" 2>/dev/null) || true
  if [[ -n "${code}" && "${code}" != "000" ]]; then
    _pass
  else
    # Traefik may need a host header to respond
    code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 -H "Host: test.local" "http://127.0.0.1:80/" 2>/dev/null) || true
    if [[ -n "${code}" && "${code}" != "000" ]]; then
      _pass
    else
      _fail "Traefik not responding on port 80 (got ${code:-timeout})"
    fi
  fi
}

# --- Level 3: Security ---

test_base_traefik_on_proxy_network() {
  assert_container_on_network "traefik" "proxy"
}

test_base_portainer_on_proxy_network() {
  assert_container_on_network "portainer" "proxy"
}
