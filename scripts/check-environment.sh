#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Environment Health Check
# Comprehensive environment detector: Docker, network, ports, disk, CN readiness.
# Outputs a structured health report suitable for troubleshooting.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0; INFO=0

log_pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((PASS++)); }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
log_warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((WARN++)); }
log_info() { echo -e "  ${BLUE}[INFO]${NC} $*"; ((INFO++)); }

# ---------------------------------------------------------------------------
# 1. Docker & Compose
# ---------------------------------------------------------------------------
check_docker() {
  echo -e "${CYAN}── Docker Environment ──${NC}"

  # Docker binary
  if ! command -v docker &>/dev/null; then
    log_fail "docker not found — install: https://docs.docker.com/get-docker/"
    return
  fi

  # Docker daemon
  if ! docker info &>/dev/null; then
    log_fail "docker daemon not running — start Docker Desktop or: sudo systemctl start docker"
    return
  fi

  # Docker version
  local client_ver server_ver
  client_ver=$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'unknown')
  server_ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')
  log_pass "Docker client: $client_ver | server: $server_ver"

  # Docker Compose
  if docker compose version &>/dev/null; then
    local compose_ver
    compose_ver=$(docker compose version --short 2>/dev/null || echo 'unknown')
    log_pass "Docker Compose v2: $compose_ver"
  elif command -v docker-compose &>/dev/null; then
    log_warn "docker-compose v1 detected — upgrade to v2 plugin"
  else
    log_fail "docker compose not found"
  fi

  # Docker root directory disk
  local docker_root
  docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo '/')
  local docker_free
  docker_free=$(df -BG "$docker_root" 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}' || echo '?')
  if [[ "$docker_free" != "?" && "$docker_free" -ge 10 ]]; then
    log_pass "Docker root ($docker_root): ${docker_free}GB free"
  elif [[ "$docker_free" != "?" ]]; then
    log_warn "Docker root ($docker_root): only ${docker_free}GB free (recommend ≥10GB)"
  else
    log_info "Docker root disk: unable to check"
  fi

  # Docker volumes
  local vol_count
  vol_count=$(docker volume ls -q 2>/dev/null | wc -l || echo 0)
  log_info "Docker volumes: $vol_count"

  # Running containers
  local running
  running=$(docker ps -q 2>/dev/null | wc -l || echo 0)
  log_info "Running containers: $running"
}

# ---------------------------------------------------------------------------
# 2. Network Connectivity
# ---------------------------------------------------------------------------
check_network() {
  echo -e "${CYAN}── Network Connectivity ──${NC}"

  # DNS resolution
  if nslookup google.com &>/dev/null; then
    log_pass "DNS resolution working"
  else
    log_fail "DNS resolution failed — check /etc/resolv.conf"
  fi

  # Global internet (Google)
  if curl -sf --connect-timeout 5 --max-time 10 "https://www.google.com" &>/dev/null; then
    log_pass "Global internet (google.com) reachable"
  else
    log_warn "Global internet unreachable (may need proxy or VPN)"
  fi

  # GitHub
  if curl -sf --connect-timeout 5 --max-time 10 "https://github.com" &>/dev/null; then
    log_pass "GitHub reachable"
  else
    log_warn "GitHub unreachable — may need mirror for git operations"
  fi

  # Docker Hub
  if curl -sf --connect-timeout 5 --max-time 10 "https://hub.docker.com" &>/dev/null; then
    log_pass "Docker Hub reachable"
  else
    log_warn "Docker Hub unreachable — pull from Hub will fail without mirrors"
  fi

  # CN mirror check
  local cn_mirrors=(
    "https://docker.m.daocloud.io"
    "https://ghcr.m.daocloud.io"
    "https://mirror.baidubce.com"
  )
  local cn_ok=0
  for mirror in "${cn_mirrors[@]}"; do
    if curl -sf --connect-timeout 5 --max-time 10 "$mirror" &>/dev/null; then
      ((cn_ok++))
    fi
  done
  if [[ $cn_ok -gt 0 ]]; then
    log_pass "CN mirrors accessible ($cn_ok/${#cn_mirrors[@]})"
  else
    log_warn "No CN mirrors accessible — CN acceleration unavailable"
  fi

  # Detect if likely in CN network
  if curl -sf --connect-timeout 5 --max-time 10 "https://www.baidu.com" &>/dev/null; then
    log_info "Likely CN network (baidu.com reachable)"
  else
    log_info "Likely non-CN network"
  fi

  # HTTP proxy
  if [[ -n "${HTTP_PROXY:-}" || -n "${HTTPS_PROXY:-}" || -n "${http_proxy:-}" || -n "${https_proxy:-}" ]]; then
    log_info "HTTP proxy configured: ${HTTP_PROXY:-$HTTPS_PROXY:-$http_proxy:-$https_proxy}"
  fi
}

