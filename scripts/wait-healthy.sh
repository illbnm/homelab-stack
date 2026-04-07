#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
STACKS_DIR="$SCRIPT_DIR/../stacks"

DEFAULT_TIMEOUT=300
POLL_INTERVAL=5

get_health_status() {
  local container=$1
  docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none"
}

get_container_state() {
  local container=$1
  docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown"
}

print_logs() {
  local container=$1
  local lines=${2:-50}
  echo ""
  log_warn "Last $lines lines of $container logs:"
  docker logs --tail "$lines" "$container" 2>&1 | sed 's/^/  /'
}

wait_for_stack() {
  local stack=$1
  local timeout=${2:-$DEFAULT_TIMEOUT}
  
  log_step "Waiting for stack: $stack (timeout: ${timeout}s)"
  
  local compose_file=""
  if [[ -f "$STACKS_DIR/$stack/docker-compose.local.yml" ]]; then
    compose_file="$STACKS_DIR/$stack/docker-compose.local.yml"
  elif [[ -f "$STACKS_DIR/$stack/docker-compose.yml" ]]; then
    compose_file="$STACKS_DIR/$stack/docker-compose.yml"
  else
    log_error "Stack not found: $stack"
    return 2
  fi
  
  local containers
  containers=$(docker compose -f "$compose_file" ps -q 2>/dev/null || true)
  
  if [[ -z "$containers" ]]; then
    log_error "No containers found for stack: $stack"
    return 2
  fi
  
  local container_names=()
  while IFS= read -r container_id; do
    local name
    name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/^///')
    container_names+=("$name")
  done <<< "$containers"
  
  log_info "Monitoring ${#container_names[@]} containers: ${container_names[*]}"
  
  local start_time=$(date +%s)
  local all_healthy=false
  local unhealthy_containers=()
  local exited_containers=()
  
  while true; do
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [[ $elapsed -ge $timeout ]]; then
      log_error "Timeout reached after ${timeout}s"
      break
    fi
    
    all_healthy=true
    unhealthy_containers=()
    exited_containers=()
    
    for container in "${container_names[@]}"; do
      local state
      state=$(get_container_state "$container")
      
      if [[ "$state" == "exited" ]]; then
        exited_containers+=("$container")
        all_healthy=false
      else
        local health
        health=$(get_health_status "$container")
        
        case $health in
          healthy)
            echo -e "${GREEN}✓${NC} $container: healthy"
            ;;
          unhealthy)
            echo -e "${RED}✗${NC} $container: unhealthy"
            unhealthy_containers+=("$container")
            all_healthy=false
            ;;
          starting)
            echo -e "${YELLOW}○${NC} $container: starting"
            all_healthy=false
            ;;
          none)
            if [[ "$state" == "running" ]]; then
              echo -e "${GREEN}✓${NC} $container: running (no health check)"
            else
              echo -e "${YELLOW}?${NC} $container: $state (no health check)"
              all_healthy=false
            fi
            ;;
        esac
      fi
    done
    
    if [[ "$all_healthy" == true ]]; then
      log_info "✓ All containers are healthy!"
      return 0
    fi
    
    local remaining=$((timeout - elapsed))
    echo -e "${BLUE}[${elapsed}s/${timeout}s]${NC} Waiting... (${remaining}s remaining)"
    echo ""
    
    sleep $POLL_INTERVAL
  done
  
  log_error "Health check failed. Diagnostics:"
  
  if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
    for container in "${unhealthy_containers[@]}"; do
      print_logs "$container"
    done
  fi
  
  if [[ ${#exited_containers[@]} -gt 0 ]]; then
    log_error "Exited containers: ${exited_containers[*]}"
    for container in "${exited_containers[@]}"; do
      print_logs "$container"
    done
    return 2
  fi
  
  return 1
}

usage() {
  cat << USAGE_EOF
Usage: $0 [OPTIONS]

Options:
  --stack <name>      Wait for all containers in a stack
  --timeout <seconds> Timeout in seconds (default: $DEFAULT_TIMEOUT)
  --container <name>  Wait for specific container
  --help              Show this help message

Examples:
  $0 --stack base --timeout 300
  $0 --stack monitoring
USAGE_EOF
  exit 1
}

main() {
  local stack=""
  local timeout=$DEFAULT_TIMEOUT
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --stack)
        stack="$2"
        shift 2
        ;;
      --timeout)
        timeout="$2"
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
  
  if [[ -n "$stack" ]]; then
    wait_for_stack "$stack" "$timeout"
    exit $?
  else
    log_error "Must specify --stack"
    usage
  fi
}

main "$@"
