#!/bin/bash
# wait-healthy.sh - Wait for all containers in a stack to be healthy
# Usage: ./scripts/wait-healthy.sh --stack <name> [--timeout <seconds>]
#
# Example:
#   ./scripts/wait-healthy.sh --stack monitoring --timeout 300

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

STACK=""
TIMEOUT=300
INTERVAL=5
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack)
            STACK="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 --stack <name> [--timeout <seconds>] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --stack <name>   Stack name (e.g., monitoring, sso, databases)"
            echo "  --timeout <sec>  Maximum seconds to wait (default: 300)"
            echo "  --verbose        Show detailed output"
            echo ""
            echo "Example:"
            echo "  $0 --stack monitoring --timeout 300"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$STACK" ]; then
    echo "Error: --stack is required"
    echo "Usage: $0 --stack <name> [--timeout <seconds>]"
    exit 1
fi

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Find compose file
COMPOSE_FILE=""
for dir in "$ROOT_DIR" "$ROOT_DIR/stacks"; do
    if [ -f "${dir}/${STACK}/docker-compose.yml" ]; then
        COMPOSE_FILE="${dir}/${STACK}/docker-compose.yml"
        break
    fi
done

if [ -z "$COMPOSE_FILE" ]; then
    error "Stack not found: ${STACK}"
    echo "Available stacks:"
    ls -d "$ROOT_DIR/stacks"/*/ 2>/dev/null | xargs -I {} basename {}
    exit 1
fi

log "Waiting for stack '${STACK}' to be healthy..."
log "Compose file: ${COMPOSE_FILE}"
log "Timeout: ${TIMEOUT}s"
echo ""

# Get list of services in the stack
get_services() {
    docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null
}

# Check if a container is healthy
is_healthy() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

    # If no health check defined, just check if running
    if [ "$status" = "none" ]; then
        local running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
        [ "$running" = "true" ] && return 0 || return 1
    fi

    [ "$status" = "healthy" ] && return 0 || return 1
}

# Get container status
get_status() {
    local container="$1"
    docker inspect --format='{{.State.Health.Status}} ({{.State.Status}})' "$container" 2>/dev/null || echo "not found"
}

# Main wait loop
main() {
    local start_time=$(date +%s)
    local elapsed=0
    local all_healthy=false

    while [ $elapsed -lt $TIMEOUT ]; do
        local not_ready=()
        local ready_count=0
        local total_count=0

        for service in $(get_services); do
            ((total_count++)) || true
            local container=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)

            if [ -z "$container" ]; then
                verbose "Service '${service}': container not found yet"
                not_ready+=("$service")
                continue
            fi

            if is_healthy "$container"; then
                ((ready_count++)) || true
                verbose "Service '${service}': $(get_status "$container")"
            else
                not_ready+=("$service")
                verbose "Service '${service}': $(get_status "$container")"
            fi
        done

        if [ $ready_count -eq $total_count ] && [ $total_count -gt 0 ]; then
            all_healthy=true
            break
        fi

        echo -ne "  Progress: ${ready_count}/${total_count} healthy   \r"
        sleep $INTERVAL
        elapsed=$(($(date +%s) - start_time))
    done

    echo ""

    if [ "$all_healthy" = true ]; then
        echo ""
        log "All $total_count services are healthy!"
        exit 0
    else
        echo ""
        error "Timeout waiting for services to be healthy"
        echo ""
        echo "Services not ready:"
        for service in "${not_ready[@]}"; do
            local container=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
            if [ -n "$container" ]; then
                echo "  - ${service}: $(get_status "$container")"
            else
                echo "  - ${service}: container not found"
            fi
        done
        echo ""
        echo "You can check logs with:"
        echo "  docker compose -f ${COMPOSE_FILE} logs"
        exit 1
    fi
}

main "$@"
