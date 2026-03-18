#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Full stack health check
# Usage: ./health-check.sh [--json]
# =============================================================================
set -euo pipefail

JSON_OUTPUT=false
[[ "${1:-}" == "--json" ]] && JSON_OUTPUT=true

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if $JSON_OUTPUT; then
    # Collect data into JSON
    CONTAINERS=$(docker ps -a --format '{{.Names}}|{{.Status}}' 2>/dev/null | jq -Rn '
        [inputs | split("|") | {name: .[0], status: .[1]}]
    ')
    NETWORK=$(docker network inspect proxy --format '{{.Name}}' 2>/dev/null && echo "exists" || echo "missing")
    MEM_PCT=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    TIMESTAMP=$(date -Iseconds)

    jq -n \
        --arg ts "$TIMESTAMP" \
        --argjson containers "$CONTAINERS" \
        --arg network "$NETWORK" \
        --arg mem "$MEM_PCT" \
        --arg disk "$DISK_PCT" \
        '{
            timestamp: $ts,
            containers: $containers,
            proxy_network: $network,
            memory_percent: $mem,
            disk_percent: $disk
        }'
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

    echo "=== HomeLab Health Check ==="
    echo ""

    # Container status
    echo "--- Containers ---"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Cannot list containers"

    # Proxy network
    echo ""
    echo "--- Proxy Network ---"
    if docker network inspect proxy >/dev/null 2>&1; then
        echo -e "${GREEN}✓ proxy network exists${NC}"
        docker network inspect proxy --format '  Containers: {{len .Containers}}' 2>/dev/null
    else
        echo -e "${RED}✗ proxy network missing${NC}"
    fi

    # Resources
    echo ""
    echo "--- Resources ---"
    MEM_PCT=$(free | awk '/Mem/{printf "%.0f%% used (%.1fG / %.1fG)", $3/$2*100, $3/1024/1024, $2/1024/1024}')
    DISK_PCT=$(df -h / | awk 'NR==2{printf "%s used (%s / %s)", $5, $3, $2}')
    echo "  Memory: $MEM_PCT"
    echo "  Disk:   $DISK_PCT"

    # Warnings
    [[ $(free | awk '/Mem/{print int($3/$2*100)}') -gt 90 ]] && echo -e "  ${YELLOW}⚠ Memory > 90%${NC}"
    [[ $(df / | awk 'NR==2{print $5}' | tr -d '%') -gt 90 ]] && echo -e "  ${YELLOW}⚠ Disk > 90%${NC}"

    echo ""
    echo "=== Done ==="
fi
