#!/usr/bin/env bash
# =============================================================================
# Auto Recovery — Attempt to recover from common failures
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

RECOVERED=0
FAILED=0
SKIPPED=0

DRY_RUN=false

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--help]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n    Show what would be done without making changes"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Recovery: Fix permissions on acme.json
# ---------------------------------------------------------------------------
recover_acme_permissions() {
  local acme_file="$PROJECT_ROOT/config/traefik/acme.json"
  
  if [[ ! -f "$acme_file" ]]; then
    log_warn "acme.json not found, creating..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY RUN] Would create: $acme_file"
    else
      touch "$acme_file"
      chmod 600 "$acme_file"
      log_info "Created $acme_file with permissions 600"
      ((RECOVERED++))
    fi
    return 0
  fi
  
  local perms
  perms=$(stat -c '%a' "$acme_file" 2>/dev/null || stat -f '%A' "$acme_file" 2>/dev/null || echo "unknown")
  
  if [[ "$perms" != "600" ]]; then
    log_warn "acme.json has incorrect permissions: $perms"
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY RUN] Would fix permissions: chmod 600 $acme_file"
    else
      chmod 600 "$acme_file"
      log_info "Fixed permissions on $acme_file"
      ((RECOVERED++))
    fi
  else
    log_info "acme.json permissions are correct"
    ((SKIPPED++))
  fi
}

# ---------------------------------------------------------------------------
# Recovery: Create missing proxy network
# ---------------------------------------------------------------------------
recover_proxy_network() {
  if docker network inspect proxy &>/dev/null; then
    log_info "Network 'proxy' exists"
    ((SKIPPED++))
    return 0
  fi
  
  log_warn "Network 'proxy' not found"
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create network: proxy"
  else
    docker network create proxy
    log_info "Created network 'proxy'"
    ((RECOVERED++))
  fi
}

# ---------------------------------------------------------------------------
# Recovery: Restart unhealthy containers
# ---------------------------------------------------------------------------
recover_unhealthy_containers() {
  log_step "Checking for unhealthy containers"
  
  local unhealthy
  unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" || echo "")
  
  if [[ -z "$unhealthy" ]]; then
    log_info "No unhealthy containers found"
    ((SKIPPED++))
    return 0
  fi
  
  log_warn "Found unhealthy containers: $unhealthy"
  
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY RUN] Would restart: $container"
    else
      log_info "Restarting $container..."
      if docker restart "$container"; then
        log_info "Successfully restarted $container"
        ((RECOVERED++))
      else
        log_error "Failed to restart $container"
        ((FAILED++))
      fi
    fi
  done <<< "$unhealthy"
}

# ---------------------------------------------------------------------------
# Recovery: Restart containers with high restart count
# ---------------------------------------------------------------------------
recover_crashloop_containers() {
  log_step "Checking for containers in crash loop"
  
  local containers
  containers=$(docker ps -a --format "{{.Names}} {{.Status}}" | grep -E "Restarting \(.*\)" | awk '{print $1}' || echo "")
  
  if [[ -z "$containers" ]]; then
    log_info "No containers in crash loop"
    ((SKIPPED++))
    return 0
  fi
  
  log_warn "Found containers in crash loop: $containers"
  
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY RUN] Would attempt recovery for: $container"
    else
      log_info "Attempting to recover $container..."
      
      # Try to identify the issue from logs
      local last_error
      last_error=$(docker logs --tail 50 "$container" 2>&1 | grep -iE "error|failed|fatal" | tail -5 || echo "")
      
      if [[ -n "$last_error" ]]; then
        log_warn "Last errors from $container:"
        echo "$last_error" | while read -r line; do
          log_warn "  $line"
        done
      fi
      
      # Attempt restart with delay
      sleep 2
      if docker restart "$container"; then
        log_info "Restarted $container - monitoring..."
        sleep 5
        
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
          log_info "$container is now running"
          ((RECOVERED++))
        else
          log_error "$container is still failing"
          ((FAILED++))
        fi
      else
        log_error "Failed to restart $container"
        ((FAILED++))
      fi
    fi
  done <<< "$containers"
}

