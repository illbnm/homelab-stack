#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — 一键诊断工具
# 收集系统信息、Docker 状态、日志等,用于问题排查
# =============================================================================
set -euo pipefail

# Colors
# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Output file
OUTPUT_FILE="diagnose-report.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

# Section divider
divider() {
  echo ""
  echo "============================================"
  echo ""
}

# Header
header() {
  local title="$1"
  echo ""
  echo -e "${CYAN}${BOLD}### $title ###${NC}"
  echo ""
}

# Collect system info
collect_system_info() {
  header "System Information"
  
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Hostname: $(hostname)"
  echo ""
  
  # OS info
  echo "Operating System:"
  if [[ -f /etc/os-release ]]; then
    grep -E "^(NAME|VERSION|ID)=" /etc/os-release | sed 's/^/  /'
  else
    uname -a | sed 's/^/  /'
  fi
  echo ""
  
  # Kernel
  echo "Kernel: $(uname -r)"
  echo "Architecture: $(uname -m)"
  echo ""
  
  # Uptime
  echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
  echo ""
  
  # Memory
  echo "Memory:"
  free -h 2>/dev/null | sed 's/^/  /' || echo "  (free command not available)"
  echo ""
  
  # Disk
  echo "Disk Usage:"
  df -h / /var/lib/docker 2>/dev/null | sed 's/^/  /' || df -h / | sed 's/^/  /'
  echo ""
  
  # CPU
  echo "CPU Info:"
  if [[ -f /proc/cpuinfo ]]; then
    echo "  Cores: $(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)"
    grep "model name" /proc/cpuinfo | head -1 | sed 's/model name.*/  Model: /' | tr -d '\n'
    grep "model name" /proc/cpuinfo | head -1 | sed 's/model name.*: //'
  else
    echo "  (cpuinfo not available)"
  fi
}

# Collect Docker info
collect_docker_info() {
  header "Docker Information"
  
  # Version
  echo "Docker Version:"
  docker version 2>/dev/null | sed 's/^/  /' || echo "  (docker not available)"
  echo ""
  
  # Docker info
  echo "Docker System Info:"
  docker info 2>/dev/null | grep -E "^(Server Version|Storage Driver|Cgroup|Operating System|Kernel Version|Total Memory|CPUs|Docker Root Dir)" | sed 's/^/  /' || echo "  (docker info not available)"
  echo ""
  
  # Docker Compose
  echo "Docker Compose Version:"
  docker compose version 2>/dev/null | sed 's/^/  /' || echo "  (docker compose not available)"
  echo ""
  
  # Network
  echo "Docker Networks:"
  docker network ls 2>/dev/null | sed 's/^/  /' || echo "  (unable to list networks)"
  echo ""
  
  # Volumes
  echo "Docker Volumes:"
  docker volume ls 2>/dev/null | sed 's/^/  /' || echo "  (unable to list volumes)"
  echo ""
  
  # Mirror config
  echo "Docker Registry Mirrors:"
  if [[ -f /etc/docker/daemon.json ]]; then
    jq '.["registry-mirrors"] // empty' /etc/docker/daemon.json 2>/dev/null | sed 's/^/  /' || echo "  (no mirrors configured)"
  else
    echo "  (daemon.json not found)"
  fi
}

