#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Infrastructure Tests
# Tests: Traefik + Portainer + Watchtower
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Skip if base not selected
should_run_stack "base" || { begin_suite "Base Infrastructure"; assert_skip "not selected"; exit 0; }

begin_suite "Base Infrastructure — Traefik + Portainer + Watchtower"

# ---- Traefik ----
assert_container_running "traefik"
assert_container_healthy "traefik"
assert_container_not_latest "traefik"
assert_container_restart_policy "traefik"
assert_port_open "localhost" "80" "http"
assert_port_open "localhost" "443" "https"
assert_http_200 "${BASE_URL:-http://localhost}:80" "traefik:80"

# Traefik API endpoint
begin_test "traefik:api:version"
local_ver=$(curl -sf --connect-timeout 5 "${BASE_URL:-http://localhost}:80/api/version" 2>/dev/null || echo "")
if [[ -n "$local_ver" ]]; then
  assert_pass "API reachable"
else
  assert_skip "API not exposed (dashboard may require auth)"
fi

# ---- Portainer ----
assert_container_running "portainer"
assert_container_healthy "portainer"
assert_container_not_latest "portainer"
assert_container_restart_policy "portainer"
assert_http_200 "${BASE_URL:-http://localhost}:9000/api/status" "portainer:api"

# ---- Watchtower ----
assert_container_running "watchtower"
assert_container_not_latest "watchtower"
assert_container_restart_policy "watchtower"

# ---- Network ----
assert_network_exists "proxy"
assert_container_in_network "traefik" "proxy"
assert_container_in_network "portainer" "proxy"

# ---- Volumes ----
assert_volume_exists "portainer-data"

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/base/docker-compose.yml" "base"
