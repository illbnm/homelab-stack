#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Connectivity Checker
# Checks connectivity to Docker registries, GitHub, gcr.io, ghcr.io
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_ok()    { echo -e "  ${GREEN}[OK]${NC} $*"; }
log_slow()  { echo -e "  ${YELLOW}[SLOW]${NC} $*"; }
log_fail()  { echo -e "  ${RED}[FAIL]${NC} $*"; }
log_info()  { echo -e "  ${CYAN}[INFO]${NC} $*"; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }

# -----------------------------------------------------------------------------
# Test targets
# -----------------------------------------------------------------------------
declare -A TARGETS=(
    ["hub.docker.com"]="Docker Hub"
    ["github.com"]="GitHub"
    ["gcr.io"]="gcr.io"
    ["ghcr.io"]="ghcr.io"
    ["quay.io"]="quay.io"
    ["k8s.gcr.io"]="Kubernetes gcr"
    ["registry.k8s.io"]="Kubernetes Registry"
)

# -----------------------------------------------------------------------------
# Test DNS resolution
# -----------------------------------------------------------------------------
check_dns() {
    log_step "DNS Resolution"
    
    local dns_ok=true
    
    # Test common domains
    for domain in google.com cloudflare.com github.com; do
        if nslookup "$domain" &>/dev/null; then
            log_ok "DNS resolves: $domain"
        else
            log_fail "DNS fails to resolve: $domain"
            dns_ok=false
        fi
    done
    
    
    $dns_ok
}

# -----------------------------------------------------------------------------
# Test outbound ports
# -----------------------------------------------------------------------------
check_ports() {
    log_step "Outbound Ports"
    
    local ports_ok=true
    
    for port in 80 443; do
        if timeout 1 bash -c "echo >/dev/tcp/8.8.8.8:$port" 2>/dev/null; then
            log_ok "Port $port is open for outbound connections"
        else
            log_fail "Port $port is blocked"
            ports_ok=false
        fi
    done
    
    $ports_ok
}

# -----------------------------------------------------------------------------
# Test registry connectivity
# -----------------------------------------------------------------------------
check_registry() {
    local host="$1"
    local name="$2"
    
    log_info "Testing: $name ($host)"
    
    local latency
    latency=$(curl -o /dev/null -s -w "%{time_total}" \
        --connect-timeout 5 \
        --max-time 10 \
        "https://$host" 2>/dev/null)
    
    if [[ "$latency" =~ ^[0-9] ]]; then
        local latency_ms
        latency_ms=$(echo "$latency * 1000" | bc -l 2>/dev/null)
        latency_ms=${latency_ms%.*}
        
        if [[ $latency_ms -lt 500 ]]; then
            log_ok "$name ($host) — ${latency_ms}ms"
            return 0
        elif [[ $latency_ms -lt 2000 ]]; then
            log_slow "$name ($host) — ${latency_ms}ms"
            return 1
        else
            log_fail "$name ($host) — ${latency_ms}ms (timeout or very slow)"
            return 2
        fi
    else
        log_fail "$name ($host) — connection failed"
        return 2
    fi
}

# -----------------------------------------------------------------------------
# Main check function
# -----------------------------------------------------------------------------
check_all() {
    log_step "Network Connectivity Check"
    echo "Checking connectivity to common registries and services..."
    echo
    
    local failed=0
    local slow=0
    local ok=0
    
    # Check DNS
    if ! check_dns; then
        log_fail "DNS resolution failed. Check your DNS settings."
        ((failed++))
    fi
    
    # Check ports
    if ! check_ports; then
        log_fail "Required ports are blocked. Check firewall settings."
        ((failed++))
    fi
    
    # Check each registry
    for host in "${!TARGETS[@]}"; do
        local name="${TARGETS[$host]}"
        local result
        result=$(check_registry "$host" "$name")
        case $result in
            0) ((ok++)) ;;
            1) ((slow++)) ;;
            2) ((failed++)) ;;
        esac
    done
    
    # Summary
    log_step "Summary"
    echo -e "  ${GREEN}OK: $ok${NC}  ${YELLOW}SLOW: $slow${NC}  ${RED}FAIL: $failed${NC}"
    echo
    
    if [[ $failed -gt 0 ]]; then
        log_info "Detected $failed unreachable source(s). Recommendations:"
        echo "  1. Run: ./scripts/setup-cn-mirrors.sh  # Configure CN mirrors"
        echo "  2. Run: ./scripts/localize-images.sh --cn  # Use CN mirrors"
        echo "  3. Check VPN or proxy settings"
        return 1
    elif [[ $slow -gt 0 ]]; then
        log_info "Detected $slow slow connection(s). Consider enabling CN mirrors."
        echo "  Run: ./scripts/setup-cn-mirrors.sh"
        return 0
    else
        log_info "All connections are healthy. No CN mirrors needed."
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --help       Show this help message

Description:
  Checks connectivity to Docker registries, GitHub, gcr.io, ghcr.io
  and other common services. Reports latency and availability.

Examples:
  $(basename "$0")           # Run full connectivity check
EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
case "${1:-}" in
    --help|-h)
        usage
        ;;
    *)
        check_all
        ;;
esac
