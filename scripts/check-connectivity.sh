#!/usr/bin/env bash
# Network connectivity check for HomeLab deployment
set -euo pipefail

TIMEOUT=5
ISSUES=0

check_host() {
  local name="$1" host="$2"
  local start end latency

  start=$(date +%s%N)
  if curl -sf --connect-timeout $TIMEOUT "https://$host" -o /dev/null 2>/dev/null; then
    end=$(date +%s%N)
    latency=$(( (end - start) / 1000000 ))
    if [ $latency -gt 1000 ]; then
      printf "  [SLOW] %-20s — %dms ⚠️\n" "$name ($host)" "$latency"
    else
      printf "  [OK]   %-20s — %dms\n" "$name ($host)" "$latency"
    fi
  else
    printf "  [FAIL] %-20s — connection timeout ✗\n" "$name ($host)"
    ((ISSUES++))
  fi
}

echo "=== Network Connectivity Check ==="
echo ""

check_host "Docker Hub" "hub.docker.com"
check_host "GitHub" "github.com"
check_host "gcr.io" "gcr.io"
check_host "ghcr.io" "ghcr.io"
check_host "DNS (Google)" "dns.google"

echo ""
if [ $ISSUES -gt 0 ]; then
  echo "⚠️  $ISSUES unreachable sources detected."
  echo "   Suggestion: run ./scripts/setup-cn-mirrors.sh"
else
  echo "✓ All sources reachable"
fi
