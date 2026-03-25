#!/bin/bash
# notifications.test.sh - Notification stack tests
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Load environment
if [ -f "${SCRIPT_DIR}/../../.env" ]; then
    export $(grep -E '^[A-Z]' "${SCRIPT_DIR}/../../.env" | xargs 2>/dev/null)
fi

echo "Running Notification Stack Tests..."

# ntfy tests
test_start "ntfy container is running"
docker ps --format '{{.Names}}' | grep -q "ntfy" && test_pass || test_fail

test_start "ntfy container is healthy"
if docker ps --format '{{.Names}}' | grep -q "ntfy"; then
    local health=$(docker inspect --format='{{.State.Health.Status}}' ntfy 2>/dev/null || echo "none")
    [ "$health" = "healthy" ] && test_pass || test_fail "ntfy health: $health"
else
    test_fail "ntfy not found"
fi

test_start "ntfy health endpoint"
curl -sf http://ntfy:80/v1/health >/dev/null 2>&1 && test_pass || test_fail

# gotify tests
test_start "gotify container is running"
docker ps --format '{{.Names}}' | grep -q "gotify" && test_pass || test_fail

test_start "gotify health endpoint"
curl -sf http://gotify:80/health >/dev/null 2>&1 && test_pass || test_fail

# apprise tests
test_start "apprise container is running"
docker ps --format '{{.Names}}' | grep -q "apprise" && test_pass || test_fail

test_start "apprise web UI accessible"
curl -sf http://apprise:8000/ >/dev/null 2>&1 && test_pass || test_fail

# notify.sh script tests
test_start "notify.sh script exists"
[ -f "${SCRIPT_DIR}/../../scripts/notify.sh" ] && test_pass || test_fail

test_start "notify.sh is executable"
[ -x "${SCRIPT_DIR}/../../scripts/notify.sh" ] && test_pass || test_fail

# Network connectivity tests
test_start "ntfy reachable from apprise"
docker exec apprise wget -qO- http://ntfy:80/v1/health >/dev/null 2>&1 && test_pass || test_fail
