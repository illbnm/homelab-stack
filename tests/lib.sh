#!/usr/bin/env bash
# =============================================================================
# Shared test library for homelab-stack
# Provides common assertion, logging, and reporting functions.
# =============================================================================

set -o pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_LIST=()

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_test()  { echo -e "${BLUE}[TEST]${NC} $*"; }
log_section(){ echo -e "\n${CYAN}=== $1 ===${NC}"; }

# Record current test name for failure reporting
_current_test=""

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

test_begin() {
    _current_test="$1"
    ((TESTS_RUN++)) || true
    log_test "Running: $_current_test"
}

test_pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓ PASS${NC}"
}

test_fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗ FAIL${NC}: $*"
    FAILED_LIST+=("  [$_current_test] $*")
}

assert_file_exists() {
    local file="$1"; shift
    local msg="${*:-$file}"
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} File exists: $msg"
        return 0
    else
        echo -e "  ${RED}✗${NC} File missing: $msg"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"; shift
    if command -v "$cmd" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Command available: $cmd"
        return 0
    else
        echo -e "  ${RED}✗${NC} Command not found: $cmd"
        return 1
    fi
}

assert_string_in_file() {
    local pattern="$1"; local file="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Found '${pattern}' in $file"
        return 0
    else
        echo -e "  ${RED}✗${NC} Missing '${pattern}' in $file"
        return 1
    fi
}

assert_docker_compose_valid() {
    local compose_file="$1"
    docker compose -f "$compose_file" config > /dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

test_summary() {
    log_section "Test Summary"
    echo -e "  Total:  ${BLUE}$TESTS_RUN${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failures:${NC}"
        for f in "${FAILED_LIST[@]}"; do echo -e "$f"; done
    fi

    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! 🎉${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Get script directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
