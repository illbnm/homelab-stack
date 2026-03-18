#!/usr/bin/env bash
# =============================================================================
# Base Stack Tests — Traefik + Portainer + Watchtower + Socket Proxy
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

test_base_socket_proxy_running() {
  assert_container_running "socket-proxy"
}

test_base_socket_proxy_healthy() {
  assert_container_healthy "socket-proxy" 30
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

# --- Level 2: HTTP Endpoints ---

test_base_traefik_api() {
  assert_http_200 "http://localhost:8080/api/version" 10
}

test_base_portainer_http() {
  assert_http_200 "http://localhost:9000" 15
}

# --- Level 3: Service Integration ---

test_base_traefik_uses_socket_proxy() {
  # Traefik should connect to socket-proxy, not mount docker.sock directly
  local volumes
  volumes=$(docker inspect --format='{{range .Mounts}}{{.Source}} {{end}}' traefik 2>/dev/null)
  if echo "${volumes}" | grep -q "docker.sock"; then
    _fail "Traefik mounts docker.sock directly (should use socket-proxy)"
  else
    _pass
  fi
}

test_base_socket_proxy_network_internal() {
  # Socket proxy network should not be the proxy network
  assert_container_not_on_network "socket-proxy" "proxy"
}

test_base_http_redirect() {
  # HTTP should redirect to HTTPS (301/308)
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:80/" 2>/dev/null) || true
  if [[ "${code}" == "301" || "${code}" == "308" || "${code}" == "302" || "${code}" == "307" ]]; then
    _pass
  else
    _fail "Expected HTTP redirect (301/308), got ${code:-timeout}"
  fi
}
