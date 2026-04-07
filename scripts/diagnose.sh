#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — System diagnostic tool for HomeLab Stack
# Collects comprehensive diagnostic information for troubleshooting
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
REPORT_FILE="$PROJECT_ROOT/diagnose-report.txt"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Write to both stdout and file
# ---------------------------------------------------------------------------
write_report() {
  echo "$*" | tee -a "$REPORT_FILE"
}

write_section() {
  echo "" | tee -a "$REPORT_FILE"
  echo -e "${BOLD}=== $* ===${NC}" | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
}

# ---------------------------------------------------------------------------
# Collect system information
# ---------------------------------------------------------------------------
collect_system_info() {
  write_section "System Information"

  write_report "Hostname: $(hostname)"
  write_report "OS: $(uname -s)"
  write_report "Kernel: $(uname -r)"
  write_report "Architecture: $(uname -m)"
  write_report ""

  # Distribution info
  if [[ -f /etc/os-release ]]; then
    write_report "Distribution:"
    grep -E '^(NAME|VERSION|ID)=' /etc/os-release | while read -r line; do
      write_report "  $line"
    done
  fi
  write_report ""

  # CPU info
  write_report "CPU:"
  if command -v lscpu &>/dev/null; then
    lscpu | grep -E '^(Model name|CPU\(s\)|CPU MHz)' | while read -r line; do
      write_report "  $line"
    done
  elif [[ -f /proc/cpuinfo ]]; then
    write_report "  Cores: $(grep -c ^processor /proc/cpuinfo)"
  fi
  write_report ""

  # Memory info
  write_report "Memory:"
  if command -v free &>/dev/null; then
    free -h | head -2 | tail -1 | awk '{print "  Total: " $2 "\n  Used: " $3 "\n  Free: " $4 "\n  Available: " $7}'
  fi
  write_report ""

  # Disk info
  write_report "Disk Space:"
  df -h | grep -E '^/dev|Filesystem' | head -10 | while read -r line; do
    write_report "  $line"
  done
  write_report ""

  # Uptime
  write_report "Uptime: $(uptime -p 2>/dev/null || uptime)"
}

# ---------------------------------------------------------------------------
# Collect Docker information
# ---------------------------------------------------------------------------
collect_docker_info() {
  write_section "Docker Information"

  if ! command -v docker &>/dev/null; then
    write_report "${RED}Docker is not installed${NC}"
    return
  fi

  # Version
  write_report "Docker Version:"
  docker version 2>&1 | head -20 | while read -r line; do
    write_report "  $line"
  done
  write_report ""

  # Docker info
  write_report "Docker Info:"
  docker info 2>&1 | grep -E '^(Server Version|Storage Driver|Cgroup|Operating System|Architecture|CPUs|Total Memory|Docker Root Dir)' | while read -r line; do
    write_report "  $line"
  done
  write_report ""

  # Registry mirrors
  write_report "Registry Mirrors:"
  if docker info 2>&1 | grep -q "Registry Mirrors"; then
    docker info 2>&1 | grep -A 5 "Registry Mirrors" | while read -r line; do
      write_report "  $line"
    done
  else
    write_report "  No mirrors configured"
  fi
  write_report ""

  # Docker Compose version
  write_report "Docker Compose:"
  if docker compose version &>/dev/null; then
    docker compose version
  elif command -v docker-compose &>/dev/null; then
    docker-compose version
  else
    write_report "  Not found"
  fi
}

