#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
REPORT_FILE="diagnose-report.txt"

init_report() {
  local output_file=${1:-$REPORT_FILE}
  
  cat > "$output_file" << REPORT_EOF
# HomeLab Stack Diagnostics Report
Generated: $(date)
Hostname: $(hostname)
User: $(whoami)

========================================

REPORT_EOF
  
  REPORT_FILE="$output_file"
}

append_report() {
  local title=$1
  local content=$2
  
  cat >> "$REPORT_FILE" << REPORT_EOF

## $title

$content

========================================

REPORT_EOF
}

collect_system_info() {
  log_step "Collecting system information"
  
  local info=""
  info+="OS: $(uname -s)\n"
  info+="Kernel: $(uname -r)\n"
  info+="Architecture: $(uname -m)\n"
  info+="Hostname: $(hostname)\n"
  
  if [[ -f /etc/os-release ]]; then
    info+="Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')\n"
  fi
  
  if command -v free &> /dev/null; then
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    local mem_avail=$(free -h | awk '/^Mem:/ {print $7}')
    info+="Memory: Total $mem_total, Available $mem_avail\n"
  fi
  
  if command -v df &> /dev/null; then
    local disk_root=$(df -h / | awk 'NR==2 {print $4 " available of " $2}')
    info+="Disk (root): $disk_root\n"
  fi
  
  if [[ -f /proc/cpuinfo ]]; then
    local cpu_count=$(grep -c ^processor /proc/cpuinfo)
    info+="CPU Cores: $cpu_count\n"
  fi
  
  echo -e "$info"
  append_report "System Information" "$(echo -e "$info")"
}

collect_docker_info() {
  log_step "Collecting Docker information"
  
  local info=""
  
  if ! command -v docker &> /dev/null; then
    info="Docker not installed"
  else
    info+="Docker Version: $(docker --version)\n"
    
    if docker compose version &> /dev/null; then
      info+="Compose Version: $(docker compose version)\n"
    fi
    
    info+="\nDocker System Info:\n"
    info+="$(docker info 2>&1 | grep -E '(Server Version|Storage Driver|Cgroup|Operating System|Kernel Version|Total Memory|CPUs)' | head -10)\n"
    
    if [[ -f /etc/docker/daemon.json ]]; then
      info+="\nDaemon Config:\n"
      info+="$(cat /etc/docker/daemon.json | jq '.' 2>/dev/null || cat /etc/docker/daemon.json)\n"
    fi
  fi
  
  echo -e "$info"
  append_report "Docker Information" "$(echo -e "$info")"
}

collect_container_status() {
  log_step "Collecting container status"
  
  local info=""
  
  if ! command -v docker &> /dev/null; then
    info="Docker not installed"
  else
    local containers
    containers=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers")
    info="$containers"
  fi
  
  echo "$info"
  append_report "Container Status" "$info"
}

collect_network_info() {
  log_step "Testing network connectivity"
  
  local info=""
  
  if [[ -f "$SCRIPT_DIR/check-connectivity.sh" ]]; then
    info+="$(bash "$SCRIPT_DIR/check-connectivity.sh" 2>&1 || true)"
  else
    info+="Basic connectivity tests:\n"
    
    for host in "google.com" "github.com" "hub.docker.com"; do
      if timeout 5 ping -c 1 "$host" &> /dev/null; then
        info+="✓ $host: reachable\n"
      else
        info+="✗ $host: unreachable\n"
      fi
    done
  fi
  
  echo -e "$info"
  append_report "Network Connectivity" "$(echo -e "$info")"
}

main() {
  local output_file=${1:-$REPORT_FILE}
  
  echo -e "${BOLD}HomeLab Stack Diagnostics${NC}"
  echo "================================"
  echo ""
  
  init_report "$output_file"
  log_info "Report will be saved to: $output_file"
  echo ""
  
  collect_system_info
  collect_docker_info
  collect_container_status
  collect_network_info
  
  log_info "✓ Diagnostics complete!"
  log_info "Report saved to: $output_file"
  
  echo ""
  log_step "Summary"
  cat "$REPORT_FILE"
}

usage() {
  cat << USAGE_EOF
Usage: $0 [OPTIONS]

Options:
  --output <file>  Output file path (default: $REPORT_FILE)
  --help           Show this help message

Examples:
  $0                           # Generate report to diagnose-report.txt
  $0 --output my-diagnose.txt  # Generate to custom file
USAGE_EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --output)
      REPORT_FILE="$2"
      shift 2
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

main "$REPORT_FILE"
