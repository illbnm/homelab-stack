 ```diff
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,218 @@
+#!/usr/bin/env bash
+# tests/lib/assert.sh — Assertion library for HomeLab Stack integration tests
+
+set -euo pipefail
+
+# Source common utilities
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || true
+
+# Global counters
+TESTS_PASSED=0
+TESTS_FAILED=0
+TESTS_SKIPPED=0
+CURRENT_TEST_NAME=""
+CURRENT_STACK=""
+
+# Colors (fallback if tput unavailable)
+if command -v tput &>/dev/null && [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ]; then
+    RED=$(tput setaf 1)
+    GREEN=$(tput setaf 2)
+    YELLOW=$(tput setaf 3)
+    BLUE=$(tput setaf 4)
+    CYAN=$(tput setaf 6)
+    BOLD=$(tput bold)
+    RESET=$(tput sgr0)
+else
+    RED=''
+    GREEN=''
+    YELLOW=''
+    BLUE=''
+    CYAN=''
+    BOLD=''
+    RESET=''
+fi
+
+# Set current stack context
+set_stack() {
+    CURRENT_STACK="$1"
+}
+
+# Internal: Print test result
+_print_result() {
+    local status="$1"
+    local duration="${2:-0}"
+    local stack_name="${CURRENT_STACK:-unknown}"
+    
+    if [ -n "${CURRENT_TEST_NAME:-}" ]; then
+        if [ "$status" = "PASS" ]; then
+            echo -e "  [${stack_name}] ▶ ${CURRENT_TEST_NAME} ${GREEN}✅ PASS${RESET} (${duration}s)"
+        elif [ "$status" = "FAIL" ]; then
+            echo -e "  [${stack_name}] ▶ ${CURRENT_TEST_NAME} ${RED}❌ FAIL${RESET} (${duration}s)"
+        else
+            echo -e "  [${stack_name}] ▶ ${CURRENT_TEST_NAME} ${YELLOW}⏭️  SKIP${RESET}"
+        fi
+    fi
+}
+
+# Run a test function with timing and error handling
+run_test() {
+    local test_func="$1"
+    CURRENT_TEST_NAME="${2:-$test_func}"
+    
+    local start_time end_time duration
+    start_time=$(date +%s.%N)
+    
+    if "$test_func" 2>/dev/null; then
+        end_time=$(date +%s.%N)
+        duration=$(awk "BEGIN {printf \"%.1f\", $end_time - $start_time}")
+        TESTS_PASSED=$((TESTS_PASSED + 1))
+        _print_result "PASS" "$duration"
+        return 0
+    else
+        end_time=$(date +%s.%N)
+        duration=$(awk "BEGIN {printf \"%.1f\", $end_time - $start_time}")
+        TESTS_FAILED=$((TESTS_FAILED + 1))
+        _print_result "FAIL" "$duration"
+        return 1
+    fi
+}
+
+# Skip a test with message
+skip_test() {
+    local msg="${1:-}"
+    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
+    _print_result "SKIP" "0"
+    [ -n "$msg" ] && echo "    ${YELLOW}Reason: ${msg}${RESET}"
+}
+
+# Assertions
+
+assert_eq() {
+    local actual="$1"
+    local expected="$2"
+    local msg="${3:-Expected '$expected' but got '$actual'}"
+    
+    if [ "$actual" != "$expected" ]; then
+        echo "    ${RED}ASSERT FAIL: $msg${RESET}" >&2
+        return 1
+    fi
+}
+
+assert_not_empty() {
+    local value="$1"
+    local msg="${2:-Value is empty}"
+    
+    if [ -z "$value" ]; then
+        echo "    ${RED}ASSERT FAIL: $msg${RESET}" >&2
+        return 1
+    fi
+}
+
+assert_exit_code() {
+    local code="$1"
+    local msg="${2:-Expected exit code 0 but got $code}"
+    
+    if [ "$code" -ne 0 ]; then
+        echo "    ${RED}ASSERT FAIL: $msg${RESET}" >&2
+        return 1
+    fi
+}
+
+assert_container_running() {
+    local name="$1"
+    local msg="${2:-Container $name is not running}"
+    
+    if ! docker ps --format '{{.Names}}' | grep -qx "$name"; then
+        echo "    ${RED}ASSERT FAIL: $msg${RESET}" >&2
+        return 1
+    fi
+}
+
+assert_container_healthy() {
+    local name="$1"
+    local max_wait="${2:-60}"
+    local msg="${3:-Container $name is not healthy after ${max_wait}s}"
+    
+    local waited=0
+    while [ $waited -lt "$max_wait" ]; do
+        local status
+        status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
+        if [ "$status" = "healthy" ]; then
+            return 0
+        fi
+        sleep 2
+        waited=$((waited + 2))
+    done
+    
+    echo "    ${RED}ASSERT FAIL: $msg (status: $status)${RESET}" >&2
+    return 1
+}
+
+assert_http_200() {
+    local url="$1"
+    local timeout="${2:-30}"
+    local msg="${3:-HTTP $url did not return 200}"
+    
+    local http_code
+    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
+    
+    if [ "$http_code" != "200" ]; then
+        echo "    ${RED}ASSERT FAIL: $msg (got $http_code)${RESET}" >&2
+        return 1
+    fi
+}
+
+assert_http_response() {
+    local url="$1"
+    local pattern="$2"
+    local timeout="${3:-30}"
+    local msg="${4:-HTTP response from $url does not match pattern}"
+    
+    local response
+   