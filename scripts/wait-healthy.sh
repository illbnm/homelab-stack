#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — Docker Compose 健康等待工具
# 等待所有容器健康检查通过,超时后输出错误日志
# =============================================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
STACK_NAME=""
TIMEOUT=300
INTERVAL=5
LOG_LINES=50

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if stack exists
check_stack() {
  if [[ -z "$STACK_NAME" ]]; then
    log_error "Stack name required (--stack)"
    return 1
  fi
  
  # Check if compose file exists
  local compose_file="stacks/$STACK_NAME/docker-compose.yml"
  if [[ ! -f "$compose_file" ]]; then
    compose_file="stacks/$STACK_NAME/docker-compose.local.yml"
  fi
  
  if [[ ! -f "$compose_file" ]]; then
    log_error "Stack not found: $STACK_NAME"
    return 1
  fi
}

# Get containers for stack
get_stack_containers() {
  docker ps --filter "label=com.docker.compose.project=$STACK_NAME" \
            --format '{{.Names}}' 2>/dev/null || echo ""
}

# Check container health
check_container_health() {
  local container="$1"
  local status
  
  status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
  
  case "$status" in
    healthy) return 0 ;;
    unhealthy) return 1 ;;
    starting) return 2 ;;  # Still starting
    none)
      # No health check defined - check if running
      local running
      running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
      if [[ "$running" == "true" ]]; then
        return 0  # Consider running as healthy if no health check
      fi
      return 1
      ;;
    *) return 1 ;;
  esac
}

# Get container status summary
get_container_status() {
  local container="$1"
  docker inspect --format='{{.State.Status}} (Health: {{.State.Health.Status}})' "$container" 2>/dev/null || echo "unknown"
}

# Show unhealthy container logs
show_unhealthy_logs() {
  local containers="$1"
  
  echo ""
  echo -e "${RED}${BOLD}=== Unhealthy Container Logs ===${NC}"
  echo ""
  
  for container in $containers; do
    local status
    status=$(get_container_status "$container")
    
    echo -e "${RED}$container${NC} - $status"
    echo -e "${YELLOW}Last $LOG_LINES log lines:${NC}"
    docker logs --tail "$LOG_LINES" "$container" 2>&1 | sed 's/^/  /'
    echo ""
  done
}

# Check all containers
check_all_containers() {
  local containers
  containers=$(get_stack_containers)
  
  if [[ -z "$containers" ]]; then
    log_error "No containers found for stack: $STACK_NAME"
    return 2
  fi
  
  local all_healthy=true
  local any_unhealthy=false
  local unhealthy_containers=""
  
  for container in $containers; do
    check_container_health "$container"
    local rc=$?
    
    case $rc in
      0)
        echo -e "  ${GREEN}✓${NC} $container - healthy"
        ;;
      1)
        echo -e "  ${RED}✗${NC} $container - unhealthy"
        all_healthy=false
        any_unhealthy=true
        unhealthy_containers="$unhealthy_containers $container"
        ;;
      2)
        echo -e "  ${YELLOW}⏳${NC} $container - starting"
        all_healthy=false
        ;;
    esac
  done
  
  if $any_unhealthy; then
    UNHEALTHY_CONTAINERS="$unhealthy_containers"
    return 1
  fi
  
  $all_healthy && return 0 || return 2
}

# Wait for healthy
wait_for_healthy() {
  log_info "Waiting for stack '$STACK_NAME' to become healthy..."
  log_info "Timeout: ${TIMEOUT}s, Check interval: ${INTERVAL}s"
  echo ""
  
  local start_time
  start_time=$(date +%s)
  local elapsed=0
  
  while [[ $elapsed -lt $TIMEOUT ]]; do
    echo -e "${BLUE}==>${NC} Checking containers... (${elapsed}s / ${TIMEOUT}s)"
    
    UNHEALTHY_CONTAINERS=""
    check_all_containers
    local rc=$?
    
    case $rc in
      0)
        echo ""
        log_info "${GREEN}${BOLD}✓ All containers are healthy!${NC}"
        echo ""
        return 0
        ;;
      1)
        # Unhealthy containers
        show_unhealthy_logs "$UNHEALTHY_CONTAINERS"
        return 1
        ;;
      2)
        # Still starting, continue waiting
        sleep "$INTERVAL"
        elapsed=$(( $(date +%s) - start_time ))
        ;;
    esac
  done
  
  # Timeout
  echo ""
  log_error "Timeout after ${TIMEOUT}s"
  echo ""
  
  # Show status of all containers
  echo -e "${YELLOW}${BOLD}=== Container Status at Timeout ===${NC}"
  check_all_containers
  
  # Show logs for any non-healthy containers
  local containers
  containers=$(get_stack_containers)
  local problem_containers=""
  
  for container in $containers; do
    check_container_health "$container" || problem_containers="$problem_containers $container"
  done
  
  if [[ -n "$problem_containers" ]]; then
    show_unhealthy_logs "$problem_containers"
  fi
  
  return 1
}

# Watch mode - continuous monitoring
watch_mode() {
  log_info "Watching stack '$STACK_NAME' (Ctrl+C to stop)"
  echo ""
  
  while true; do
    clear
    echo -e "${BOLD}Stack: $STACK_NAME${NC}"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    local containers
    containers=$(get_stack_containers)
    
    for container in $containers; do
      local status
      status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
      local health
      health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
      
      local icon
      case "$health" in
        healthy) icon="${GREEN}✓${NC}" ;;
        unhealthy) icon="${RED}✗${NC}" ;;
        starting) icon="${YELLOW}⏳${NC}" ;;
        *) icon="${BLUE}•${NC}" ;;
      esac
      
      echo -e "  $icon $container - $status (health: $health)"
    done
    
    echo ""
    sleep "$INTERVAL"
  done
}

# Usage
usage() {
  cat <<EOF
Usage: $0 --stack <name> [OPTIONS]

Options:
  --stack <name>      Stack/project name (required)
  --timeout <sec>     Timeout in seconds (default: 300)
  --interval <sec>    Check interval in seconds (default: 5)
  --lines <n>         Log lines to show on failure (default: 50)
  --watch             Continuous monitoring mode
  -h, --help          Show this help

Exit codes:
  0 - All containers healthy
  1 - Timeout or unhealthy containers
  2 - Stack not found or no containers

Examples:
  $0 --stack monitoring
  $0 --stack sso --timeout 600
  $0 --stack base --watch

EOF
  exit 0
}

# Main
main() {
  local watch=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --stack) STACK_NAME="$2"; shift ;;
      --timeout) TIMEOUT="$2"; shift ;;
      --interval) INTERVAL="$2"; shift ;;
      --lines) LOG_LINES="$2"; shift ;;
      --watch) watch=true ;;
      -h|--help) usage ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
  done
  
  # Validate
  if [[ -z "$STACK_NAME" ]]; then
    log_error "Stack name required"
    usage
  fi
  
  check_stack || exit 2
  
  if $watch; then
    watch_mode
  else
    wait_for_healthy
    exit $?
  fi
}

# Store unhealthy containers globally
UNHEALTHY_CONTAINERS=""

main "$@"
