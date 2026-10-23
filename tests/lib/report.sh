#!/usr/bin/env bash
# Terminal and JSON reporting utilities

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

PASSED_TESTS=0
FAILED_TESTS=0

report_pass() {
    local test_name="$1"
    echo -e "${GREEN}[PASS]${NC} $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

report_fail() {
    local test_name="$1"
    local reason="${2:-Assertion failed}"
    echo -e "${RED}[FAIL]${NC} $test_name: $reason"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

report_summary() {
    echo ""
    echo "========================================="
    echo " TEST SUMMARY"
    echo " Total: $((PASSED_TESTS + FAILED_TESTS)) | Passed: $PASSED_TESTS | Failed: $FAILED_TESTS"
    echo "========================================="
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}
