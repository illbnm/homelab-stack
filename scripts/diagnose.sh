#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — Comprehensive System Diagnostics for HomeLab Stack
# =============================================================================
# Performs thorough system diagnostics to identify issues and provide
# recommendations for optimal HomeLab Stack operation.
#
# Usage:
#   ./diagnose.sh [--quick] [--full] [--json]
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
REPORT_FILE="$PROJECT_ROOT/diagnostic-report.txt"

# Diagnostic results
declare -A RESULTS
declare -a ISSUES
declare -a RECOMMENDATIONS

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}[${NC} $* ${BLUE}${BOLD}]${NC}"; }
log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; }
log_warn_msg() { echo -e "  ${YELLOW}!${NC} $*"; }

# Check Docker
check_docker() {
  log_step "Docker Diagnostics"

  if command -v docker &>/dev/null; then
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    log_pass "Docker version: $docker_version"
    RESULTS["docker_version"]="$docker_version"

    if docker info &>/dev/null; then
      log_pass "Docker daemon: running"
      RESULTS["docker_daemon"]="OK"
    else
      log_fail "Docker daemon: not running"
      RESULTS["docker_daemon"]="FAIL"
      ISSUES+=("Docker daemon is not running")
      RECOMMENDATIONS+=("Start Docker: sudo systemctl start docker")
    fi
  else
    log_fail "Docker: not installed"
    RESULTS["docker"]="FAIL"
    ISSUES+=("Docker is not installed")
    RECOMMENDATIONS+=("Install Docker: curl -fsSL https://get.docker.com | sh")
  fi
}

# Check Docker Compose
check_compose() {
  log_step "Docker Compose Diagnostics"

  if docker compose version &>/dev/null; then
    local compose_version
    compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
    log_pass "Docker Compose v2: $compose_version"
    RESULTS["compose"]="v2"
  elif command -v docker-compose &>/dev/null; then
    log_warn_msg "Docker Compose v1 found (upgrade to v2 recommended)"
    RESULTS["compose"]="v1"
    ISSUES+=("Using Docker Compose v1 (deprecated)")
    RECOMMENDATIONS+=("Upgrade to Docker Compose v2")
  else
    log_fail "Docker Compose: not found"
    RESULTS["compose"]="FAIL"
    ISSUES+=("Docker Compose not installed")
  fi
}

# Check resources
check_resources() {
  log_step "Resource Diagnostics"

  # CPU
  local cpu_cores
  cpu_cores=$(nproc)
  log_info "CPU cores: $cpu_cores"
  RESULTS["cpu_cores"]="$cpu_cores"

  # Memory
  if [[ -f /proc/meminfo ]]; then
    local total_mem
    total_mem=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
    local avail_mem
    avail_mem=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo)
    local used_mem=$((total_mem - avail_mem))
    local mem_percent=$((used_mem * 100 / total_mem))

    log_info "Memory: ${used_mem}MB / ${total_mem}MB (${mem_percent}% used)"
    RESULTS["memory_total"]="$total_mem"

    if [[ $mem_percent -gt 90 ]]; then
      log_fail "Memory usage critical: ${mem_percent}%"
      ISSUES+=("High memory usage: ${mem_percent}%")
    fi
  fi

  # Disk
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')

  log_info "Disk space: ${free_gb}GB free"
  RESULTS["disk_avail"]="$free_gb"

  if [[ "$free_gb" -lt 10 ]]; then
    log_fail "Low disk space: ${free_gb}GB"
    ISSUES+=("Low disk space")
    RECOMMENDATIONS+=("Free up disk space")
  fi
}

# Check network
check_network() {
  log_step "Network Diagnostics"

  if timeout 5 curl -sf https://www.google.com &>/dev/null; then
    log_pass "Internet: connected"
    RESULTS["internet"]="OK"
  else
    if timeout 5 curl -sf https://www.baidu.com &>/dev/null; then
      log_warn_msg "Internet: connected (China network detected)"
      RESULTS["internet"]="CN"
      RECOMMENDATIONS+=("Consider using CN mirrors")
    else
      log_fail "Internet: not connected"
      RESULTS["internet"]="FAIL"
      ISSUES+=("No internet connectivity")
    fi
  fi
}

# Check ports
check_ports() {
  log_step "Port Availability"

  local critical_ports=(80 443)

  for port in "${critical_ports[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      log_warn_msg "Port $port: in use"
      RESULTS["port_$port"]="USED"
    else
      log_pass "Port $port: available"
      RESULTS["port_$port"]="FREE"
    fi
  done
}

# Check configuration
check_configuration() {
  log_step "Configuration Diagnostics"

  cd "$PROJECT_ROOT"

  if [[ -f .env ]]; then
    log_pass ".env file: exists"
    RESULTS["env_file"]="OK"
  else
    log_fail ".env file: not found"
    RESULTS["env_file"]="FAIL"
    ISSUES+=(".env file not found")
    RECOMMENDATIONS+=("Create .env: cp .env.example .env")
  fi
}

# Generate recommendations
generate_recommendations() {
  log_step "Recommendations"

  if [[ ${#RECOMMENDATIONS[@]} -eq 0 ]]; then
    log_info "No critical issues found!"
    return
  fi

  log_info "Recommendations:"
  for rec in "${RECOMMENDATIONS[@]}"; do
    echo "  - $rec"
  done
}

# Save diagnostic report
save_report() {
  {
    echo "HomeLab Stack Diagnostic Report"
    echo "Generated: $(date)"
    echo "================================"
    echo

    echo "Docker:"
    echo "  Version: ${RESULTS[docker_version]:-not installed}"
    echo "  Daemon: ${RESULTS[docker_daemon]:-unknown}"
    echo "  Compose: ${RESULTS[compose]:-not found}"
    echo

    echo "Resources:"
    echo "  CPU cores: ${RESULTS[cpu_cores]:-unknown}"
    echo "  Memory: ${RESULTS[memory_total]:-?}MB"
    echo "  Disk available: ${RESULTS[disk_avail]:-?}GB"
    echo

    echo "Network:"
    echo "  Internet: ${RESULTS[internet]:-unknown}"
    echo

    echo "Issues:"
    if [[ ${#ISSUES[@]} -eq 0 ]]; then
      echo "  None"
    else
      for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
      done
    fi

  } > "$REPORT_FILE"
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 [OPTIONS]

${BOLD}Options:${NC}
  --quick       Quick diagnostics
  --full        Full diagnostics
  -h, --help    Show this help message

${BOLD}Examples:${NC}
  # Run quick diagnostics
  $0 --quick

  # Full diagnostics
  $0 --full
EOF
}

# Main entry point
main() {
  local mode="normal"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quick)
        mode="quick"
        shift
        ;;
      --full)
        mode="full"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Header
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║        HomeLab Stack Diagnostic Tool v1.0                 ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo

  # Run diagnostics
  check_docker
  check_compose
  check_resources

  if [[ "$mode" != "quick" ]]; then
    check_network
    check_ports
    check_configuration
  fi

  # Generate report
  generate_recommendations
  save_report

  echo
  log_info "Diagnostic report saved to: $REPORT_FILE"

  # Exit with appropriate code
  if [[ ${#ISSUES[@]} -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
