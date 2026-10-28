#!/usr/bin/env bash
set -u

echo "================================================="
echo "   HomeLab Stack: Network Connectivity Probe   "
echo "================================================="

TIMEOUT=5
FAILURES=0

test_probe() {
  local name="$1"
  local url="$2"
  local start
  local end
  local latency
  local http_code

  start=$(date +%s%3N 2>/dev/null || date +%s)
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
  end=$(date +%s%3N 2>/dev/null || date +%s)
  latency=$((end - start))

  if [ "$http_code" != "000" ]; then
    if [ "$latency" -gt 1000 ]; then
      printf "  [SLOW] %-25s — Latency: %4dms (HTTP %s) ⚠️ Recommend mirror\n" "$name" "$latency" "$http_code"
    else
      printf "  [OK]   %-25s — Latency: %4dms (HTTP %s)\n" "$name" "$latency" "$http_code"
    fi
  else
    printf "  [FAIL] %-25s — Connection timed out / unreachable ✗\n" "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "Probing Core Registries and Endpoints:"
test_probe "Docker Hub (hub.docker.com)" "https://hub.docker.com/v2/"
test_probe "GitHub (github.com)" "https://github.com"
test_probe "GitHub Container (ghcr.io)" "https://ghcr.io/v2/"
test_probe "Google Container (gcr.io)" "https://gcr.io/v2/"
test_probe "DaoCloud Mirror" "https://docker.m.daocloud.io/v2/"
test_probe "Tuna Tsinghua Mirror" "https://mirrors.tuna.tsinghua.edu.cn"

echo "Checking Outbound Ports & DNS:"
if host -W 3 google.com >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1 || ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
  echo "  [OK]   DNS Resolution functional"
else
  echo "  [FAIL] DNS Resolution failed"
  FAILURES=$((FAILURES + 1))
fi

echo "================================================="
if [ "$FAILURES" -gt 0 ]; then
  echo "⚠️ Recommendation: Detected $FAILURES unreachable endpoints."
  echo "   Execute './scripts/setup-cn-mirrors.sh' and './scripts/localize-images.sh --cn'."
else
  echo "🎉 All network probes passed! Network environment optimal."
fi
exit 0