# ---------------------------------------------------------------------------
# Collect container status
# ---------------------------------------------------------------------------
collect_container_status() {
  write_section "Container Status"

  if ! docker ps &>/dev/null; then
    write_report "${RED}Cannot list containers (Docker not running?)${NC}"
    return
  fi

  # All containers
  local total_containers
  total_containers=$(docker ps -a --format '{{.Names}}' | wc -l)
  write_report "Total containers: $total_containers"
  write_report ""

  # Running containers
  write_report "Running Containers:"
  if docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | head -20; then
    write_report ""
  else
    write_report "  None"
  fi
  write_report ""

  # Stopped containers
  write_report "Stopped Containers:"
  local stopped
  stopped=$(docker ps --filter "status=exited" --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null)
  if [[ -n "$stopped" ]]; then
    echo "$stopped" | head -20 | while read -r line; do
      write_report "  $line"
    done
  else
    write_report "  None"
  fi
  write_report ""

  # Unhealthy containers
  write_report "Unhealthy Containers:"
  local unhealthy
  unhealthy=$(docker ps --filter "health=unhealthy" --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null)
  if [[ -n "$unhealthy" ]]; then
    echo "$unhealthy" | while read -r line; do
      write_report "  $line"
    done
  else
    write_report "  None"
  fi
}

# ---------------------------------------------------------------------------
# Collect network information
# ---------------------------------------------------------------------------
collect_network_info() {
  write_section "Network Information"

  # Docker networks
  write_report "Docker Networks:"
  docker network ls 2>&1 | while read -r line; do
    write_report "  $line"
  done
  write_report ""

  # Proxy network details
  if docker network inspect proxy &>/dev/null; then
    write_report "Proxy Network Details:"
    docker network inspect proxy 2>&1 | grep -E '"Name"|"Driver"|"Scope"' | while read -r line; do
      write_report "  $line"
    done
  fi
  write_report ""

  # Port usage
  write_report "Port Usage (80, 443, 3000, 8080):"
  for port in 80 443 3000 8080; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      write_report "  Port $port: IN USE"
      ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print "    Process: " $7}'
    else
      write_report "  Port $port: Available"
    fi
  done
  write_report ""

  # DNS resolution
  write_report "DNS Resolution Test:"
  for domain in google.com github.com docker.io; do
    if nslookup "$domain" &>/dev/null; then
      write_report "  $domain: OK"
    else
      write_report "  $domain: FAILED"
    fi
  done
}

# ---------------------------------------------------------------------------
# Collect container logs
# ---------------------------------------------------------------------------
collect_error_logs() {
  write_section "Recent Error Logs (Last 24h)"

  # Get containers with recent errors
  local containers
  containers=$(docker ps --format '{{.Names}}' 2>/dev/null | head -20)

  for container in $containers; do
    local errors
    errors=$(docker logs --since 24h "$container" 2>&1 | grep -iE "(error|fatal|failed|exception)" | tail -5 || true)

    if [[ -n "$errors" ]]; then
      write_report ""
      write_report "${YELLOW}Container: $container${NC}"
      echo "$errors" | while read -r line; do
        write_report "  $line"
      done
    fi
  done
}

