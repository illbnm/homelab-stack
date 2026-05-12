#!/usr/bin/env bash
# AI stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 AI Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "ollama"
assert_container_running "open-webui"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:11434/api/version" "Ollama /api/version"

print_summary
exit $FAIL
