#!/usr/bin/env bash
# Productivity stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Productivity Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "gitea"
assert_container_running "nextcloud"
assert_container_running "outline"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:3000/api/v1/version" "Gitea /api/v1/version"

print_summary
exit $FAIL
