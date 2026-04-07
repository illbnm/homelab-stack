#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — Wait for Docker Compose Services to be Healthy
# =============================================================================
# Monitors docker compose services and waits for all to reach healthy state
# or timeout. Provides detailed error reporting and progress updates.
#
# Usage:
#   ./wait-healthy.sh [OPTIONS] [COMPOSE_FILE]
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
DEFAULT_TIMEOUT=300  # 5 minutes
DEFAULT_INTERVAL=5   # 5 seconds
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>${NC} $*"; }

# Get service health status
get_service_health() {
  local service="$1"
  local compose_file="${2:-}"

  local compose_cmd="docker compose"
  if [[ -n "$compose_file" ]]; then
    compose_cmd="docker compose -f $compose_file"
  fi

  # Get health status using docker compose ps
  local health
  health=$($compose_cmd ps --format json 2>/dev/null | jq -r ".[] | select(.Service == \"$service\") | .Health" || echo "unknown")

  echo "$health"
}

# Get all services from compose file
get_services() {
  local compose_file="${1:-}"

  local compose_cmd="docker compose"
  if [[ -n "$compose_file" ]]; then
    compose_cmd="docker compose -f $compose_file"
  fi

  $compose_cmd config --services 2>/dev/null
}

# Check if service has health check configured
has_healthcheck() {
  local service="$1"
  local compose_file="${2:-}"

  local compose_cmd="docker compose"
  if [[ -n "$compose_file" ]]; then
    compose_cmd="docker compose -f $compose_file"
  fi

  # Check if service has healthcheck in compose config
  local config
  config=$($compose_cmd config 2>/dev/null)

  if echo "$config" | grep -A 20 "service.*$service" | grep -q "healthcheck"; then
    return 0
  else
    return 1
  fi
}

# Wait for all services in compose file
wait_all_healthy() {
  local compose_file="${1:-}"
  local timeout="${2:-$DEFAULT_TIMEOUT}"
  local verbose="${3:-false}"

  local compose_cmd="docker compose"
  if [[ -n "$compose_file" ]]; then
    compose_cmd="docker compose -f $compose_file"
  fi

  log_step "Waiting for all services to be healthy (timeout: ${timeout}s)"

  # Get all services
  local services
  services=$(get_services "$compose_file")

  if [[ -z "$services" ]]; then
    log_error "No services found in compose file"
    return 1
  fi

  local service_count
  service_count=$(echo "$services" | wc -l)
  log_info "Found $service_count service(s): $(echo "$services" | tr '\n' ' ')"

  local start_time
  start_time=$(date +%s)
  local end_time=$((start_time + timeout))

  local failed_services=()
  local healthy_services=()

  # Progress tracking
  local last_status_time=0

  # Wait loop
  while [[ $(date +%s) -lt $end_time ]]; do
    local all_healthy=true
    healthy_services=()

    # Check each service
    while IFS= read -r service; do
      [[ -z "$service" ]] && continue

      local health
      health=$(get_service_health "$service" "$compose_file")

      if [[ "$verbose" == "true" ]]; then
        log_info "  $service: $health"
      fi

      case "$health" in
        healthy)
          healthy_services+=("$service")
          ;;
        unhealthy)
          all_healthy=false
          if [[ ! " ${failed_services[*]} " =~ " ${service} " ]]; then
            failed_services+=("$service")
            log_warn "Service '$service' became unhealthy"
          fi
          ;;
        starting|"")
          all_healthy=false
          ;;
      esac
    done <<< "$services"

    # Check if all healthy
    if [[ "$all_healthy" == "true" ]]; then
      log_info "✓ All services are healthy!"
      return 0
    fi

    # Progress update every 10 seconds
    local current_time
    current_time=$(date +%s)
    if [[ $((current_time - last_status_time)) -ge 10 ]]; then
      local elapsed=$((current_time - start_time))
      local remaining=$((timeout - elapsed))
      local healthy_count=${#healthy_services[@]}
      log_info "Progress: $healthy_count/$service_count healthy (${elapsed}s elapsed, ${remaining}s remaining)"
      last_status_time=$current_time
    fi

    sleep 2
  done

  # Timeout - report status
  log_error "✗ Timeout reached. Not all services became healthy."
  echo

  # Detailed status report
  log_step "Final Status Report"

  while IFS= read -r service; do
    [[ -z "$service" ]] && continue

    local health
    health=$(get_service_health "$service" "$compose_file")

    case "$health" in
      healthy)
        echo -e "  ${GREEN}✓${NC} $service: $health"
        ;;
      unhealthy)
        echo -e "  ${RED}✗${NC} $service: $health"
        ;;
      starting)
        echo -e "  ${YELLOW}⋯${NC} $service: $health"
        ;;
      *)
        echo -e "  ${BLUE}?${NC} $service: $health"
        ;;
    esac
  done <<< "$services"

  # Show logs for failed services
  if [[ ${#failed_services[@]} -gt 0 ]]; then
    echo
    log_error "Failed services: ${failed_services[*]}"
    log_info "Showing last 20 log lines for each failed service:"

    for service in "${failed_services[@]}"; do
      echo
      log_info "=== Logs for $service ==="
      $compose_cmd logs --tail=20 "$service"
    done
  fi

  return 1
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 [OPTIONS] [COMPOSE_FILE]

${BOLD}Options:${NC}
  -t, --timeout SECONDS    Timeout in seconds (default: $DEFAULT_TIMEOUT)
  -a, --all                Wait for all services (default)
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message

${BOLD}Examples:${NC}
  # Wait for all services in default compose file
  $0

  # Wait for all services with custom timeout
  $0 -t 600 docker-compose.yml

  # Verbose output
  $0 -v docker-compose.yml

${BOLD}Exit Codes:${NC}
  0 - All services healthy
  1 - Timeout or unhealthy services
EOF
}

# Main entry point
main() {
  local timeout="$DEFAULT_TIMEOUT"
  local compose_file=""
  local verbose="false"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--timeout)
        timeout="$2"
        shift 2
        ;;
      -v|--verbose)
        verbose="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        # Positional argument - compose file
        if [[ -z "$compose_file" ]]; then
          compose_file="$1"
        fi
        shift
        ;;
    esac
  done

  # Validate compose file if specified
  if [[ -n "$compose_file" ]] && [[ ! -f "$compose_file" ]]; then
    log_error "Compose file not found: $compose_file"
    exit 1
  fi

  # Execute
  wait_all_healthy "$compose_file" "$timeout" "$verbose"
}

main "$@"
