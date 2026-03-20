#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Diagnostic Tool
# Collects system information and generates diagnostic report
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
# Script info
# -----------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
REPORT_FILE="$ROOT_DIR/diagnose-report.txt"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
HomeLab Stack — Diagnostic Tool
Collects system information and generates a diagnostic report.

Usage: $(basename "$0") [options]

Options:
  --output <file>   Write report to file (default: diagnose-report.txt)
  --no-color         Disable colored output
  --help             Show this help message

Examples:
  $(basename "$0") > diagnose-report.txt
  $(basename "$0") --no-color
EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Collect system info
# -----------------------------------------------------------------------------
collect_system_info() {
    log_step "System Information"
    
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(cat /etc/os-release 2>/dev/null | head -1)"
    echo "Arch: $(uname -m)"
    
    # Memory
    local mem_total
    mem_total=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' | awk '{printf "%.1f GB\n", $2/1024}')
    echo "Memory: $mem_total GB"
    
    # Swap
    local swap_used
    swap_used=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}' | awk '{printf "%.1f GB\n", $2/1024}')
    echo "Swap Used: $swap_used GB"
    
    # Disk
    local disk_free
    disk_free=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
    echo "Disk Free: ${disk_free}GB"
}

# -----------------------------------------------------------------------------
# Collect Docker info
# -----------------------------------------------------------------------------
collect_docker_info() {
    log_step "Docker Information"
    
    if ! command -v docker &>/dev/null; then
        log_warn "Docker not installed"
        return
    fi
    
    echo "Docker Version: $(docker --version | head -1)"
    echo "Docker Compose: $(docker compose version --short 2>/dev/null || echo 'not installed')"
    
    # Docker daemon status
    if docker info &>/dev/null; then
        echo "Docker Daemon: Running"
    else
        echo "Docker Daemon: Not running"
    fi
    
    # Container count
    local container_count
    container_count=$(docker ps -q 2>/dev/null | wc -l)
    echo "Running Containers: $container_count"
}

# -----------------------------------------------------------------------------
# Collect container status
# -----------------------------------------------------------------------------
collect_containers() {
    log_step "Container Status"
    
    local containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        echo "No containers running"
        return
    fi
    
    echo "$containers"
}
# -----------------------------------------------------------------------------
# Collect recent logs
# -----------------------------------------------------------------------------
collect_logs() {
    log_step "Recent Container Logs (last 20 lines per container)"
    
    local containers
    containers=$(docker ps -q 2>/dev/null)
    
    for container in $containers; do
        local name
        name=$(docker inspect "$container" --format '{{.Name}}' 2>/dev/null)
        log_info "=== $name ==="
        docker logs "$container" --tail 20 2>&1 || true
        echo
    done
}
# -----------------------------------------------------------------------------
# Check configuration files
# -----------------------------------------------------------------------------
check_configs() {
    log_step "Configuration Files"
    
    local config_dirs=(
        "config/traefik"
        "config/prometheus"
        "config/grafana"
        "config/loki"
        "config/alertmanager"
    ".env"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$ROOT_DIR/$dir" ]]; then
            local file_count
            file_count=$(find "$ROOT_DIR/$dir" -type f 2>/dev/null | wc -l)
            log_info "$dir: $file_count files"
        else
            log_warn "$dir: not found"
        fi
    done
}

# -----------------------------------------------------------------------------
# Check network connectivity
# -----------------------------------------------------------------------------
check_network() {
    log_step "Network Connectivity"
    
    if [[ -x "$ROOT_DIR/scripts/check-connectivity.sh" ]]; then
        log_info "Running connectivity check..."
        bash "$ROOT_DIR/scripts/check-connectivity.sh"
    else
        log_warn "check-connectivity.sh not found, skipping network check"
    fi
}
# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
print_summary() {
    log_step "Diagnostic Summary"
    
    local container_count
    container_count=$(docker ps -q 2>/dev/null | wc -l)
    
    local unhealthy_count
    unhealthy_count=$(docker ps --filter "status=exited" --format "{{.Names}}" 2>/dev/null | wc -l)
    
    if [[ $container_count -eq 0 ]]; then
        log_info "No containers running. System is clean."
    elif [[ $unhealthy_count -gt 0 ]]; then
        log_warn "$unhealthy_count container(s) have exited status"
    else
        log_info "$container_count container(s) running normally"
    fi
    
    echo
    log_info "Report saved to: $REPORT_FILE"
}
# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output)
                REPORT_FILE="$2"
                shift 2
                ;;
            --no-color)
                # Disable colors
                RED=""
                GREEN=""
                YELLOW=""
                CYAN=""
                BOLD=""
                NC=""
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Create report directory
    mkdir -p "$(dirname "$REPORT_FILE")" 2>/dev/null || true
    
    # Collect information
    {
        collect_system_info
        collect_docker_info
        collect_containers
        collect_logs
        check_configs
        check_network
    } > "$REPORT_FILE"
    
    # Summary
    print_summary
}

main "$@"
