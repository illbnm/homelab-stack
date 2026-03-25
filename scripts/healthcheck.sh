#!/bin/bash
# =============================================================================
# healthcheck.sh - Container health monitoring
# Usage: ./healthcheck.sh [--notify]
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Configuration
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-health}"
NOTIFY="${1:-}"

# Get all containers
CONTAINERS=$(docker ps -a --format '{{.Names}}')

UNHEALTHY=""
TOTAL=0
HEALTHY=0

for container in $CONTAINERS; do
    TOTAL=$((TOTAL + 1))
    
    # Get health status
    HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    
    case "$HEALTH" in
        healthy)
            HEALTHY=$((HEALTHY + 1))
            ;;
        unhealthy)
            UNHEALTHY="${UNHEALTHY}${container}\n"
            ;;
        none)
            # Container has no health check
            ;;
    esac
done

# Summary
echo "======================================"
echo "Container Health Summary"
echo "======================================"
echo "Total: $TOTAL"
echo -e "Healthy: ${GREEN}$HEALTHY${NC}"
echo -e "Unhealthy: ${RED}$(echo -e "$UNHEALTHY" | grep -c . || echo 0)${NC}"
echo "======================================"

if [[ -n "$UNHEALTHY" ]]; then
    echo -e "${RED}Unhealthy Containers:${NC}"
    echo -e "$UNHEALTHY"
fi

# Send notification if requested and there are unhealthy containers
if [[ "$NOTIFY" == "--notify" && -n "$UNHEALTHY" ]]; then
    curl -sf -X POST "${NTFY_URL}/${NTFY_TOPIC}" \
        -H "Title: Container Health Alert" \
        -H "Priority: high" \
        -H "Tags: warning,docker" \
        -d "Unhealthy containers: $(echo -e "$UNHEALTHY" | tr '\n' ', ')" || true
fi

# Exit with error if unhealthy
if [[ -n "$UNHEALTHY" ]]; then
    exit 1
fi

exit 0
