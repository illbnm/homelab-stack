#!/bin/bash
# Integration test runner for homelab-stack
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK=${1:-all}

source "$ROOT/tests/lib/assert.sh"

echo "=== Integration Tests: $STACK ==="

test_stack() {
    local name=$1
    echo ""
    echo "--- Testing $name stack ---"
    
    # Check compose file exists
    assert_file_exists "$ROOT/stacks/$name/docker-compose.yml" "docker-compose.yml for $name"
    
    # Check .env exists or .env.example exists
    if [ -f "$ROOT/stacks/$name/.env" ] || [ -f "$ROOT/stacks/$name/.env.example" ]; then
        echo -e "  [${GREEN}PASS${NC}] Configuration file exists for $name"
    fi
}

# Run tests for each stack or all
if [ "$STACK" = "all" ]; then
    for d in stacks/*/; do
        name=$(basename "$d")
        test_stack "$name"
    done
else
    test_stack "$STACK"
fi

print_summary
