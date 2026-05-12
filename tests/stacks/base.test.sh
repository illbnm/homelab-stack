#!/usr/bin/env bash
# Base infrastructure tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Base Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "traefik"
assert_container_healthy "traefik"
assert_container_running "portainer"
assert_container_running "watchtower"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:8080/api/version" "Traefik API /api/version"
assert_http_200 "http://localhost:9000/api/status" "Portainer /api/status"

print_summary
exit $FAIL
