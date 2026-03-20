#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Wait for Healthy Containers
# Waits for all containers in a stack to become healthy
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") --stack <name> [--timeout <seconds>]

Options:
  --stack      Stack name to wait for (e.g., base, media, monitoring)
  --timeout    Maximum wait time in seconds (default: 300)
  --help       Show this help message

Examples:
  $(basename "$0") --stack base --timeout 300
  $(basename "$0") --stack media
EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
STACK_NAME=""
TIMEOUT=300

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            STACK_NAME="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
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

if [[ -z "$STACK_NAME" ]]; then
    log_error "Stack name is required"
    usage
fi

# -----------------------------------------------------------------------------
# Find compose file
# -----------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
COMPOSE_FILE=""

# Check multiple possible locations
for file in \
    "$ROOT_DIR/docker-compose.base.yml" \
    "$ROOT_DIR/stacks/$STACK_NAME/docker-compose.yml" \
    "$ROOT_DIR/stacks/$STACK_NAME/docker-compose.local.yml"
do
    if [[ -f "$file" ]]; then
        COMPOSE_FILE="$file"
        break
    fi
done

if [[ -z "$COMPOSE_FILE" ]]; then
    log_error "Stack not found: $STACK_NAME"
    log_info "Available stacks: $(ls "$ROOT_DIR/stacks" 2>/dev/null | tr '\n' ' ')"
    exit 2
fi

# -----------------------------------------------------------------------------
# Wait for healthy containers
# -----------------------------------------------------------------------------
wait_healthy() {
    log_step "Waiting for healthy containers"
    log_info "Stack: $STACK_NAME"
    log_info "Timeout: ${TIMEOUT}s"
    log_info "Compose file: $COMPOSE_FILE"
    
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local elapsed
        elapsed=$(($(date +%s) - start_time))
        
        if [[ $elapsed -ge $TIMEOUT ]]; then
            log_error "Timeout after ${TIMEOUT}s"
            print_unhealthy_logs
            return 1
        fi
        
        # Get container statuses
        local containers
        containers=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null || echo "[]")
        
        local running=0
        local healthy=0
        local unhealthy=0
        local total=0
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            ((total++))
            local name
            name=$(echo "$line" | jq -r '.Name // empty' 2>/dev/null || echo "")
            local status
            status=$(echo "$line" | jq -r '.Status // empty' 2>/dev/null || echo "")
            local health
            health=$(echo "$line" | jq -r '.Health // empty' 2>/dev/null || echo "")
            
            if [[ "$status" == "running" ]]; then
                ((running++))
                if [[ "$health" == "healthy" ]]; then
                    ((healthy++))
                    log_info "  $name: $status (healthy)"
                else
                    ((unhealthy++))
                    log_warn "  $name: $status (health: starting)"
                fi
            else
                ((unhealthy++))
                log_error "  $name: $status"
            fi
        done <<< "$containers"
        
        # Progress indicator
        echo
        log_info "Progress: $healthy/$total healthy, $running running, $unhealthy issues"
        
        if [[ $healthy -eq $total ]] && [[ $total -gt 0 ]]; then
            log_step "All containers are healthy!"
            log_info "Total time: ${elapsed}s"
            return 0
        fi
        
        sleep 5
    done
}

# -----------------------------------------------------------------------------
# Print logs for unhealthy containers
# -----------------------------------------------------------------------------
print_unhealthy_logs() {
    log_step "Container logs (last 50 lines)"
    
    local services
    services=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null || echo "")
    
    for service in $services; do
        local status
        status=$(docker compose -f "$COMPOSE_FILE" ps "$service" --format json 2>/dev/null | jq -r '.[0].Status' 2>/dev/null || echo "")
        
        if [[ "$status" != "running" ]]; then
            log_warn "=== $service logs ==="
            docker compose -f "$COMPOSE_FILE" logs "$service" --tail 50 2>&1 || true
            echo
        fi
    done
}
# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
wait_healthy