# Collect container status
collect_container_status() {
  header "Container Status"
  
  # All containers
  echo "All Containers:"
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -20 | sed 's/^/  /'
  local total
  total=$(docker ps -aq 2>/dev/null | wc -l)
  if [[ $total -gt 20 ]]; then
    echo "  ... and $((total - 20)) more containers"
  fi
  echo ""
  
  # Running by stack
  echo "Containers by Stack:"
  for stack_dir in "$PROJECT_ROOT"/stacks/*/; do
    [[ -d "$stack_dir" ]] || continue
    local stack_name
    stack_name=$(basename "$stack_dir")
    local count
    count=$(docker ps --filter "label=com.docker.compose.project=$stack_name" -q 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
      echo "  $stack_name: $count running"
    fi
  done
  echo ""
  
  # Unhealthy containers
  echo "Unhealthy Containers:"
  local unhealthy
  unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
  if [[ -n "$unhealthy" ]]; then
    echo "$unhealthy" | sed 's/^/  /'
  else
    echo "  (none)"
  fi
}

# Collect error logs
collect_error_logs() {
  header "Recent Error Logs"

  # Check each running container for errors
  local containers
  containers=$(docker ps --format "{{.Names}}" 2>/dev/null | head -20 || true)
  
  for container in $containers; do
    local errors
    errors=$(docker logs --tail 100 "$container" 2>&1 | grep -iE "(error|fail|exception|fatal|panic)" | tail -5 || true)
    
    if [[ -n "$errors" ]]; then
      echo -e "${YELLOW}$container${NC}:"
      echo "$errors" | sed 's/^/  /'
      echo ""
    fi
  done
}

# Collect network info
collect_network_info() {
  header "Network Connectivity"
  
  # DNS
  echo "DNS Resolution:"
  for domain in "github.com" "hub.docker.com" "gcr.io" "ghcr.io"; do
    if host -W 2 "$domain" &>/dev/null; then
      echo "  ✓ $domain"
    else
      echo "  ✗ $domain (failed)"
    fi
  done
  echo ""
  
  # Port availability
  echo "Port Availability:"
  for port in 80 443; do
    if timeout 2 bash -c "echo >/dev/tcp/google.com $port" 2>/dev/null; then
      echo "  ✓ Port $port"
    else
      echo "  ✗ Port $port (blocked or filtered)"
    fi
  done
  echo ""
  
  # Quick connectivity test
  echo "Registry Connectivity:"
  for registry in "hub.docker.com" "gcr.io" "ghcr.io"; do
    if curl -sf --connect-timeout 3 --max-time 5 "https://$registry/v2/" &>/dev/null; then
      echo "  ✓ $registry"
    else
      echo "  ✗ $registry (unreachable)"
    fi
  done
}

# Collect config validation
collect_config_validation() {
  header "Configuration Validation"
  
  # Check .env
  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo ".env file: ✓ Found"
    
    # Check required variables (without showing values)
    local required=("DOMAIN" "ACME_EMAIL" "TZ")
    for var in "${required[@]}"; do
      if grep -q "^${var}=" "$PROJECT_ROOT/.env"; then
        local val
        val=$(grep "^${var}=" "$PROJECT_ROOT/.env" | cut -d= -f2-)
        if [[ -n "$val" && "$val" != "yourdomain.com" && "$val" != "you@example.com" ]]; then
          echo "  $var: ✓ Set"
        else
          echo "  $var: ✗ Not configured"
        fi
      else
        echo "  $var: ✗ Missing"
      fi
    done
  else
    echo ".env file: ✗ Not found"
  fi
  echo ""
  
  # Check acme.json
  local acme_file="$PROJECT_ROOT/config/traefik/acme.json"
  if [[ -f "$acme_file" ]]; then
    local perms
    perms=$(stat -c '%a' "$acme_file" 2>/dev/null || stat -f '%A' "$acme_file" 2>/dev/null || echo "unknown")
    if [[ "$perms" == "600" ]]; then
      echo "acme.json: ✓ Permissions correct (600)"
    else
      echo "acme.json: ✗ Wrong permissions ($perms, should be 600)"
    fi
  else
    echo "acme.json: (not created yet)"
  fi
  echo ""
  
  # Check compose files syntax
  echo "Docker Compose File Validation:"
  for compose_file in "$PROJECT_ROOT"/stacks/*/docker-compose*.yml; do
    [[ -f "$compose_file" ]] || continue
    local name
    name=$(basename "$(dirname "$compose_file")")/$(basename "$compose_file")
    if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
      echo "  ✓ $name"
    else
      echo "  ✗ $name (syntax error)"
    fi
  done
}