# ---------------------------------------------------------------------------
# Collect configuration status
# ---------------------------------------------------------------------------
collect_config_status() {
  write_section "Configuration Status"

  # .env file
  write_report ".env File:"
  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    write_report "  Status: Present"
    write_report "  Size: $(du -h "$PROJECT_ROOT/.env" | cut -f1)"
    write_report "  Modified: $(stat -c %y "$PROJECT_ROOT/.env" 2>/dev/null | cut -d. -f1 || stat -f "%Sm" "$PROJECT_ROOT/.env")"
  else
    write_report "  Status: ${RED}Missing${NC}"
  fi
  write_report ""

  # ACME file
  write_report "ACME Certificate File:"
  local acme_file="$PROJECT_ROOT/config/traefik/acme.json"
  if [[ -f "$acme_file" ]]; then
    write_report "  Status: Present"
    local perms
    perms=$(stat -c '%a' "$acme_file" 2>/dev/null || stat -f '%A' "$acme_file" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
      write_report "  Permissions: $perms ${GREEN}(Correct)${NC}"
    else
      write_report "  Permissions: $perms ${RED}(Should be 600)${NC}"
    fi
  else
    write_report "  Status: ${RED}Missing${NC}"
  fi
  write_report ""

  # Config files validation
  write_report "Configuration Files:"
  local config_files=(
    "$PROJECT_ROOT/docker-compose.base.yml"
    "$PROJECT_ROOT/.env"
    "$PROJECT_ROOT/config/traefik/traefik.yml"
  )

  for file in "${config_files[@]}"; do
    if [[ -f "$file" ]]; then
      write_report "  $(basename "$file"): ${GREEN}Present${NC}"
    else
      write_report "  $(basename "$file"): ${RED}Missing${NC}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Collect connectivity test results
# ---------------------------------------------------------------------------
collect_connectivity_tests() {
  write_section "Network Connectivity Tests"

  # Test essential endpoints
  local endpoints=(
    "https://hub.docker.com|Docker Hub"
    "https://github.com|GitHub"
    "https://gcr.io|Google Container Registry"
    "https://ghcr.io|GitHub Container Registry"
  )

  for endpoint in "${endpoints[@]}"; do
    local url
    url=$(echo "$endpoint" | cut -d'|' -f1)
    local name
    name=$(echo "$endpoint" | cut -d'|' -f2)

    if curl -sf --connect-timeout 5 --max-time 10 "$url" &>/dev/null; then
      write_report "  $name: ${GREEN}OK${NC}"
    else
      write_report "  $name: ${RED}FAILED${NC}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Generate recommendations
# ---------------------------------------------------------------------------
generate_recommendations() {
  write_section "Recommendations"

  local issues=()

  # Check Docker
  if ! command -v docker &>/dev/null; then
    issues+=("Docker is not installed")
  fi

  # Check .env
  if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    issues+=(".env file is missing - run: cp .env.example .env && ./scripts/setup-env.sh")
  fi

  # Check proxy network
  if ! docker network inspect proxy &>/dev/null; then
    issues+=("Proxy network missing - run: docker network create proxy")
  fi

  # Check disk space
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  if [[ "$free_gb" -lt 10 ]]; then
    issues+=("Low disk space: ${free_gb}GB free (recommend >= 10GB)")
  fi

  # Check memory
  if command -v free &>/dev/null; then
    local total_mb
    total_mb=$(free -m | awk 'NR==2 {print $2}')
    if [[ "$total_mb" -lt 2048 ]]; then
      issues+=("Low memory: ${total_mb}MB (recommend >= 2048MB)")
    fi
  fi

  # Check for unhealthy containers
  local unhealthy_count
  unhealthy_count=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null | wc -l)
  if [[ "$unhealthy_count" -gt 0 ]]; then
    issues+=("$unhealthy_count unhealthy container(s) detected")
  fi

  # Display issues
  if [[ ${#issues[@]} -eq 0 ]]; then
    write_report "${GREEN}✓ No critical issues found${NC}"
  else
    write_report "${YELLOW}Found ${#issues[@]} issue(s):${NC}"
    for issue in "${issues[@]}"; do
      write_report "  • $issue"
    done
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local output_file=${1:-$REPORT_FILE}

  # Initialize report file
  echo "HomeLab Stack Diagnostic Report" > "$output_file"
  echo "Generated: $(date)" >> "$output_file"
  echo "================================" >> "$output_file"

  echo -e ""
  echo -e "${BOLD}  HomeLab Stack — Diagnostic Tool${NC}"
  echo -e "${BOLD}  =================================${NC}"
  echo -e ""
  log_info "Generating diagnostic report..."
  log_info "Report will be saved to: $output_file"
  echo ""

  collect_system_info
  collect_docker_info
  collect_container_status
  collect_network_info
  collect_error_logs
  collect_config_status
  collect_connectivity_tests
  generate_recommendations

  write_section "Report Complete"
  write_report "For support, attach this file when creating an issue:"
  write_report "  https://github.com/illbnm/homelab-stack/issues"
  write_report ""

  log_info ""
  log_info "${GREEN}✓ Diagnostic report generated!${NC}"
  log_info "Report saved to: $output_file"
  log_info ""
  log_info "Next steps:"
  log_info "  1. Review the report: cat $output_file"
  log_info "  2. Check recommendations section for issues"
  log_info "  3. Attach report when filing issues"
  log_info ""
}

main "$@"
