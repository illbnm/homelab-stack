#!/usr/bin/env bash
# Network stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Network Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "adguard"
assert_container_healthy "adguard"
assert_container_running "wireguard"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:3000/control/status" "AdGuard /control/status"

print_summary
exit $FAIL
