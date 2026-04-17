#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage: ./tests/run-tests.sh [--stack <name>] | [--all] | [--ci]
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")"; pwd)"
BASE_DIR="$(cd "$TESTS_DIR/.."; pwd)"

# Load libraries
source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"
source "$TESTS_DIR/lib/report.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
STACK=""
ALL=false
CI_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)  STACK="$2"; shift 2 ;;
        --all)    ALL=true; shift ;;
        --ci)     CI_MODE=true; ALL=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--stack <name>] [--all] [--ci]"
            echo ""
            echo "Options:"
            echo "  --stack <name>  Run tests for a specific stack"
            echo "  --all           Run all stack tests"
            echo "  --ci            CI mode: run all + generate JSON report"
            echo ""
            echo "Available stacks:"
            for d in "$BASE_DIR"/stacks/*/; do
                echo "  - $(basename "$d")"
            done
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
START_TIME=$(date +%s)
FAILED_TESTS=()

echo -e "\n\033[1m🧪 HomeLab Stack Integration Tests\033[0m"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "   $(hostname)"

# Pre-flight: check docker
describe "Pre-flight checks"
it "Docker daemon is running"
if docker info >/dev/null 2>&1; then
    _TESTS_RUN=$((_TESTS_RUN + 1)); _TESTS_PASSED=$((_TESTS_PASSED + 1))
    echo -e "  ${_GREEN}✓${_NC} Docker is running"
else
    _TESTS_RUN=$((_TESTS_RUN + 1)); _TESTS_FAILED=$((_TESTS_FAILED + 1))
    echo -e "  ${_RED}✗${_NC} Docker is NOT running — aborting"
    exit 1
fi

it "Docker Compose is available"
if docker compose version >/dev/null 2>&1; then
    _TESTS_RUN=$((_TESTS_RUN + 1)); _TESTS_PASSED=$((_TESTS_PASSED + 1))
    echo -e "  ${_GREEN}✓${_NC} docker compose available"
else
    _TESTS_RUN=$((_TESTS_RUN + 1)); _TESTS_FAILED=$((_TESTS_FAILED + 1))
    echo -e "  ${_RED}✗${_NC} docker compose NOT available"
fi

# Determine which tests to run
run_test_file() {
    local test_file="$1"
    if [[ -f "$test_file" ]]; then
        source "$test_file"
    else
        echo -e "  ${_YELLOW}⚠${_NC} Test file not found: $test_file"
    fi
}

if [[ -n "$STACK" ]]; then
    run_test_file "$TESTS_DIR/stacks/${STACK}.test.sh"
elif [[ "$ALL" == "true" ]]; then
    for test_file in "$TESTS_DIR"/stacks/*.test.sh; do
        run_test_file "$test_file"
    done
    if [[ "$CI_MODE" == "true" ]]; then
        for test_file in "$TESTS_DIR"/e2e/*.test.sh; do
            run_test_file "$test_file"
        done
    fi
else
    echo "No stack specified. Use --all or --stack <name>"
    echo "Run $0 --help for usage."
    exit 1
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

print_summary "$_TESTS_RUN" "$_TESTS_PASSED" "$_TESTS_FAILED" "$_TESTS_SKIPPED" "$DURATION"

if [[ "$CI_MODE" == "true" ]]; then
    generate_report "$_TESTS_RUN" "$_TESTS_PASSED" "$_TESTS_FAILED" "$_TESTS_SKIPPED" "$DURATION"
fi

# Exit code
[[ "$_TESTS_FAILED" -eq 0 ]]
