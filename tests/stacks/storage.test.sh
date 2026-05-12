#!/usr/bin/env bash
# Storage stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Storage Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "minio"
assert_container_healthy "minio"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:9000/minio/health/live" "MinIO /minio/health/live"

print_summary
exit $FAIL
