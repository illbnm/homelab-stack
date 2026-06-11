 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Runner
+# Usage: ./run-tests.sh [--stack <name> | --all] [--verbose]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+
+# Source libraries
+source "${SCRIPT_DIR}/lib/assert.sh"
+source "${SCRIPT_DIR}/lib/docker.sh"
+source "${SCRIPT_DIR}/lib/report.sh"
+
+# Globals
+VERBOSE=${VERBOSE:-0}
+SELECTED_STACK=""
+RUN_ALL=0
+TOTAL_TESTS=0
+PASSED_TESTS=0
+FAILED_TESTS=0
+START_TIME=""
+
+#######################################
+# Parse CLI arguments
+#######################################
+parse_args() {
+  while [[ $# -gt 0 ]]; do
+    case "$1" in
+      --stack)
+        SELECTED_STACK="$2"
+        shift 2
+        ;;
+      --all)
+        RUN_ALL=1
+        shift
+        ;;
+      --verbose)
+        VERBOSE=1
+        shift
+        ;;
+      *)
+        echo "Unknown option: $1" >&2
+        echo "Usage: $0 [--stack <name> | --all] [--verbose]" >&2
+        exit 1
+        ;;
+    esac
+  done
+}
+
+#######################################
+# Discover and run test files
+#######################################
+run_test_file() {
+  local file="$1"
+  local stack_name
+  stack_name="$(basename "$file" .test.sh)"
+
+  report_stack_header "$stack_name"
+
+  # Source the test file in a subshell to isolate functions
+  (
+    # shellcheck source=/dev/null
+    source "$file"
+
+    # Find all test functions
+    local funcs
+    funcs=$(grep -oE '^test_[a-zA-Z0-9_]+\(\)' "$file" | sed 's/()//' | sort)
+
+    for func in $funcs; do
+      ((TOTAL_TESTS++)) || true
+      local test_start
+      test_start=$(date +%s)
+
+      if $func > /tmp/test_output_$$.log 2>&1; then
+        local test_end
+        test_end=$(date +%s)
+        local duration=$((test_end - test_start))
+        report_test_pass "$stack_name" "$func" "$duration"
+        ((PASSED_TESTS++)) || true
+      else
+        local test_end
+        test_end=$(date +%s)
+        local duration=$((test_end - test_start))
+        report_test_fail "$stack_name" "$func" "$duration" "$(cat /tmp/test_output_$$.log)"
+        ((FAILED_TESTS++)) || true
+      fi
+    done
+  )
+}
+
+#######################################
+# Main
+#######################################
+main() {
+  parse_args "$@"
+
+  # Validate selection
+  if [[ -z "$SELECTED_STACK" && "$RUN_ALL" -eq 0 ]]; then
+    echo "Usage: $0 [--stack <name> | --all] [--verbose]" >&2
+    echo "Available stacks:" >&2
+    ls -1 "${SCRIPT_DIR}/stacks/"*.test.sh 2>/dev/null | sed 's|.*/||; s|\.test\.sh$||' | sed 's/^/  - /' >&2
+    exit 1
+  fi
+
+  report_header
+  START_TIME=$(date +%s)
+
+  if [[ "$RUN_ALL" -eq 1 ]]; then
+    for f in "${SCRIPT_DIR}/stacks/"*.test.sh; do
+      [[ -f "$f" ]] && run_test_file "$f"
+    done
+    # E2E tests
+    for f in "${SCRIPT_DIR}/e2e/"*.test.sh; do
+      [[ -f "$f" ]] && run_test_file "$f"
+    done
+  else
+    local stack_file="${SCRIPT_DIR}/stacks/${SELECTED_STACK}.test.sh"
+    if [[ -f "$stack_file" ]]; then
+      run_test_file "$stack_file"
+    else
+      echo "Stack test file not found: $stack_file" >&2
+      exit 1
+    fi
+  fi
+
+  local end_time
+  end_time=$(date +%s)
+  local total_duration=$((end_time - START_TIME))
+
+  report_footer "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS" "$total_duration"
+
+  [[ "$FAILED_TESTS" -eq 0 ]]
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+# tests/lib/assert.sh — Assertion library for HomeLab Stack integration tests
+
+set -euo pipefail
+
+#######################################
+# Internal helpers
+#######################################
+
+__assert_fail() {
+  local msg="$1"
+  echo "ASSERT FAIL: $msg" >&2
+  return 1
+}
+
+#######################################
+# Basic assertions
+#######################################
+
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-Expected '$expected' but got '$actual'}"
+  if [[ "$actual" != "$expected" ]]; then
+    __assert_fail "$msg"
+  fi
+}
+
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-Value is empty}"
+  if [[ -z "$value" ]]; then
+    __assert_fail "$msg"
+  fi
+}
+
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-Expected exit code $code but got $?"
+  # This is typically used with a command; caller should check $? before calling
+  if [[ "$code" -ne 0 ]]; then
+    __assert_fail "$msg"
+  fi
+}
+
+#######################################
+# Docker assertions
+#######################################
+
+assert_container_running() {
+  local name="$1"
+  local msg="${2:-Container $name is not running}"
+  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+    __assert_fail "$msg"
+  fi
+}
+
+assert_container_healthy() {
+  local name="$1"
+  local msg="${2:-