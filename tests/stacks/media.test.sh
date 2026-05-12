#!/usr/bin/env bash
# Media stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Media Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "jellyfin"
assert_container_healthy "jellyfin"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:8096/health" "Jellyfin /health"

print_summary
exit $FAIL