# ---------------------------------------------------------------------------
# Recovery: Fix disk space issues
# ---------------------------------------------------------------------------
recover_disk_space() {
  log_step "Checking disk space"
  
  local usage_percent
  usage_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  
  if [[ "$usage_percent" -lt 80 ]]; then
    log_info "Disk usage is acceptable: ${usage_percent}%"
    ((SKIPPED++))
    return 0
  fi
  
  log_warn "High disk usage: ${usage_percent}%"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would clean up Docker resources"
    return 0
  fi
  
  # Clean up Docker
  log_info "Cleaning up unused Docker resources..."
  
  # Remove stopped containers
  local stopped_containers
  stopped_containers=$(docker ps -a -q -f "status=exited" | wc -l)
  if [[ $stopped_containers -gt 0 ]]; then
    docker container prune -f
    log_info "Removed $stopped_containers stopped containers"
    ((RECOVERED++))
  fi
  
  # Remove dangling images
  local dangling_images
  dangling_images=$(docker images -f "dangling=true" -q | wc -l)
  if [[ $dangling_images -gt 0 ]]; then
    docker image prune -f
    log_info "Removed $dangling_images dangling images"
    ((RECOVERED++))
  fi
  
  # Remove unused networks
  docker network prune -f 2>/dev/null || true
  
  # Remove old volumes (be careful)
  # docker volume prune -f  # Commented out to avoid data loss
  
  # Check usage again
  local new_usage
  new_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  log_info "Disk usage after cleanup: ${new_usage}% (was ${usage_percent}%)"
}

# ---------------------------------------------------------------------------
# Recovery: Restart failed stack services
# ---------------------------------------------------------------------------
recover_stack() {
  local stack=$1
  local compose_file="$PROJECT_ROOT/stacks/$stack/docker-compose.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    log_warn "Stack $stack not found"
    ((SKIPPED++))
    return 1
  fi
  
  log_step "Attempting to recover stack: $stack"
  
  # Check if any services are not running
  local failed_services
  failed_services=$(docker compose -f "$compose_file" ps --services --filter "status=stopped" 2>/dev/null || echo "")
  
  if [[ -z "$failed_services" ]]; then
    log_info "All services in $stack are running"
    ((SKIPPED++))
    return 0
  fi
  
  log_warn "Failed services in $stack: $failed_services"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would restart stack: $stack"
    return 0
  fi
  
  # Try to restart the stack
  if docker compose -f "$compose_file" up -d; then
    log_info "Successfully restarted stack $stack"
    ((RECOVERED++))
    
    # Wait for services to become healthy
    sleep 10
    
    # Verify
    local still_failed
    still_failed=$(docker compose -f "$compose_file" ps --services --filter "status=stopped" 2>/dev/null || echo "")
    
    if [[ -n "$still_failed" ]]; then
      log_error "Some services still failing: $still_failed"
      ((FAILED++))
    fi
  else
    log_error "Failed to restart stack $stack"
    ((FAILED++))
  fi
}

# ---------------------------------------------------------------------------
# Recovery: Fix .env issues
# ---------------------------------------------------------------------------
recover_env_file() {
  local env_file="$PROJECT_ROOT/.env"
  local env_example="$PROJECT_ROOT/.env.example"
  
  if [[ ! -f "$env_file" ]]; then
    log_error ".env file not found"
    if [[ -f "$env_example" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would copy .env.example to .env"
      else
        cp "$env_example" "$env_file"
        log_info "Created .env from .env.example - please edit it!"
        log_warn "Run: ./scripts/setup-env.sh to configure"
        ((RECOVERED++))
      fi
    fi
    return 1
  fi
  
  log_info ".env file exists"
  ((SKIPPED++))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo -e "${BLUE}=== HomeLab Stack — Auto Recovery ===${NC}"
  
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
  fi
  
  echo ""
  
  recover_acme_permissions
  recover_proxy_network
  recover_unhealthy_containers
  recover_crashloop_containers
  recover_disk_space
  recover_env_file
  
  # Optionally recover specific stacks
  if [[ "${1:-}" != "" && "${1:-}" != "--dry-run" && "${1:-}" != "-n" ]]; then
    recover_stack "$1"
  fi
  
  # Summary
  echo ""
  echo -e "${BLUE}=== Recovery Summary ===${NC}"
  echo -e "  ${GREEN}Recovered: $RECOVERED${NC}"
  echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
  echo -e "  ${RED}Failed: $FAILED${NC}"
  echo
  
  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}Some recovery actions failed. Manual intervention required.${NC}"
    exit 1
  elif [[ "$RECOVERED" -gt 0 ]]; then
    echo -e "${GREEN}Recovery completed successfully.${NC}"
    exit 0
  else
    echo -e "${GREEN}No recovery actions needed.${NC}"
    exit 0
  fi
}

main "$@"
