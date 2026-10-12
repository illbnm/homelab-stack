#!/bin/bash
# Script to check network connectivity to various services and ports.

# Source common utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"

# Exit on error
set -e

# Define services to check
declare -A SERVICES
SERVICES["Docker Hub"]="hub.docker.com:443"
SERVICES["GitHub"]="github.com:443"
SERVICES["gcr.io"]="gcr.io:443"
SERVICES["ghcr.io"]="ghcr.io:443"
SERVICES["Google DNS"]="8.8.8.8:53" # For general internet connectivity/DNS
SERVICES["Baidu"]="www.baidu.com:443" # For general CN connectivity

# Function to check connectivity to a host:port
check_host_port() {
    local name="$1"
    local host_port="$2"
    local host="${host_port%:*}"
    local port="${host_port#*:}"
    local start_time=$(date +%s%3N) # Milliseconds
    local status="FAIL"
    local message=""
    local icon="✗"
    local color="${COLOR_RED}"
    local curl_opts=("--silent" "--output" "/dev/null" "--write-out" "%{time_total}")

    # Check DNS resolution first
    if ! dig +short "$host" >/dev/null; then
        message="DNS resolution failed"
    else
        # Try to connect using curl
        local time_total=$(curl_retry "https://${host}:${port}" "${curl_opts[@]}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$time_total" ]; then
            local latency_ms=$(echo "$time_total * 1000" | bc | cut -d'.' -f1)
            status="OK"
            icon="✓"
            color="${COLOR_GREEN}"
            message="Latency ${latency_ms}ms"
            if (( latency_ms > 1000 )); then
                status="SLOW"
                icon="⚠️"
                color="${COLOR_YELLOW}"
                message="${message} ⚠️ Suggests slow connection"
            fi
        else
            message="Connection timeout or refused"
        fi
    fi

    echo -e "  ${color}[${status}]${COLOR_RESET} ${name} (${host_port}) — ${message} ${icon}"
    if [[ "$status" == "FAIL" ]]; then
        return 1
    fi
    return 0
}

# Main execution
log_info "Starting network connectivity check..."
echo ""

failed_sources=0
slow_sources=0

# Check DNS resolution
log_info "Checking DNS resolution..."
if dig +short google.com >/dev/null; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} DNS resolution (google.com) — Normal ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} DNS resolution (google.com) — Failed ✗"
    failed_sources=$((failed_sources + 1))
fi
echo ""

# Check specific services
log_info "Checking critical service reachability..."
for service_name in "${!SERVICES[@]}"; do
    if ! check_host_port "$service_name" "${SERVICES[$service_name]}"; then
        if [[ "$(echo -e "${COLOR_RED}[FAIL]${COLOR_RESET}" | grep -o "FAIL")" ]]; then # Check if the output contained FAIL
            failed_sources=$((failed_sources + 1))
        elif [[ "$(echo -e "${COLOR_YELLOW}[SLOW]${COLOR_RESET}" | grep -o "SLOW")" ]]; then # Check if the output contained SLOW
            slow_sources=$((slow_sources + 1))
        fi
    fi
done
echo ""

# Check common outbound ports
log_info "Checking common outbound ports (80/443)..."
if nc -zw1 google.com 80 >/dev/null 2>&1; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} Outbound port 80 (HTTP) — Open ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} Outbound port 80 (HTTP) — Blocked ✗"
    failed_sources=$((failed_sources + 1))
fi

if nc -zw1 google.com 443 >/dev/null 2>&1; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} Outbound port 443 (HTTPS) — Open ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} Outbound port 443 (HTTPS) — Blocked ✗"
    failed_sources=$((failed_sources + 1))
fi
echo ""

# Summary and recommendations
if (( failed_sources > 0 )); then
    log_warn "Detected ${failed_sources} unreachable source(s)."
    log_info "Recommendation: Some critical services are unreachable. You might be in a restricted network environment."
    log_info "Consider running './scripts/setup-cn-mirrors.sh' to configure Docker mirrors and './scripts/localize-images.sh --cn' to use localized images."
elif (( slow_sources > 0 )); then
    log_warn "Detected ${slow_sources} slow source(s)."
    log_info "Recommendation: Some services are slow. You might benefit from using local mirrors."
    log_info "Consider running './scripts/setup-cn-mirrors.sh' to configure Docker mirrors and './scripts/localize-images.sh --cn' to use localized images."
else
    log_success "All critical services and ports are reachable and responsive. Your network environment seems healthy."
fi

exit 0
