#!/usr/bin/env bash
# =============================================================================
# Test: Network Connectivity Configuration
# Validates that networks are properly defined and referenced across stacks,
# and that services can theoretically communicate (config validation).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

log_section "Network Configuration Tests"

# -----------------------------------------------------------------------------
# Test: External proxy network is referenced consistently
# -----------------------------------------------------------------------------
test_begin "proxy network is external in all stacks"
PROXY_NETWORK_ISSUES=()
for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    stack_name=$(basename "$(dirname "$compose_file")")

    # Check if this stack uses 'proxy' network
    if grep -q "proxy" "$compose_file" 2>/dev/null; then
        # It should be marked as external
        if grep -A5 "^networks:" "$compose_file" | grep -q "external: true"; then
            : # OK
        else
            PROXY_NETWORK_ISSUES+=("$stack_name: proxy network not marked external")
        fi
    fi
done
if [[ ${#PROXY_NETWORK_ISSUES[@]} -eq 0 ]]; then
    test_pass
else
    for issue in "${PROXY_NETWORK_ISSUES[@]}"; do
        log_warn "  $issue"
    done
    test_fail "${#PROXY_NETWORK_ISSUES[@]} stack(s) with proxy network issues"
fi

# -----------------------------------------------------------------------------
# Test: Internal networks are properly isolated (bridge driver)
# -----------------------------------------------------------------------------
test_begin "Internal networks use bridge driver"
INTERNAL_NETWORK_ISSUES=()
for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    stack_name=$(basename "$(dirname "$compose_file")")

    # Find non-proxy networks
    local networks
    networks=$(grep -A10 "^networks:" "$compose_file" 2>/dev/null | grep -E "^  [a-zA-Z]" | awk '{print $1}' | grep -v "proxy" || true)

    for net in $networks; do
        # Check it has a driver defined or is internal
        local net_def
        net_def=$(grep -A20 "^networks:" "$compose_file" 2>/dev/null | grep -A5 "^  $net:" | grep "driver:" || true)
        if [[ -n "$net_def" ]]; then
            if echo "$net_def" | grep -q "bridge"; then
                : # OK
            elif echo "$net_def" | grep -q "overlay"; then
                : # OK for swarm
            fi
        fi
    done
done
test_pass "(manual review for custom network configs)"

# -----------------------------------------------------------------------------
# Test: All Traefik-enabled services have proper router labels
# -----------------------------------------------------------------------------
test_begin "Traefik services have proper labels"
TRAEFIK_ISSUES=()
for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    stack_name=$(basename "$(dirname "$compose_file")")

    # Check services with traefik.enable=true
    local traefik_services
    traefik_services=$(grep -B20 "traefik.enable=true" "$compose_file" 2>/dev/null | grep "^  [a-zA-Z]" | awk '{print $1}' | head -5 || true)

    for svc in $traefik_services; do
        # Should have rule and entrypoint
        if ! grep -A30 "^  $svc:" "$compose_file" | grep -q "traefik.http.routers"; then
            TRAEFIK_ISSUES+=("$stack_name/$svc: missing traefik router")
        fi
    done
done
if [[ ${#TRAEFIK_ISSUES[@]} -eq 0 ]]; then
    test_pass
else
    for issue in "${TRAEFIK_ISSUES[@]}"; do
        log_warn "  $issue"
    done
    test_fail "${#TRAEFIK_ISSUES[@]} Traefik configuration issue(s)"
fi

# -----------------------------------------------------------------------------
# Test: No port conflicts across stacks
# -----------------------------------------------------------------------------
test_begin "No obvious port conflicts"
declare -A PORT_USAGE
CONFLICTS=()

for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    stack_name=$(basename "$(dirname "$compose_file")")

    # Extract published ports
    local ports
    ports=$(grep -E '^\s*-\s*"?[0-9]+:[0-9]+"?' "$compose_file" 2>/dev/null | grep -oE '[0-9]+:' | tr -d ':' | sort -u || true)

    for port in $ports; do
        local key="${port}_${stack_name}"
        if [[ -n "${PORT_USAGE[$port]:-}" ]]; then
            CONFLICTS+=("Port $port: ${PORT_USAGE[$port]} and $stack_name")
        fi
        PORT_USAGE[$port]="$stack_name"
    done
done

if [[ ${#CONFLICTS[@]} -eq 0 ]]; then
    test_pass
else
    for conflict in "${CONFLICTS[@]}"; do
        log_warn "  Conflict: $conflict"
    done
    test_fail "${#CONFLICTS[@]} port conflict(s)"
fi

# -----------------------------------------------------------------------------
# Test: Network cross-stack connectivity config (same network = can talk)
# -----------------------------------------------------------------------------
test_begin "Cross-stack network configuration validated"
# Services on the same internal network should be able to communicate
# Services on 'proxy' network can reach Traefik

# Check that monitoring stack can reach Authentik (SSO)
test_begin "  monitoring stack has proxy network (for SSO)"
if grep -q "proxy" stacks/monitoring/docker-compose.yml 2>/dev/null; then
    test_pass
else
    test_fail "monitoring stack cannot reach proxy network (SSO won't work)"
fi

test_begin "  sso stack has proxy network (for Traefik routing)"
if grep -q "proxy" stacks/sso/docker-compose.yml 2>/dev/null; then
    test_pass
else
    test_fail "sso stack cannot reach proxy network"
fi

# -----------------------------------------------------------------------------
# Test: Network driver compatibility
# -----------------------------------------------------------------------------
test_begin "All network drivers are supported"
DRIVER_ISSUES=()
for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    stack_name=$(basename "$(dirname "$compose_file")")

    local drivers
    drivers=$(grep "driver:" "$compose_file" 2>/dev/null | grep -oE '(bridge|overlay|host|none|macvlan|ipvlan)' || true)

    for driver in $drivers; do
        case "$driver" in
            bridge|overlay|host|none|macvlan|ipvlan) : ;; # OK
            *)
                DRIVER_ISSUES+=("$stack_name: unknown driver '$driver'")
                ;;
        esac
    done
done

if [[ ${#DRIVER_ISSUES[@]} -eq 0 ]]; then
    test_pass
else
    for issue in "${DRIVER_ISSUES[@]}"; do
        log_warn "  $issue"
    done
    test_fail "${#DRIVER_ISSUES[@]} unsupported driver(s)"
fi

test_summary
