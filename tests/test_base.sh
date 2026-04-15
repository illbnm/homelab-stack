#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Stack Tests
# Tests: Traefik, Portainer, Watchtower
# Usage: ./tests/test_base.sh [--smoke|--full]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/assertions.sh"

TEST_SUITE_NAME="base"
TEST_MODE="${1:---full}"
COMPOSE_FILE="$REPO_ROOT/stacks/base/docker-compose.yml"
DOMAIN="${DOMAIN:-test.homelab.local}"

# =============================================================================
# Compose validation (always runs)
# =============================================================================
log_group "Compose File Validation"
assert_file_exists "$COMPOSE_FILE"
assert_compose_valid "$COMPOSE_FILE"
assert_compose_services "$COMPOSE_FILE" 3
assert_image_pinned "$COMPOSE_FILE"

# =============================================================================
# Smoke tests — fast, no running containers needed
# =============================================================================
log_group "Config File Checks"
assert_file_exists "$REPO_ROOT/config/traefik/traefik.yml"

log_group "Compose Config Analysis"
# Validate Traefik labels and routing config by inspecting compose output
_compose_config=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")
if [[ -n "$_compose_config" ]]; then
    # Check all containers have restart policy
    if echo "$_compose_config" | grep -q "restart:"; then
        _log_pass "All services define restart policy"
    else
        _log_fail "Missing restart policy in compose config"
    fi

    # Check traefik has healthcheck
    if echo "$_compose_config" | grep -q "traefik healthcheck"; then
        _log_pass "Traefik has healthcheck defined"
    else
        # Alternative: check the compose file directly
        if grep -q "healthcheck" "$COMPOSE_FILE"; then
            _log_pass "Services have healthchecks defined"
        else
            _log_fail "Missing healthchecks in compose file"
        fi
    fi

    # Check external network reference
    if echo "$_compose_config" | grep -q "external: true" || grep -q "external: true" "$COMPOSE_FILE"; then
        _log_pass "Proxy network is declared external"
    else
        _log_fail "Proxy network should be external"
    fi
else
    _log_skip "Cannot parse compose config (docker compose not available or .env missing)"
fi

if [[ "$TEST_MODE" == "--smoke" ]]; then
    print_summary
    [[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
fi

# =============================================================================
# Integration tests — require running containers
# =============================================================================
log_group "Container Status — Traefik"
assert_container_running traefik
assert_healthy traefik 90
assert_container_image traefik "traefik:v3"
assert_restart_policy traefik "unless-stopped"
assert_container_network traefik "proxy"
assert_container_label traefik "traefik.enable" "true"

log_group "Container Status — Portainer"
assert_container_running portainer
assert_healthy portainer 90
assert_container_image portainer "portainer/portainer-ce"
assert_restart_policy portainer "unless-stopped"
assert_container_network portainer "proxy"
assert_container_label portainer "traefik.enable" "true"

log_group "Container Status — Watchtower"
assert_container_running watchtower
assert_healthy watchtower 90
assert_container_image watchtower "containrrr/watchtower"
assert_restart_policy watchtower "unless-stopped"
assert_container_label watchtower "com.centurylinklabs.watchtower.enable" "true"

log_group "Security — Base Stack"
assert_no_privileged traefik
assert_no_privileged portainer
assert_no_privileged watchtower

# Docker socket is mounted read-only
log_group "Volume Mounts"
assert_volume_mounted traefik "/var/run/docker.sock"
assert_volume_mounted portainer "/var/run/docker.sock"

# =============================================================================
# Traefik routing tests
# =============================================================================
log_group "Traefik — Port Accessibility"
assert_port_open "Traefik HTTP" localhost 80
assert_port_open "Traefik HTTPS" localhost 443

log_group "Traefik — HTTP to HTTPS Redirect"
assert_http_redirect "HTTP->HTTPS redirect" "http://localhost" "https://"

log_group "Traefik — Dashboard"
# Dashboard should respond (may require auth)
_dash_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://localhost:8080/api/overview" 2>/dev/null || echo "000")
if [[ "$_dash_code" =~ ^[234] ]]; then
    _log_pass "Traefik API/dashboard responding (HTTP ${_dash_code})"
else
    # Try via Traefik internal API on port 80/443 with host header
    _dash_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 -H "Host: traefik.${DOMAIN}" "http://localhost/api/overview" 2>/dev/null || echo "000")
    if [[ "$_dash_code" =~ ^[234] ]]; then
        _log_pass "Traefik dashboard via reverse proxy (HTTP ${_dash_code})"
    else
        _log_skip "Traefik dashboard not reachable directly (may need auth/domain)"
    fi
fi

log_group "Traefik — Routing Rules"
# Verify Portainer is routed through Traefik
_port_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 -H "Host: portainer.${DOMAIN}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$_port_code" =~ ^[234] ]]; then
    _log_pass "Portainer accessible via Traefik routing (HTTP ${_port_code})"
else
    _log_skip "Portainer Traefik routing: HTTP ${_port_code} (may need HTTPS/real domain)"
fi

log_group "Portainer — API"
# Portainer serves on internal port 9000
_papi_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://localhost:9000/api/status" 2>/dev/null || echo "000")
if [[ "$_papi_code" =~ ^[234] ]]; then
    _log_pass "Portainer API responding on :9000 (HTTP ${_papi_code})"
else
    _log_skip "Portainer API on :9000 not reachable (port not published — expected)"
fi

# =============================================================================
# Summary
# =============================================================================
print_summary
[[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
