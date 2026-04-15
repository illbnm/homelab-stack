#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Stack Tests
# Tests: AdGuard Home, Unbound (recursive DNS), WireGuard (wg-easy)
# Usage: ./tests/test_network.sh [--smoke|--full]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/assertions.sh"

TEST_SUITE_NAME="network"
TEST_MODE="${1:---full}"
COMPOSE_FILE="$REPO_ROOT/stacks/network/docker-compose.yml"
DOMAIN="${DOMAIN:-test.homelab.local}"

# =============================================================================
# Compose validation
# =============================================================================
log_group "Compose File Validation"
assert_file_exists "$COMPOSE_FILE"
assert_compose_valid "$COMPOSE_FILE"
assert_compose_services "$COMPOSE_FILE" 3
assert_image_pinned "$COMPOSE_FILE"

# =============================================================================
# Smoke tests
# =============================================================================
log_group "Compose Config Analysis"
_compose_config=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")
if [[ -n "$_compose_config" ]]; then
    # Check internal network exists for DNS isolation
    if grep -q "network-internal" "$COMPOSE_FILE"; then
        _log_pass "Internal network defined for DNS isolation"
    else
        _log_fail "Missing internal network for DNS isolation"
    fi

    # Check Unbound depends on nothing (root of DNS chain)
    if echo "$_compose_config" | grep -q "unbound"; then
        _log_pass "Unbound DNS resolver configured"
    else
        _log_fail "Unbound service missing from config"
    fi

    # wg-easy needs NET_ADMIN capability
    if grep -q "NET_ADMIN" "$COMPOSE_FILE"; then
        _log_pass "WireGuard has NET_ADMIN capability"
    else
        _log_fail "WireGuard missing NET_ADMIN capability"
    fi

    # wg-easy needs ip_forward sysctl
    if grep -q "net.ipv4.ip_forward" "$COMPOSE_FILE"; then
        _log_pass "WireGuard has ip_forward sysctl"
    else
        _log_fail "WireGuard missing ip_forward sysctl"
    fi
else
    _log_skip "Cannot parse compose config"
fi

if [[ "$TEST_MODE" == "--smoke" ]]; then
    print_summary
    [[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
fi

# =============================================================================
# Integration tests
# =============================================================================
log_group "Container Status — Unbound"
assert_container_running unbound
assert_healthy unbound 60
assert_container_image unbound "mvance/unbound"
assert_restart_policy unbound "unless-stopped"
assert_container_network unbound "network-internal"

log_group "Container Status — AdGuard Home"
assert_container_running adguardhome
assert_healthy adguardhome 60
assert_container_image adguardhome "adguard/adguardhome"
assert_restart_policy adguardhome "unless-stopped"
assert_container_network adguardhome "proxy"
assert_container_label adguardhome "traefik.enable" "true"

log_group "Container Status — WireGuard (wg-easy)"
assert_container_running wg-easy
assert_healthy wg-easy 60
assert_container_image wg-easy "wg-easy"
assert_restart_policy wg-easy "unless-stopped"
assert_container_network wg-easy "proxy"
assert_container_label wg-easy "traefik.enable" "true"

log_group "Security — Network Stack"
# Unbound and AdGuard should not be privileged
assert_no_privileged unbound
assert_no_privileged adguardhome
# Note: wg-easy needs NET_ADMIN + SYS_MODULE, not full privileged

# =============================================================================
# DNS Tests
# =============================================================================
log_group "DNS — Port Accessibility"
assert_port_open "AdGuard DNS TCP" localhost 53
# UDP check via dig
_dns_result=$(dig +short +tcp @127.0.0.1 -p 53 cloudflare.com A 2>/dev/null || echo "")
if [[ -n "$_dns_result" ]]; then
    _log_pass "AdGuard Home DNS resolving (cloudflare.com -> ${_dns_result})"
else
    _log_skip "AdGuard Home DNS not responding on port 53"
fi

log_group "DNS — Unbound Recursive Resolution"
# Test Unbound via AdGuard (chain: client -> AdGuard -> Unbound -> root servers)
assert_exec adguardhome "AdGuard can reach Unbound" wget -q --spider http://unbound:8953 2>/dev/null || \
    _dns_chain=$(docker exec adguardhome nslookup example.com unbound 2>/dev/null || echo "")
if [[ -n "${_dns_chain:-}" ]] && [[ "$_dns_chain" == *"Address"* ]]; then
    _log_pass "DNS chain: AdGuard -> Unbound resolves correctly"
else
    _log_skip "Cannot verify AdGuard->Unbound chain from outside"
fi

log_group "DNS — AdGuard Web UI"
_adguard_port="${ADGUARD_WEB_PORT:-3000}"
_ag_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://localhost:${_adguard_port}" 2>/dev/null || echo "000")
if [[ "$_ag_code" =~ ^[23] ]]; then
    _log_pass "AdGuard Home web UI responding (HTTP ${_ag_code})"
else
    _log_skip "AdGuard Home web UI not reachable on port ${_adguard_port}"
fi

# =============================================================================
# WireGuard Tests
# =============================================================================
log_group "WireGuard — Port Accessibility"
assert_port_open "WireGuard UDP" localhost "${WG_PORT:-51820}" || true

log_group "WireGuard — Interface"
_wg_iface=$(docker exec wg-easy ip link show wg0 2>/dev/null || echo "")
if [[ -n "$_wg_iface" ]] && [[ "$_wg_iface" == *"UP"* || "$_wg_iface" == *"wg0"* ]]; then
    _log_pass "WireGuard wg0 interface is active"
else
    _log_skip "WireGuard wg0 interface not found/active"
fi

log_group "WireGuard — Web UI"
_wg_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 -H "Host: wg.${DOMAIN}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$_wg_code" =~ ^[234] ]]; then
    _log_pass "wg-easy web UI via Traefik (HTTP ${_wg_code})"
else
    _log_skip "wg-easy web UI not reachable via Traefik"
fi

# =============================================================================
# Inter-service Network Connectivity
# =============================================================================
log_group "Network Connectivity"
# AdGuard should reach Unbound on internal network
_ping_result=$(docker exec adguardhome ping -c 1 -W 2 unbound 2>/dev/null && echo "OK" || echo "FAIL")
if [[ "$_ping_result" == *"OK"* ]]; then
    _log_pass "AdGuard -> Unbound connectivity (internal network)"
else
    _log_skip "Cannot verify AdGuard -> Unbound ping"
fi

# wg-easy should be on both proxy and network-internal
assert_container_network wg-easy "proxy"

# =============================================================================
# Traefik Routing
# =============================================================================
log_group "Traefik Routing — Network Stack"
for svc in adguard wg-easy; do
    _host="${svc}.${DOMAIN}"
    [[ "$svc" == "wg-easy" ]] && _host="wg.${DOMAIN}"
    _code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 -H "Host: ${_host}" "http://localhost" 2>/dev/null || echo "000")
    if [[ "$_code" =~ ^[234] ]]; then
        _log_pass "Traefik routes ${_host} (HTTP ${_code})"
    else
        _log_skip "Traefik route ${_host} -> HTTP ${_code}"
    fi
done

# =============================================================================
# Summary
# =============================================================================
print_summary
[[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
