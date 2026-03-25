#!/bin/bash
# base.test.sh - Base infrastructure tests
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Load environment
if [ -f "${SCRIPT_DIR}/../../.env" ]; then
    export $(grep -E '^[A-Z]' "${SCRIPT_DIR}/../../.env" | xargs 2>/dev/null)
fi

echo "Running Base Infrastructure Tests..."

# Traefik tests
test_start "traefik container is running"
docker ps --format '{{.Names}}' | grep -q "traefik" && test_pass || test_fail

test_start "traefik container is healthy"
if docker ps --format '{{.Names}}' | grep -q "traefik"; then
    local health=$(docker inspect --format='{{.State.Health.Status}}' traefik 2>/dev/null || echo "none")
    [ "$health" = "healthy" ] && test_pass || test_fail "Traefik health: $health"
else
    test_fail "Traefik not found"
fi

test_start "traefik HTTP endpoint accessible"
curl -sf http://localhost:80/api/version >/dev/null 2>&1 && test_pass || test_fail

# Portainer tests
test_start "portainer container is running"
docker ps --format '{{.Names}}' | grep -q "portainer" && test_pass || test_fail

test_start "portainer API accessible"
curl -sf http://localhost:9000/api/status >/dev/null 2>&1 && test_pass || test_fail

# Watchtower tests
test_start "watchtower container is running"
docker ps --format '{{.Names}}' | grep -q "watchtower" && test_pass || test_fail
