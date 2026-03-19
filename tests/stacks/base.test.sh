#!/usr/bin/env bash
# =============================================================================
# tests/stacks/base.test.sh — Base Infrastructure (Traefik + Portainer + Watchtower)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
BASE_STACK="$SCRIPT_DIR/stacks/base/docker-compose.yml"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

# ---- Traefik Tests ----

test_traefik_running() {
  assert_container_running "traefik"
}

test_traefik_healthy() {
  assert_container_healthy "traefik" 60
}

test_traefik_api_version() {
  local code
  code=$(http_status "http://localhost:80/api/version" 5)
  assert_eq "$code" "200"
}

test_traefik_dashboard_reachable() {
  assert_http_200 "http://localhost:80/api/overview" 10
}

# ---- Portainer Tests ----

test_portainer_running() {
  assert_container_running "portainer"
}

test_portainer_http() {
  local code
  code=$(http_status "http://localhost:9000/api/status" 10)
  # May return 200 or redirect
  assert_contains "200 302 401" "$code"
}

# ---- Watchtower Tests ----

test_watchtower_running() {
  assert_container_running "watchtower"
}

test_watchtower_logs() {
  local logs
  logs=$(docker_get_logs "watchtower" 10)
  assert_not_empty "$logs"
}

# ---- Network Tests ----

test_proxy_network_exists() {
  if docker network inspect proxy &>/dev/null; then
    return 0
  else
    echo "Proxy network does not exist"
    return 1
  fi
}

# ---- Config Tests ----

test_compose_valid() {
  assert_compose_valid "$BASE_STACK"
}

test_acme_json_exists() {
  assert_file_exists "$SCRIPT_DIR/config/traefik/acme.json"
}

test_acme_json_permissions() {
  local perms
  perms=$(stat -c '%a' "$SCRIPT_DIR/config/traefik/acme.json" 2>/dev/null || echo "unknown")
  assert_eq "$perms" "600"
}

# ---- Environment Tests ----

test_env_file_exists() {
  assert_file_exists "$SCRIPT_DIR/.env"
}

test_env_domain_set() {
  local domain
  domain=$(grep "^DOMAIN=" "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "")
  assert_not_empty "$domain" "DOMAIN must be set in .env"
}

# ---- Port Tests ----

test_port_80_available() {
  assert_http_200 "http://localhost:80" 5
}

test_port_443_available() {
  local code
  code=$(curl -sk --connect-timeout 5 -o /dev/null -w '%{http_code}' "https://localhost:443" 2>/dev/null || echo "000")
  # May redirect or 404, but port should be open
  assert_contains "200 301 302 404" "$code"
}