# Collect stack-specific info
collect_stack_info() {
  header "Stack Status"
  
  for stack_dir in "$PROJECT_ROOT"/stacks/*/; do
    [[ -d "$stack_dir" ]] || continue
    local stack_name
    stack_name=$(basename "$stack_dir")
    
    echo -e "${BOLD}$stack_name${NC}:"
    
    # Check if running
    local running
    running=$(docker ps --filter "label=com.docker.compose.project=$stack_name" -q 2>/dev/null | wc -l)
    
    if [[ $running -gt 0 ]]; then
      echo "  Status: Running ($running containers)"
      
      # Show container health
      docker ps --filter "label=com.docker.compose.project=$stack_name" \
        --format "  - {{.Names}}: {{.Status}}" 2>/dev/null | head -5
      
      if [[ $running -gt 5 ]]; then
        echo "  ... and $((running - 5)) more"
      fi
    else
      echo "  Status: Not running"
    fi
    echo ""
  done
}

# Generate report
generate_report() {
  {
    echo "============================================"
    echo "     HomeLab Stack Diagnostic Report"
    echo "============================================"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Script Version: 1.0.0"
    
    collect_system_info
    collect_docker_info
    collect_container_status
    collect_config_validation
    collect_network_info
    collect_stack_info
    collect_error_logs
    
    echo ""
    echo "============================================"
    echo "     End of Diagnostic Report"
    echo "============================================"
  } | tee "$OUTPUT_FILE"
  
  echo ""
  log_info "Report saved to: $OUTPUT_FILE"
}

# Quick check mode
quick_check() {
  echo -e "${BOLD}Quick Health Check${NC}"
  echo ""
  
  local issues=0
  
  # Docker running?
  if docker info &>/dev/null; then
    echo -e "${GREEN}✓${NC} Docker is running"
  else
    echo -e "${RED}✗${NC} Docker is not running"
    ((issues++))
  fi
  
  # .env exists?
  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo -e "${GREEN}✓${NC} .env configured"
  else
    echo -e "${YELLOW}!${NC} .env not found"
    ((issues++))
  fi
  
  # acme.json?
  local acme="$PROJECT_ROOT/config/traefik/acme.json"
  if [[ -f "$acme" ]]; then
    local perms
    perms=$(stat -c '%a' "$acme" 2>/dev/null || echo "unknown")
    if [[ "$perms" == "600" ]]; then
      echo -e "${GREEN}✓${NC} acme.json correct"
    else
      echo -e "${YELLOW}!${NC} acme.json wrong perms ($perms)"
      ((issues++))
    fi
  fi
  
  # Unhealthy containers?
  local unhealthy
  unhealthy=$(docker ps --filter "health=unhealthy" -q 2>/dev/null | wc -l || echo "0")
  if [[ "$unhealthy" -gt 0 ]]; then
    echo -e "${RED}✗${NC} $unhealthy unhealthy containers"
    ((issues++))
  else
    echo -e "${GREEN}✓${NC} No unhealthy containers"
  fi
  
  echo ""
  if [[ $issues -eq 0 ]]; then
    echo -e "${GREEN}All checks passed${NC}"
    return 0
  else
    echo -e "${YELLOW}$issues issue(s) found${NC}"
    echo "Run '$0 --full' for detailed report"
    return 1
  fi
}

# Usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -f, --full       Generate full diagnostic report
  -q, --quick      Quick health check (default)
  -o, --output     Output file (default: diagnose-report.txt)
  --no-logs        Skip error logs collection
  -h, --help       Show this help

Examples:
  $0                    # Quick health check
  $0 --full             # Full diagnostic report
  $0 --full -o report.txt

The report includes:
  - System information (OS, memory, disk)
  - Docker version and configuration
  - Container status and health
  - Network connectivity tests
  - Configuration validation
  - Recent error logs
  - Stack-specific status

Use this report when filing issues on GitHub.

EOF
  exit 0
}

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Main
main() {
  local mode="quick"
  local collect_logs=true
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--full) mode="full" ;;
      -q|--quick) mode="quick" ;;
      -o|--output) OUTPUT_FILE="$2"; shift ;;
      --no-logs) collect_logs=false ;;
      -h|--help) usage ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
  done
  
  cd "$PROJECT_ROOT"
  
  if [[ "$mode" == "quick" ]]; then
    quick_check
  else
    generate_report
  fi
}

main "$@"
