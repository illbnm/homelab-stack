#!/usr/bin/env bash
# Notifications stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Notifications Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "ntfy"
assert_container_healthy "ntfy"
assert_container_running "gotify"
assert_container_healthy "gotify"
assert_container_running "apprise"
assert_container_healthy "apprise"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:80/v1/health" "ntfy /v1/health"
assert_http_200 "http://localhost:8080/health" "Gotify /health"

print_summary
exit $FAIL
