```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,138 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Entry Point
+# Usage: ./run-tests.sh [--stack <name> | --all] [--ci] [--verbose]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+TEST_DIR="$SCRIPT_DIR"
+LIB_DIR="$TEST_DIR/lib"
+STACKS_DIR="$TEST_DIR/stacks"
+E2E_DIR="$TEST_DIR/e2e"
+
+# Source libraries
+source "$LIB_DIR/assert.sh"
+source "$LIB_DIR/docker.sh"
+source "$LIB_DIR/report.sh"
+
+# Global state
+declare -g CI_MODE="${CI_MODE:-false}"
+declare -g VERBOSE="${VERBOSE:-false}"
+declare -g SELECTED_STACK=""
+declare -g RUN_ALL=false
+declare -g TOTAL_PASSED=0
+declare -g TOTAL_FAILED=0
+declare -g TOTAL_SKIPPED=0
+declare -g TEST_START_TIME=""
+
+# Parse arguments
+parse_args() {
+    while [[ $# -gt 0 ]]; do
+        case "$1" in
+            --stack)
+                SELECTED_STACK="$2"
+                shift 2
+                ;;
+            --all)
+                RUN_ALL=true
+                shift
+                ;;
+            --ci)
+                CI_MODE=true
+                shift
+                ;;
+            --verbose)
+                VERBOSE=true
+                shift
+                ;;
+            -h|--help)
+                echo "Usage: $0 [--stack <name> | --all] [--ci] [--verbose]"
+                echo ""
+                echo "Options:"
+                echo "  --stack <name>  Run tests for a specific stack"
+                echo "  --all           Run all tests"
+                echo "  --ci            CI mode (no TTY, JSON output)"
+                echo "  --verbose       Verbose output"
+                echo "  -h, --help      Show this help"
+                exit 0
+                ;;
+            *)
+                echo "Unknown option: $1" >&2
+                exit 1
+                ;;
+        esac
+    done
+
+    if [[ -z "$SELECTED_STACK" && "$RUN_ALL" == false ]]; then
+        echo "Error: Must specify --stack <name> or --all" >&2
+        exit 1
+    fi
+}
+
+# Run a single test file
+run_test_file() {
+    local file="$1"
+    local stack_name
+    stack_name="$(basename "$file" .test.sh)"
+
+    report_section "$stack_name"
+
+    # Source the test file in a subshell to isolate
+    (
+        source "$file"
+
+        # Find and run all test_* functions
+        local tests
+        tests=$(compgen -A function | grep '^test_' || true)
+
+        for test_func in $tests; do
+            run_single_test "$stack_name" "$test_func"
+        done
+    )
+}
+
+# Main execution
+main() {
+    parse_args "$@"
+
+    report_header
+    TEST_START_TIME=$(date +%s)
+
+    if [[ "$RUN_ALL" == true ]]; then
+        for test_file in "$STACKS_DIR"/*.test.sh; do
+            [[ -f "$test_file" ]] || continue
+            run_test_file "$test_file"
+        done
+
+        # Run e2e tests
+        for e2e_file in "$E2E_DIR"/*.test.sh; do
+            [[ -f "$e2e_file" ]] || continue
+            run_test_file "$e2e_file"
+        done
+    else
+        local test_file="$STACKS_DIR/${SELECTED_STACK}.test.sh"
+        if [[ ! -f "$test_file" ]]; then
+            echo "Error: No test file found for stack '$SELECTED_STACK'" >&2
+            exit 1
+        fi
+        run_test_file "$test_file"
+    fi
+
+    report_footer "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED" \
+        "$(($(date +%s) - TEST_START_TIME))"
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,208 @@
+#!/usr/bin/env bash
+# Assertion library for HomeLab Stack integration tests
+
+source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
+
+# Internal: Track assertion state
+_assert_failed=false
+
+# Reset assertion state for a new test
+assert_reset() {
+    _assert_failed=false
+}
+
+# Check if any assertion failed
+assert_did_fail() {
+    [[ "$_assert_failed" == true ]]
+}
+
+# ----------------------------------------------------------------------------
+# Basic assertions
+# ----------------------------------------------------------------------------
+
+assert_eq() {
+    local actual="$1"
+    local expected="$2"
+    local msg="${3:-Expected '$expected' but got '$actual'}"
+
+    if [[ "$actual" != "$expected" ]]; then
+        _assert_failed=true
+        report_test_fail "$msg"
+        return 1
+    fi
+    return 0
+}
+
+assert_not_empty() {
+    local value="$1"
+    local msg="${2:-Expected non-empty value}"
+
+    if [[ -z "$value" ]]; then
+        _assert_failed=true
+        report_test_fail "$msg"
+        return 1
+    fi
+    return 0
+}
+
+assert_exit_code() {
+    local code="$1"
+    local msg="${2:-Expected exit code $code}"
+    local last_code="$?"
+
+    if [[ "$last_code" -ne "$code" ]]; then
+        _assert_failed=true
+        report_test_fail "$msg (got $last_code)"
+        return 1
+    fi
+    return 0
+}
+
+# ----------------------------------------------------------------------------
+# Docker assertions
+# ----------------------------------------------------------------------------
+
+assert_container_running() {
+    local name="$1"
+    local msg="${2:-Container $name is not running}"
+
+    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+        _assert_failed=true
+        report_test_fail "$msg"
+        return 1
+    fi
+    return 0
+}
+
+assert_container_healthy() {
+    local name="$1"
+    local timeout="${2:-60}"
+    local msg="${3:-Container $name did not become healthy within ${timeout}s}"
+
+    local elapsed=0
+    while [[ $elapsed