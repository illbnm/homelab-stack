#!/usr/bin/env bash
# ==============================================================================
# Wait for containers to become healthy
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."

# Defaults
STACK=""
TIMEOUT=300
VERBOSE=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Wait for specific stack containers
  --timeout <sec>   Timeout in seconds (default: 300)
  --verbose         Show detailed output
  --help            Show this help

Examples:
  $(basename "$0") --stack base --timeout 120
  $(basename "$0") --stack databases
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack) STACK="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Get containers for stack
get_stack_containers() {
    local stack="$1"
    local compose_file="$BASE_DIR/stacks/${stack}/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        docker compose -f "$compose_file" ps --format '{{.Name}}' 2>/dev/null || true
    fi
}

# Check container health
check_health() {
    local container="$1"
    local status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
    
    case "$status" in
        healthy) return 0 ;;
        unhealthy) return 1 ;;
        no-healthcheck)
            # If no healthcheck, just check if running
            docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"
            return $?
            ;;
        starting) return 2 ;;
    esac
}

# Print container logs
print_logs() {
    local container="$1"
    echo "--- $container logs (last 50 lines) ---"
    docker logs --tail 50 "$container" 2>&1
    echo "---"
}

# Main
main() {
    local containers=""
    
    if [[ -n "$STACK" ]]; then
        containers=$(get_stack_containers "$STACK")
    else
        containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
    fi
    
    if [[ -z "$containers" ]]; then
        echo "No containers found"
        exit 0
    fi
    
    echo "Waiting for containers to become healthy (timeout: ${TIMEOUT}s)..."
    echo "Containers: $(echo $containers | tr '\n' ' ')"
    
    local elapsed=0
    local interval=5
    
    while [[ $elapsed -lt $TIMEOUT ]]; do
        local all_healthy=true
        local failed=false
        
        while read -r container; do
            [[ -z "$container" ]] && continue
            
            if check_health "$container"; then
                [[ "$VERBOSE" == true ]] && echo "  ✓ $container: healthy"
            elif [[ $? -eq 1 ]]; then
                echo "  ✗ $container: unhealthy"
                failed=true
            else
                [[ "$VERBOSE" == true ]] && echo "  ○ $container: starting..."
                all_healthy=false
            fi
        done <<< "$containers"
        
        if [[ "$all_healthy" == true ]]; then
            echo ""
            echo "All containers healthy!"
            exit 0
        fi
        
        if [[ "$failed" == true ]]; then
            echo ""
            echo "Some containers are unhealthy. Printing logs..."
            while read -r container; do
                [[ -z "$container" ]] && continue
                local status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
                if [[ "$status" == "unhealthy" ]]; then
                    print_logs "$container"
                fi
            done <<< "$containers"
            exit 1
        fi
        
        sleep $interval
        ((elapsed += interval))
        echo "Waiting... ${elapsed}s / ${TIMEOUT}s"
    done
    
    echo ""
    echo "Timeout waiting for containers. Current status:"
    while read -r container; do
        [[ -z "$container" ]] && continue
        local status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        echo "  $container: $status"
        
        if [[ "$status" != "healthy" ]]; then
            print_logs "$container"
        fi
    done <<< "$containers"
    
    exit 1
}

main "$@"