# ---------------------------------------------------------------------------
# 3. Port Availability
# ---------------------------------------------------------------------------
check_ports() {
  echo -e "${CYAN}── Port Availability ──${NC}"

  local important_ports=(80 443 3000 5432 6379 8080 8443 9090)
  local port_names=("HTTP" "HTTPS" "Grafana" "PostgreSQL" "Redis" "Dashboard" "Alt-HTTPS" "Prometheus")

  for i in "${!important_ports[@]}"; do
    local port="${important_ports[$i]}"
    local name="${port_names[$i]}"

    # Cross-platform port check
    local in_use=false
    if ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null; then
      in_use=true
    elif netstat -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null; then
      in_use=true
    elif lsof -i ":${port}" -sTCP:LISTEN &>/dev/null 2>&1; then
      in_use=true
    fi

    if $in_use; then
      local proc
      proc=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 | grep -oP 'users:\(\(".*?"' || echo '?')
      log_warn "Port $port ($name) in use — $proc"
    else
      log_pass "Port $port ($name) available"
    fi
  done
}

# ---------------------------------------------------------------------------
# 4. Disk Space
# ---------------------------------------------------------------------------
check_disk() {
  echo -e "${CYAN}── Disk Space ──${NC}"

  # Root filesystem
  local root_free root_total root_pct
  read -r root_total root_free root_pct <<< "$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$2); gsub(/G/,"",$4); print $2, $4, $5}')"
  if [[ -n "$root_free" && "$root_free" -ge 20 ]]; then
    log_pass "Root filesystem: ${root_free}GB free (${root_pct} used)"
  elif [[ -n "$root_free" && "$root_free" -ge 5 ]]; then
    log_warn "Root filesystem: ${root_free}GB free (${root_pct} used) — consider cleanup"
  else
    log_fail "Root filesystem critically low: ${root_free}GB free"
  fi

  # HomeLab data directory
  local homelab_dir="${1:-.}"
  if [[ -d "$homelab_dir" ]]; then
    local hl_free
    hl_free=$(df -BG "$homelab_dir" 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
    if [[ -n "$hl_free" ]]; then
      log_info "HomeLab dir ($homelab_dir): ${hl_free}GB free"
    fi
  fi

  # Docker disk usage
  if docker system df &>/dev/null; then
    local docker_size
    docker_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo 'unknown')
    log_info "Docker disk usage: $docker_size"
  fi
}

# ---------------------------------------------------------------------------
# 5. System Resources
# ---------------------------------------------------------------------------
check_system() {
  echo -e "${CYAN}── System Resources ──${NC}"

  # OS
  local os_name
  os_name=$(cat /etc/os-release 2>/dev/null | grep -E '^PRETTY_NAME=' | cut -d'"' -f2 || uname -s)
  log_info "OS: $os_name"

  # Kernel
  local kernel
  kernel=$(uname -r)
  log_info "Kernel: $kernel"

  # Memory
  local mem_total mem_avail
  read -r mem_total mem_avail <<< "$(free -m 2>/dev/null | awk '/^Mem:/ {print $2, $7}' || echo '? ?')"
  if [[ "$mem_total" != "?" ]]; then
    local mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
    if [[ $mem_avail -ge 512 ]]; then
      log_pass "Memory: ${mem_avail}MB available / ${mem_total}MB total (${mem_pct}% used)"
    elif [[ $mem_avail -ge 256 ]]; then
      log_warn "Memory: ${mem_avail}MB available / ${mem_total}MB total (${mem_pct}% used)"
    else
      log_fail "Memory critically low: ${mem_avail}MB available"
    fi
  else
    log_info "Memory: unable to check (Windows/macOS?)"
  fi

  # CPU
  local cpu_cores
  cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo '?')
  log_info "CPU cores: $cpu_cores"

  # Uptime
  local uptime_str
  uptime_str=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')
  log_info "Uptime: $uptime_str"
}

