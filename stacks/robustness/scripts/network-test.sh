#!/usr/bin/env bash
# =============================================================================
# Network Connectivity Test Script
# Part of: stacks/robustness
#
# Tests reachability to key endpoints for both CN and INTL regions.
# Tests: DNS resolution, HTTP reachability, latency.
#
# Usage: ./network-test.sh
# Output: Human-readable summary to stdout; exit code = 0 if all pass
# =============================================================================

set -euo pipefail

REGION="${REGION:-CN}"
TIMEOUT=5   # seconds per request

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((PASS++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((FAIL++)); }
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

test_dns() {
    local host="$1"
    local desc="$2"
    if timeout "$TIMEOUT" drill "$host" @8.8.8.8 +short | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null; then
        log_pass "DNS resolved $host ($desc)"
    else
        log_fail "DNS failed for $host ($desc)"
    fi
}

test_http() {
    local url="$1"
    local desc="$2"
    local code
    code=$(timeout "$TIMEOUT" curl -sS -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    if [ "$code" -ge 200 ] && [ "$code" -lt 500 ]; then
        log_pass "HTTP $code <- $url ($desc)"
    else
        log_fail "HTTP $code <- $url ($desc)"
    fi
}

test_latency() {
    local host="$1"
    local desc="$2"
    local ms
    ms=$(timeout "$TIMEOUT" curl -sS -o /dev/null -w "%{time_total}" --max-time "$TIMEOUT" "https://$host" 2>/dev/null || echo "9.999")
    # Convert to ms
    ms=$(echo "$ms" | awk '{printf "%.0f", $1 * 1000}')
    if [ "${ms%.*}" -lt 200 ]; then
        log_pass "Latency ${ms}ms <- $host ($desc)"
    else
        log_info "Latency ${ms}ms <- $host ($desc)"
    fi
}

echo "=========================================="
echo " Network Connectivity Test"
echo " Region: $REGION"
echo " Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "=========================================="
echo ""

log_info "=== DNS Resolution Tests ==="
test_dns "google.com" "Global DNS benchmark"
test_dns "cloudflare.com" "Cloudflare DNS"
if [ "$REGION" = "CN" ]; then
    test_dns "baidu.com" "China DNS benchmark"
    test_dns "aliyun.com" "Alibaba Cloud"
    test_dns "qq.com" "Tencent"
    test_dns "163.com" "NetEase"
else
    test_dns "google.com" "Google"
    test_dns "github.com" "GitHub"
    test_dns "cloudflare.com" "Cloudflare"
fi

echo ""
log_info "=== HTTP Reachability Tests ==="
test_http "https://www.google.com/generate_204" "Google captive portal"
test_http "https://www.cloudflare.com/cdn-cgi/trace" "Cloudflare CDN"
if [ "$REGION" = "CN" ]; then
    test_http "https://www.baidu.com" "Baidu"
    test_http "https://www.aliyun.com" "Alibaba Cloud"
    test_http "https://www.qq.com" "Tencent QQ"
    test_http "https://www.163.com" "NetEase"
    test_http "https://gs.statcounter.com" "StatCounter (CN-censored)"
else
    test_http "https://www.github.com" "GitHub"
    test_http "https://www.stackoverflow.com" "Stack Overflow"
    test_http "https://www.wikipedia.org" "Wikipedia"
fi

echo ""
log_info "=== Latency Tests ==="
test_latency "www.cloudflare.com" "Cloudflare"
if [ "$REGION" = "CN" ]; then
    test_latency "www.baidu.com" "Baidu"
    test_latency "www.aliyun.com" "Alibaba"
    test_latency "www.qq.com" "Tencent"
else
    test_latency "www.google.com" "Google"
    test_latency "www.github.com" "GitHub"
fi

echo ""
echo "=========================================="
echo " Summary: ${PASS} passed, ${FAIL} failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo "Some tests failed. Review output above."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
