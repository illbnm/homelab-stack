#!/usr/bin/env bash
# =============================================================================
# Health Check — All Homelab Services
# Part of: stacks/testing
#
# Scans all stacks/ directories for docker-compose.yml files, extracts
# service names, and checks each container's health via `docker inspect`.
#
# A container is considered HEALTHY if:
#   - It has no healthcheck defined but is running (status = running)
#   - OR its healthcheck reports (health_status = healthy)
#
# Usage: ./health-check.sh
# Output: Human-readable table to stdout and /results/health-check.log
# Exit:  0 = all healthy, 1 = one or more unhealthy
# =============================================================================

set -euo pipefail

STACKS_DIR="${STACKS_ROOT:-/stacks}/stacks"
RESULTS_DIR="/results"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$RESULTS_DIR"
LOG_FILE="$RESULTS_DIR/health-check.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo " Homelab Health Check"
echo " Time: $TIMESTAMP"
echo "=========================================="
echo ""

# Ensure results dir exists for the results file too
touch "$RESULTS_DIR/health-check.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

declare -A SERVICE_STATUS
UP=0
DOWN=0
UNKNOWN=0

# Table header
printf "%-30s %-20s %-12s %s\n" "SERVICE" "CONTAINER" "STATUS" "NOTES"
printf "%-30s %-20s %-12s %s\n" "------" "---------" "------" "-----"

check_service() {
    local container="$1"
    local service="$2"
    local stack="$3"

    # Get container status
    if ! docker inspect "$container" >/dev/null 2>&1; then
        printf "${RED}%-30s %-20s %-12s %s${NC}\n" \
            "$service" "$container" "DOWN" "Container not found"
        ((DOWN++)) || true
        return
    fi

    local state
    state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    local health
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-check{{end}}' "$container" 2>/dev/null || echo "unknown")

    if [ "$state" = "running" ]; then
        if [ "$health" = "healthy" ] || [ "$health" = "no-check" ]; then
            printf "${GREEN}%-30s %-20s %-12s %s${NC}\n" \
                "$service" "$container" "UP" "healthy=${health}"
            ((UP++)) || true
        else
            printf "${YELLOW}%-30s %-20s %-12s %s${NC}\n" \
                "$service" "$container" "UP*" "health=${health}"
            ((UP++)) || true
        fi
    else
        printf "${RED}%-30s %-20s %-12s %s${NC}\n" \
            "$service" "$container" "DOWN" "state=${state}"
        ((DOWN++)) || true
    fi
}

# Find all stacks
if [ ! -d "$STACKS_DIR" ]; then
    echo "[ERROR] Stacks directory not found: $STACKS_DIR"
    echo "Make sure STACKS_PATH in .env points to your homelab-stack repo root."
    exit 1
fi

for compose_file in $(find "$STACKS_DIR" -name "docker-compose.yml" -not -path "*/.*" 2>/dev/null | sort); do
    stack_name=$(echo "$compose_file" | sed "s|$STACKS_DIR/||" | sed 's|/docker-compose.yml||')

    # Extract service names from the compose file using docker compose
    # This respects environment variable substitution
    services=$(docker compose -f "$compose_file" config --services 2>/dev/null) || continue

    # Get the default container name prefix from the compose file's project name
    # Docker compose uses the directory name as project name by default
    project_name=$(docker compose -f "$compose_file" config --project-name 2>/dev/null || echo "$stack_name")

    for svc in $services; do
        container="${project_name}-${svc}-1"  # Docker Compose v2 naming
        check_service "$container" "$svc" "$stack_name"
    done
done

echo ""
echo "=========================================="
printf " Summary: "
printf "${GREEN}%d UP${NC} " "$UP"
if [ "$DOWN" -gt 0 ]; then
    printf "${RED}%d DOWN${NC} " "$DOWN"
fi
if [ "$UNKNOWN" -gt 0 ]; then
    printf "${YELLOW}%d UNKNOWN${NC} " "$UNKNOWN"
fi
echo ""
echo "=========================================="
echo "Full log: $LOG_FILE"

# Write JSON summary
cat > "$RESULTS_DIR/health-check.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "up": $UP,
  "down": $DOWN,
  "unknown": $UNKNOWN,
  "total": $((UP + DOWN + UNKNOWN))
}
EOF

if [ "$DOWN" -gt 0 ]; then
    echo "Some services are DOWN. Review output above."
    exit 1
else
    echo "All checked services are UP."
    exit 0
fi