# ---------------------------------------------------------------------------
# 6. CN-Specific Checks
# ---------------------------------------------------------------------------
check_cn_readiness() {
  echo -e "${CYAN}── CN Network Readiness ──${NC}"

  # Daemon.json mirrors
  if [[ -f /etc/docker/daemon.json ]]; then
    local has_mirrors
    has_mirrors=$(grep -c "registry-mirrors" /etc/docker/daemon.json 2>/dev/null || echo 0)
    if [[ "$has_mirrors" -gt 0 ]]; then
      log_pass "Docker daemon.json has mirror config"
    else
      log_warn "Docker daemon.json exists but no mirrors configured"
    fi
  else
    log_warn "No /etc/docker/daemon.json — CN mirrors not configured"
    log_info "  Run: sudo ./scripts/setup-cn-mirrors.sh"
  fi

  # Check compose files for blocked registries
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  local root_dir
  root_dir=$(dirname "$script_dir")
  local stacks_dir="$root_dir/stacks"

  if [[ -d "$stacks_dir" ]]; then
    local blocked=0
    while IFS= read -r file; do
      local count
      count=$(grep -cE 'image:.*(gcr\.io/|ghcr\.io/|k8s\.gcr\.io/|registry\.k8s\.io/|quay\.io/)' "$file" 2>/dev/null || echo 0)
      blocked=$((blocked + count))
    done < <(find "$stacks_dir" -name "docker-compose*.yml" 2>/dev/null)

    if [[ $blocked -gt 0 ]]; then
      log_warn "$blocked image(s) use blocked registries — run: ./scripts/localize-images.sh --check"
    else
      log_pass "No blocked registry images found in compose files"
    fi
  fi

  # Time sync (important for TLS)
  if timedatectl &>/dev/null; then
    local synced
    synced=$(timedatectl 2>/dev/null | grep -i "synchronized" || echo '')
    if echo "$synced" | grep -qi "yes\|active"; then
      log_pass "System clock synchronized (NTP)"
    else
      log_warn "System clock not synchronized — TLS connections may fail"
    fi
  else
    log_info "Time sync: unable to check"
  fi
}

# ---------------------------------------------------------------------------
# 7. Quick Docker Compose Validation
# ---------------------------------------------------------------------------
check_compose_files() {
  echo -e "${CYAN}── Docker Compose Validation ──${NC}"

  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  local root_dir
  root_dir=$(dirname "$script_dir")
  local stacks_dir="$root_dir/stacks"

  [[ -d "$stacks_dir" ]] || { log_warn "stacks/ directory not found"; return; }

  local total=0 errors=0
  while IFS= read -r file; do
    ((total++))
    if docker compose -f "$file" config --quiet &>/dev/null 2>&1; then
      :
    else
      log_fail "Invalid: ${file#$root_dir/}"
      ((errors++))
    fi
  done < <(find "$stacks_dir" -name "docker-compose*.yml" 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "All $total compose files valid"
  else
    log_fail "$errors/$total compose files have errors"
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}=== HomeLab Environment Report Summary ===${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo
  echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}  ${BLUE}INFO: $INFO${NC}"
  echo

  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}⛔ Critical issues found. Fix FAIL items before deploying.${NC}"
    return 2
  elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Warnings present. Review and address as needed.${NC}"
    return 1
  else
    echo -e "${GREEN}✅ Environment looks healthy. Ready to deploy.${NC}"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo
  echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  HomeLab Stack — Environment Health Check  ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
  echo

  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  local root_dir
  root_dir=$(dirname "$script_dir")

  check_docker
  echo
  check_network
  echo
  check_ports
  echo
  check_disk "$root_dir"
  echo
  check_system
  echo
  check_cn_readiness
  echo
  check_compose_files
  echo
  print_summary
}

# Allow sourcing without executing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
