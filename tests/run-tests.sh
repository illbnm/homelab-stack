#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage: ./run-tests.sh --stack <name|all> [--json] [--help]
#
# Copyright (c) 2026 思捷娅科技 (SJYKJ)
# License: MIT
# Author: 小米粒 (Xiaomili) - AI Agent
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# Available stacks
ALL_STACKS=(base databases media storage monitoring network productivity ai sso notifications backup)

usage() {
    cat <<EOF
HomeLab Stack — Integration Test Runner

Usage: $0 [options]

Options:
  --stack <name|all>   Run tests for specific stack or all (default: all)
  --json               Output JSON report only (suppress terminal output)
  --list               List available test stacks
  --help               Show this help

Examples:
  $0 --stack base              Test base infrastructure only
  $0 --stack base,media        Test base and media stacks
  $0 --all                     Run all stack tests
  $0 --all --json              Run all tests, JSON output only

Available stacks: ${ALL_STACKS[*]}

Output:
  Terminal: colored test results
  File: tests/results/report.json

Dependencies:
  bash, curl, jq, docker, docker compose (v2)
EOF
    exit 0
}

run_stack_tests() {
    local stack="$1"
    local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

    if [[ ! -f "$test_file" ]]; then
        echo -e "  ${YELLOW}⚠ No test file for stack '$stack'${NC}"
        ((ASSERT_SKIP++))
        return
    fi

    # Source and run the test function
    source "$test_file"
    "test_${stack}_all" 2>/dev/null || true
}

# Parse arguments
STACKS_TO_TEST=()
JSON_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            if [[ "$2" == "all" ]]; then
                STACKS_TO_TEST=("${ALL_STACKS[@]}")
            else
                # Support comma-separated: --stack base,media
                IFS=',' read -ra STACKS_TO_TEST <<< "$2"
            fi
            shift 2
            ;;
        --all)
            STACKS_TO_TEST=("${ALL_STACKS[@]}")
            shift
            ;;
        --json)
            JSON_ONLY=true
            shift
            ;;
        --list)
            echo "Available stacks: ${ALL_STACKS[*]}"
            exit 0
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Default to all
if [[ ${#STACKS_TO_TEST[@]} -eq 0 ]]; then
    STACKS_TO_TEST=("${ALL_STACKS[@]}")
fi

# ---- Pre-flight checks ----
for cmd in docker jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found"
        exit 1
    fi
done

# ---- Run tests ----
cd "$PROJECT_DIR"
print_header
report_init

for stack in "${STACKS_TO_TEST[@]}"; do
    echo ""
    echo -e "${BOLD}[$stack]${NC}"
    run_stack_tests "$stack"
done

# ---- Summary ----
report_summary
exit $?
