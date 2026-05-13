#!/usr/bin/env bash
# Run all integration tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOTAL_PASS=0
TOTAL_FAIL=0

echo "=========================================="
echo "  Homelab Stack - Full Integration Suite"
echo "=========================================="
echo ""

# Find and run all test scripts
for test_script in $(find "$ROOT_DIR/stacks" -name "test_*.sh" | sort); do
    rel_path="${test_script#$ROOT_DIR/}"
    echo ""
    echo "--- Running: $rel_path ---"
    echo ""
    if bash "$test_script"; then
        echo "  SUITE PASSED"
    else
        echo "  SUITE FAILED"
    fi
    echo ""
done

# Run docker health checks
echo "=========================================="
echo "  Docker Container Status"
echo "=========================================="
echo ""
docker ps --format "table {{.Names}}	{{.Status}}	{{.Ports}}" 2>/dev/null || echo "Docker not available"

echo ""
echo "=========================================="
echo "  Tests Complete"
echo "=========================================="
