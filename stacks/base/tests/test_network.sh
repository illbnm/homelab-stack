#!/usr/bin/env bash
# Network stack integration tests
set -euo pipefail

DOMAIN="${DOMAIN:-homelab.local}"
PASS=0
FAIL=0

test_dns() {
    local name=$1 host=$2
    echo -n "DNS resolve: $name... "
    if host "$host" > /dev/null 2>&1 || nslookup "$host" > /dev/null 2>&1; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

test_port() {
    local name=$1 host=$2 port=$3
    echo -n "Port open: $name... "
    if timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

echo "===== Network Integration Tests ====="
echo ""
test_dns "Traefik" "traefik.$DOMAIN"
test_dns "Docker DNS" "host.docker.internal"
test_port "HTTPS" "localhost" 443
test_port "DNS" "localhost" 53

echo ""
echo "===== Results: $PASS passed, $FAIL failed ====="
exit $FAIL
