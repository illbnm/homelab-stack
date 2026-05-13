#!/usr/bin/env bash
# Integration tests for AI stack services
set -euo pipefail

DOMAIN="${DOMAIN:-homelab.local}"
PASS=0
FAIL=0

test_endpoint() {
    local name=$1 url=$2 expected=$3
    echo -n "Testing $name... "
    if curl -sf "$url" 2>/dev/null | grep -q "$expected"; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL (expected: $expected)"
        FAIL=$((FAIL + 1))
    fi
}

test_health() {
    local name=$1 url=$2
    echo -n "Health check: $name... "
    if curl -sf "$url" > /dev/null 2>&1; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

echo "===== AI Stack Integration Tests ====="
echo ""

# Service health checks
test_health "Ollama" "http://ollama.$DOMAIN/api/tags"
test_health "Open WebUI" "http://ai.$DOMAIN/health"
test_health "Stable Diffusion" "http://sd.$DOMAIN"

# API functional tests
test_endpoint "Ollama API" "http://ollama.$DOMAIN/api/tags" "models"
test_endpoint "Open WebUI" "http://ai.$DOMAIN/health" "ok"

echo ""
echo "===== Results: $PASS passed, $FAIL failed ====="
exit $FAIL
