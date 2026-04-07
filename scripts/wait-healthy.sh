#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — Wait for all containers in a stack to become healthy
# Monitors health check status and reports failures
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DEFAULT_TIMEOUT=300
POLL_INTERVAL=5

# ---------------------------------------------------------------------------
# Get stack name from compose file
# ---------------------------------------------------------------------------
get_stack_services() {
  local compose_file=$1
  docker compose -f "$compose_file" config --services 2>/dev/null
}

# ---------------------------------------------------------------------------
# Check if a container is healthy
# ---------------------------------------------------------------------------
is_container_healthy() {
  local container=$1
  local status
  status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "not_found")

  case $status in
    healthy)
      return 0
      ;;
    unhealthy)
      return 1
      ;;
    none)
      # No health check defined, assume healthy if running
      local running
      running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
      [[ "$running" == "true" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Get container status
# ---------------------------------------------------------------------------
get_container_status() {
  local container=$1
  docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found"
}

# ---------------------------------------------------------------------------
# Print container logs
# ---------------------------------------------------------------------------
print_container_logs() {
  local container=$1
  local lines=${2:-50}
  echo -e "\n${YELLOW}=== Logs for $container (last $lines lines) ===${NC}"
  docker logs --tail "$lines" "$container" 2>&1 || true
  echo ""
}

# ---------------------------------------------------------------------------
# Wait for stack to be healthy
# ---------------------------------------------------------------------------
wait_for_stack() {
  local compose_file=$1
  local timeout=$2
  local stack_name
  stack_name=$(basename "$(dirname "$compose_file")")

  log_info "Waiting for stack: ${BOLD}$stack_name${NC}"
  log_info "Timeout: ${timeout}s | Poll interval: ${POLL_INTERVAL}s"
  echo ""

  # Get all services in the stack
  local services
  mapfile -t services < <(get_stack_services "$compose_file")

  if [[ ${#services[@]} -eq 0 ]]; then
    log_error "No services found in $compose_file"
    return 2
  fi

  log_info "Services to monitor: ${services[*]}"
  echo ""

  local start_time
  start_time=$(date +%s)
  local unhealthy_containers=()
  local no_health_check=()

  while true; do
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))

    # Check timeout
    if [[ $elapsed -ge $timeout ]]; then
      log_error "Timeout reached (${timeout}s)"
      echo ""
      print_unhealthy_report "${unhealthy_containers[@]}"
      return 1
    fi

    local all_healthy=true
    unhealthy_containers=()
    no_health_check=()

    echo -ne "\r${BLUE}[${elapsed}s/${timeout}s]${NC} Checking health status... "

    for service in "${services[@]}"; do
      # Get container name for service
      local container
      container=$(docker compose -f "$compose_file" ps -q "$service" 2>/dev/null | head -1)

      if [[ -z "$container" ]]; then
        echo -e "\n${YELLOW}Container for service '$service' not found${NC}"
        all_healthy=false
        continue
      fi

      local container_name
      container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')

      # Check if container is running
      local status
      status=$(get_container_status "$container")

      if [[ "$status" != "running" ]]; then
        echo -e "\n${RED}Container '$container_name' is not running (status: $status)${NC}"
        unhealthy_containers+=("$container_name")
        all_healthy=false
        continue
      fi

      # Check health status
      if is_container_healthy "$container"; then
        echo -ne "${GREEN}✓${NC}" >/dev/null
      else
        local health_status
        health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "unknown")

        if [[ "$health_status" == "none" ]]; then
          no_health_check+=("$container_name")
          echo -ne "${YELLOW}?${NC}" >/dev/null
        else
          unhealthy_containers+=("$container_name")
          echo -ne "${RED}✗${NC}" >/dev/null
        fi
        all_healthy=false
      fi
    done

    if [[ "$all_healthy" == "true" ]]; then
      echo -e "\n${GREEN}✓ All containers are healthy!${NC}"
      print_summary "${#services[@]}" "${#no_health_check[@]}" "$elapsed"
      return 0
    fi

    sleep $POLL_INTERVAL
  done
}

# ---------------------------------------------------------------------------
# Print unhealthy containers report
# ---------------------------------------------------------------------------
print_unhealthy_report() {
  local containers=("$@")

  if [[ ${#containers[@]} -eq 0 ]]; then
    return
  fi

  echo -e "\n${RED}=== Unhealthy Containers ===${NC}"
  for container in "${containers[@]}"; do
    echo -e "  ${RED}✗${NC} $container"
  done
  echo ""

  # Print logs for unhealthy containers
  for container in "${containers[@]}"; do
    print_container_logs "$container" 50
  done
}

# ---------------------------------------------------------------------------
# Print final summary
# ---------------------------------------------------------------------------
print_summary() {
  local total=$1
  local no_health=$2
  local elapsed=$3

  echo ""
  echo -e "${BOLD}=== Health Check Summary ===${NC}"
  echo -e "  Total services:  $total"
  echo -e "  Healthy:         ${GREEN}$((total - no_health))${NC}"
  echo -e "  No health check: ${YELLOW}$no_health${NC}"
  echo -e "  Time elapsed:    ${elapsed}s"
  echo ""
}

# ---------------------------------------------------------------------------
# Find compose file for stack
# ---------------------------------------------------------------------------
find_compose_file() {
  local stack=$1
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
  local project_root
  project_root="$(cd "$script_dir/.."; pwd)"

  # Try different compose file names
  local compose_files=(
    "$project_root/stacks/$stack/docker-compose.yml"
    "$project_root/stacks/$stack/docker-compose.local.yml"
    "$project_root/docker-compose.$stack.yml"
    "$project_root/docker-compose.yml"
  )

  for file in "${compose_files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "$file"
      return 0
    fi
  done

  return 1
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Wait for all containers in a stack to pass health checks.

Options:
  --stack <name>     Stack name (e.g., monitoring, media, base)
  --file <path>      Direct path to docker-compose file
  --timeout <sec>    Maximum wait time (default: ${DEFAULT_TIMEOUT}s)
  -h, --help         Show this help message

Exit codes:
  0 - All containers healthy
  1 - Timeout reached with unhealthy containers
  2 - Stack or compose file not found

Examples:
  # Wait for monitoring stack (default timeout)
  $0 --stack monitoring

  # Wait with custom timeout
  $0 --stack media --timeout 600

  # Wait for specific compose file
  $0 --file ./stacks/observability/docker-compose.yml

Health check behavior:
  - Containers with health checks: Must report "healthy"
  - Containers without health checks: Must be in "running" state
  - Failed containers: Logs are printed automatically

EOF
  exit 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local stack=""
  local compose_file=""
  local timeout=$DEFAULT_TIMEOUT

  while [[ $# -gt 0 ]]; do
    case $1 in
      --stack)
        stack="$2"
        shift 2
        ;;
      --file)
        compose_file="$2"
        shift 2
        ;;
      --timeout)
        timeout="$2"
        shift 2
        ;;
      -h|--help)
        usage
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        ;;
    esac
  done

  # Validate inputs
  if [[ -z "$stack" && -z "$compose_file" ]]; then
    log_error "Must specify --stack or --file"
    usage
  fi

  # Find compose file
  if [[ -n "$stack" ]]; then
    if ! compose_file=$(find_compose_file "$stack"); then
      log_error "Stack not found: $stack"
      log_info "Available stacks:"
      ls -1 "$(dirname "$(find_compose_file base)")" 2>/dev/null || true
      exit 2
    fi
  fi

  if [[ ! -f "$compose_file" ]]; then
    log_error "Compose file not found: $compose_file"
    exit 2
  fi

  log_info "Compose file: $compose_file"
  wait_for_stack "$compose_file" "$timeout"
}

main "$@"
