#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — Check reachability of image registries
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

FAIL_COUNT=0
RESULTS=()

check_host() {
    local host="$1"
    local start end latency

    if start=$(date +%s%N 2>/dev/null); then
        if curl -sf --connect-timeout 5 --max-time 10 "https://$host" >/dev/null 2>&1; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            if [[ $latency -lt 500 ]]; then
                RESULTS+=("$(echo -e "${GREEN}[OK]${NC}   $host — ${latency}ms")")
            else
                RESULTS+=("$(echo -e "${YELLOW}[SLOW]${NC} $host — ${latency}ms ⚠️ mirror recommended")")
            fi
        else
            RESULTS+=("$(echo -e "${RED}[FAIL]${NC} $host — timeout ✗ use CN mirror")")
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
}

echo "Checking connectivity to image registries..."
echo ""

# DNS check
if getent hosts github.com &>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   DNS resolution working"
else
    echo -e "${RED}[FAIL]${NC} DNS resolution broken"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Port check
if timeout 3 bash -c 'echo >/dev/tcp/1.1.1.1/443' 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   Port 443 outbound open"
else
    echo -e "${RED}[FAIL]${NC} Port 443 blocked"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if timeout 3 bash -c 'echo >/dev/tcp/1.1.1.1/80' 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   Port 80 outbound open"
else
    echo -e "${RED}[FAIL]${NC} Port 80 blocked"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""

for host in hub.docker.com ghcr.io gcr.io quay.io registry-1.docker.io github.com; do
    check_host "$host"
done

echo ""
printf '%s\n' "${RESULTS[@]}"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}⚠ $FAIL_COUNT unreachable source(s) — run: ./scripts/setup-cn-mirrors.sh${NC}"
else
    echo -e "${GREEN}All registries reachable!${NC}"
fi
