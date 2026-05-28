#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
STACKS_DIR="$SCRIPT_DIR/../stacks"

# Source assertion library
source "$LIB_DIR/assert.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test registry
declare -a TEST_SUITES=()

register_suite() {
    TEST_SUITES+=("$1")
}

run_suite() {
    local suite_name="$1"
    local suite_file="$2"
    echo -e "${YELLOW}▶ Running suite: $suite_name${NC}"
    if source "$suite_file"; then
        echo -e "${GREEN}  ✅ Suite $suite_name completed${NC}"
    else
        echo -e "${RED}  ❌ Suite $suite_name failed${NC}"
        return 1
    fi
}

# Parse arguments
STACK_FILTER=""
RUN_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            STACK_FILTER="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--stack <name>|--all]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   HomeLab Stack — Integration Tests                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Level 1: Base Infrastructure Tests
if [[ -z "$STACK_FILTER" ]] || [[ "$STACK_FILTER" == "base" ]] || $RUN_ALL; then
    source "$SCRIPT_DIR/stacks/base.test.sh"
fi

# Level 2: HTTP Endpoint Tests
if [[ -z "$STACK_FILTER" ]] || [[ "$STACK_FILTER" == "http" ]] || $RUN_ALL; then
    source "$SCRIPT_DIR/stacks/http.test.sh"
fi

# Level 3: Service Intercommunication Tests
if [[ -z "$STACK_FILTER" ]] || [[ "$STACK_FILTER" == "network" ]] || $RUN_ALL; then
    source "$SCRIPT_DIR/stacks/network.test.sh"
fi

# Level 4: SSO Flow Tests
if [[ -z "$STACK_FILTER" ]] || [[ "$STACK_FILTER" == "sso" ]] || $RUN_ALL; then
    source "$SCRIPT_DIR/e2e/sso-flow.test.sh"
fi

# Level 5: Configuration Integrity Tests
if [[ -z "$STACK_FILTER" ]] || [[ "$STACK_FILTER" == "config" ]] || $RUN_ALL; then
    source "$SCRIPT_DIR/stacks/config.test.sh"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Test Summary"
echo "═══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed:  $TESTS_FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0