#!/usr/bin/env bash
# Databases stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Databases Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "postgres"
assert_container_healthy "postgres"
assert_container_running "redis"
assert_container_healthy "redis"

echo "  [Connectivity]"
assert_port_open "localhost" "5432" "PostgreSQL port 5432"
assert_port_open "localhost" "6379" "Redis port 6379"

print_summary
exit $FAIL
