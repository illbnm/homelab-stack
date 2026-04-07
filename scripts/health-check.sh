#!/usr/bin/env bash
# =============================================================================
# Health Check — Monitor stack and service health
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

HEALTHY=0
UNHEALTHY=0
DEGRADED=0

# ---------------------------------------------------------------------------
# Check Docker daemon
# ---------------------------------------------------------------------------
check_docker_daemon() {
  if docker info &>/dev/null; then
    log_info "Docker daemon is running"
    ((HEALTHY++))
    return 0
  else
    log_error "Docker daemon is not running"
    ((UNHEALTHY++))
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Check stack status
# ---------------------------------------------------------------------------
check_stack() {
  local stack=$1
  local compose_file="$PROJECT_ROOT/stacks/$stack/docker-compose.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    log_warn "Stack $stack not found"
    ((DEGRADED++))
    return 1
  fi
  
  # Check if stack is running
  local services
  services=$(docker compose -f "$compose_file" ps --services 2>/dev/null || echo "")
  
  if [[ -z "$services" ]]; then
    log_warn "Stack $stack is not running"
    ((DEGRADED++))
    return 1
  fi
  
  local running=0
  local total=0
  local unhealthy_services=()
  
  while IFS= read -r service; do
    ((total++))
    local status
    status=$(docker compose -f "$compose_file" ps --status running "$service" 2>/dev/null | grep "$service" || echo "")
    
    if [[ -n "$status" ]]; then
      ((running++))
    else
      unhealthy_services+=("$service")
    fi
  done <<< "$services"
  
  if [[ $running -eq $total ]]; then
    log_info "Stack $stack: all $total services running"
    ((HEALTHY++))
    return 0
  elif [[ $running -gt 0 ]]; then
    log_warn "Stack $stack: $running/$total services running (degraded)"
    log_warn "  Unhealthy: ${unhealthy_services[*]}"
    ((DEGRADED++))
    return 1
  else
    log_error "Stack $stack: no services running"
    ((UNHEALTHY++))
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Check service health endpoints
# ---------------------------------------------------------------------------
check_health_endpoints() {
  local stack=$1
  local compose_file="$PROJECT_ROOT/stacks/$stack/docker-compose.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    return 1
  fi
  
  # Extract exposed ports and check health
  local ports
  ports=$(docker compose -f "$compose_file" ps --format json 2>/dev/null | jq -r '.[] | select(.Publishers != null) | .Publishers[]?.PublishedPort // empty' | sort -u || echo "")
  
  if [[ -z "$ports" ]]; then
    return 0
  fi
  
  while IFS= read -r port; do
    [[ -z "$port" ]] && continue
    
    if curl -sf --connect-timeout 2 --max-time 5 "http://localhost:$port" &>/dev/null; then
      log_info "Port $port responding"
      ((HEALTHY++))
    else
      log_warn "Port $port not responding (may be normal for some services)"
      ((DEGRADED++))
    fi
  done <<< "$ports"
}

# ---------------------------------------------------------------------------
# Check Traefik routes
# ---------------------------------------------------------------------------
check_traefik_routes() {
  if ! docker ps | grep -q traefik; then
    log_warn "Traefik is not running"
    ((DEGRADED++))
    return 1
  fi
  
  # Check if Traefik API is accessible
  if curl -sf --connect-timeout 2 --max-time 5 "http://localhost:8080/api/http/services" &>/dev/null; then
    local service_count
    service_count=$(curl -s "http://localhost:8080/api/http/services" 2>/dev/null | jq 'length' || echo "unknown")
    log_info "Traefik is routing $service_count services"
    ((HEALTHY++))
  else
    log_warn "Cannot reach Traefik API (may be normal if dashboard is disabled)"
    ((DEGRADED++))
  fi
}

# ---------------------------------------------------------------------------
# Check network connectivity
# ---------------------------------------------------------------------------
check_networks() {
  log_step "Checking Docker networks"
  
  # Check proxy network
  if docker network inspect proxy &>/dev/null; then
    local connected
    connected=$(docker network inspect proxy | jq '.[0].Containers | length' || echo "unknown")
    log_info "Network 'proxy' has $connected containers"
    ((HEALTHY++))
  else
    log_warn "Network 'proxy' not found"
    ((DEGRADED++))
  fi
  
  # Check internal network
  if docker network inspect internal &>/dev/null; then
    log_info "Network 'internal' exists"
    ((HEALTHY++))
  fi
}

# ---------------------------------------------------------------------------
# Check disk usage for Docker volumes
# ---------------------------------------------------------------------------
check_docker_disk() {
  log_step "Checking Docker disk usage"
  
  local docker_root
  docker_root=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}' || echo "/var/lib/docker")
  
  local usage_percent
  usage_percent=$(df "$docker_root" | awk 'NR==2 {print $5}' | tr -d '%')
  
  if [[ "$usage_percent" -lt 70 ]]; then
    log_info "Docker disk usage: ${usage_percent}%"
    ((HEALTHY++))
  elif [[ "$usage_percent" -lt 85 ]]; then
    log_warn "Docker disk usage: ${usage_percent}% (consider cleanup)"
    ((DEGRADED++))
  else
    log_error "Docker disk usage: ${usage_percent}% (critical)"
    ((UNHEALTHY++))
  fi
  
  # Check volume sizes
  local largest_volumes
  largest_volumes=$(docker system df -v 2>/dev/null | grep -A 100 "Volumes space usage:" | tail -n +2 | sort -k3 -h -r | head -5 || echo "")
  
  if [[ -n "$largest_volumes" ]]; then
    log_info "Largest volumes:"
    echo "$largest_volumes" | while read -r line; do
      log_info "  $line"
    done
  fi
}

# ---------------------------------------------------------------------------
# Check for container restarts
# ---------------------------------------------------------------------------
check_restarts() {
  log_step "Checking for container restarts"
  
  local restarted_containers
  restarted_containers=$(docker ps --filter "status=running" --format "{{.Names}}: {{.Status}}" | grep -i restart || echo "")
  
  if [[ -z "$restarted_containers" ]]; then
    log_info "No containers have restarted recently"
    ((HEALTHY++))
  else
    log_warn "Some containers have restarted:"
    echo "$restarted_containers" | while read -r line; do
      log_warn "  $line"
    done
    ((DEGRADED++))
  fi
}

# ---------------------------------------------------------------------------
# Check logs for errors
# ---------------------------------------------------------------------------
check_logs() {
  log_step "Checking recent logs for errors"
  
  local error_patterns=("error" "failed" "fatal" "exception" "critical")
  local found_errors=0
  
  # Get running containers
  local containers
  containers=$(docker ps --format "{{.Names}}" | head -10)  # Check first 10 to avoid noise
  
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    
    for pattern in "${error_patterns[@]}"; do
      local count
      count=$(docker logs --tail 100 "$container" 2>&1 | grep -ic "$pattern" || echo "0")
      
      if [[ $count -gt 5 ]]; then
        log_warn "Container $container has $count recent '$pattern' entries"
        ((found_errors++))
      fi
    done
  done <<< "$containers"
  
  if [[ $found_errors -eq 0 ]]; then
    log_info "No significant errors in recent logs"
    ((HEALTHY++))
  else
    log_warn "Found $found_errors potential issues in logs"
    ((DEGRADED++))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local stack="${1:-all}"
  
  echo -e "${BLUE}=== HomeLab Stack — Health Check ===${NC}\n"
  
  check_docker_daemon
  check_networks
  
  if [[ "$stack" == "all" ]]; then
    log_step "Checking all stacks"
    
    for stack_dir in "$PROJECT_ROOT"/stacks/*/; do
      [[ ! -d "$stack_dir" ]] && continue
      local stack_name
      stack_name=$(basename "$stack_dir")
      check_stack "$stack_name"
    done
  else
    check_stack "$stack"
  fi
  
  check_traefik_routes
  check_docker_disk
  check_restarts
  check_logs
  
  # Summary
  echo ""
  echo -e "${BLUE}=== Health Summary ===${NC}"
  echo -e "  ${GREEN}Healthy: $HEALTHY${NC}"
  echo -e "  ${YELLOW}Degraded: $DEGRADED${NC}"
  echo -e "  ${RED}Unhealthy: $UNHEALTHY${NC}"
  echo
  
  if [[ "$UNHEALTHY" -gt 0 ]]; then
    echo -e "${RED}System is unhealthy. Check the errors above.${NC}"
    exit 2
  elif [[ "$DEGRADED" -gt 0 ]]; then
    echo -e "${YELLOW}System is degraded. Review warnings above.${NC}"
    exit 1
  else
    echo -e "${GREEN}System is healthy.${NC}"
    exit 0
  fi
}

# Usage info
usage() {
  echo "Usage: $0 [stack-name|all]"
  echo ""
  echo "Examples:"
  echo "  $0              # Check all stacks"
  echo "  $0 all          # Check all stacks"
  echo "  $0 monitoring   # Check only monitoring stack"
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

main "${1:-all}"
