 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,163 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Runner
+# Usage: ./run-tests.sh [--stack <name> | --all] [--ci] [--verbose]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+LIB_DIR="$SCRIPT_DIR/lib"
+STACKS_DIR="$SCRIPT_DIR/stacks"
+E2E_DIR="$SCRIPT_DIR/e2e"
+
+# Source libraries
+source "$LIB_DIR/assert.sh"
+source "$LIB_DIR/docker.sh"
+source "$LIB_DIR/report.sh"
+
+# Global state
+declare -g CI_MODE=false
+declare -g VERBOSE=false
+declare -g SELECTED_STACK=""
+declare -g RUN_ALL=false
+declare -g TOTAL_PASSED=0
+declare -g TOTAL_FAILED=0
+declare -g TOTAL_SKIPPED=0
+declare -g START_TIME=0
+
+# Parse arguments
+parse_args() {
+  while [[ $# -gt 0 ]]; do
+    case "$1" in
+      --stack)
+        SELECTED_STACK="$2"
+        shift 2
+        ;;
+      --all)
+        RUN_ALL=true
+        shift
+        ;;
+      --ci)
+        CI_MODE=true
+        shift
+        ;;
+      --verbose)
+        VERBOSE=true
+        shift
+        ;;
+      *)
+        echo "Unknown option: $1" >&2
+        echo "Usage: $0 [--stack <name>] [--all] [--ci] [--verbose]" >&2
+        exit 1
+        ;;
+    esac
+  done
+}
+
+# Discover test functions in a file
+discover_tests() {
+  local file="$1"
+  grep -E '^test_\w+\(\)' "$file" | sed 's/() {//' | sed 's/()$//'
+}
+
+# Run a single test file
+run_test_file() {
+  local file="$1"
+  local stack_name="$2"
+  local test_func
+  local test_start
+  local test_duration
+  local result
+  local exit_code
+
+  # Source the test file to get test functions
+  local -A TEST_FUNCS=()
+  while IFS= read -r test_func; do
+    TEST_FUNCS["$test_func"]=1
+  done < <(discover_tests "$file")
+
+  for test_func in "${!TEST_FUNCS[@]}"; do
+    test_start=$(date +%s%N)
+
+    # Run test in subshell
+    set +e
+    (
+      source "$file"
+      $test_func
+    ) >/dev/null 2>&1
+    exit_code=$?
+    set -e
+
+    test_duration=$(echo "scale=3; ($(date +%s%N) - $test_start) / 1000000000" | bc 2>/dev/null || echo "0.0")
+
+    if [[ $exit_code -eq 0 ]]; then
+      report_pass "$stack_name" "$test_func" "$test_duration"
+      ((TOTAL_PASSED++)) || true
+    elif [[ $exit_code -eq 2 ]]; then
+      report_skip "$stack_name" "$test_func"
+      ((TOTAL_SKIPPED++)) || true
+    else
+      report_fail "$stack_name" "$test_func" "$test_duration"
+      ((TOTAL_FAILED++)) || true
+    fi
+  done
+}
+
+# Main execution
+main() {
+  parse_args "$@"
+
+  START_TIME=$(date +%s)
+  report_header
+
+  if [[ -n "$SELECTED_STACK" ]]; then
+    run_test_file "$STACKS_DIR/$SELECTED_STACK.test.sh" "$SELECTED_STACK"
+  elif $RUN_ALL; then
+    for test_file in "$STACKS_DIR"/*.test.sh; do
+      [[ -f "$test_file" ]] || continue
+      local stack_name
+      stack_name=$(basename "$test_file" .test.sh)
+      run_test_file "$test_file" "$stack_name"
+    done
+  else
+    echo "Error: Specify --stack <name> or --all" >&2
+    exit 1
+  fi
+
+  report_footer "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED" "$START_TIME"
+
+  [[ $TOTAL_FAILED -eq 0 ]]
+}
+
+main "$@"
--- /dev/null
+++ 	tests/lib/assert.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+# Assertion library for HomeLab Stack integration tests
+
+source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
+
+# Internal: Track assertion state
+declare -g _ASSERT_FAILED=0
+
+_assert_fail() {
+  local msg="$1"
+  echo "ASSERT FAIL: $msg" >&2
+  _ASSERT_FAILED=1
+  return 1
+}
+
+# assert_eq <actual> <expected> [msg]
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-Expected '$expected' but got '$actual'}"
+  if [[ "$actual" != "$expected" ]]; then
+    _assert_fail "$msg"
+  fi
+}
+
+# assert_not_empty <value> [msg]
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-Value is empty}"
+  if [[ -z "$value" ]]; then
+    _assert_fail "$msg"
+  fi
+}
+
+# assert_exit_code <code> [msg]
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-Expected exit code $code but got $?}"
+  if [[ $? -ne "$code" ]]; then
+    _assert_fail "$msg"
+  fi
+}
+
+# assert_container_running <name>
+assert_container_running() {
+  local name="$1"
+  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+    _assert_fail "Container '$name' is not running"
+  fi
+}
+
+# assert_container_healthy <name>
+# Waits up to 60 seconds for container to be healthy
+assert_container_healthy() {
+  local name="$1"
+  local retries=30
+  local delay=2
+  local i
+
+  for ((i=0; i<retries; i++)); do