 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,163 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Entry Point
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
+declare -g TESTS_PASSED=0
+declare -g TESTS_FAILED=0
+declare -g TESTS_SKIPPED=0
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
+      --verbose|-v)
+        VERBOSE=true
+        shift
+        ;;
+      --help|-h)
+        echo "Usage: $0 [--stack <name> | --all] [--ci] [--verbose]"
+        echo ""
+        echo "Options:"
+        echo "  --stack <name>  Run tests for a specific stack"
+        echo "  --all           Run all tests"
+        echo "  --ci            CI mode (no interactive, JSON output)"
+        echo "  --verbose, -v   Verbose output"
+        echo "  --help, -h      Show this help"
+        echo ""
+        echo "Available stacks: base, media, storage, monitoring, network, productivity, ai, sso, databases, notifications"
+        exit 0
+        ;;
+      *)
+        echo "Unknown option: $1" >&2
+        exit 1
+        ;;
+    esac
+  done
+}
+
+# Run a single test file
+run_test_file() {
+  local file="$1"
+  local stack_name
+  stack_name="$(basename "$file" .test.sh)"
+
+  if [[ -n "$SELECTED_STACK" && "$stack_name" != "$SELECTED_STACK" ]]; then
+    return 0
+  fi
+
+  report_section "$stack_name"
+
+  # Source the test file in a subshell to isolate functions
+  (
+    source "$file"
+
+    # Find and run all test_* functions
+    local funcs
+    funcs=$(compgen -A function | grep '^test_' || true)
+
+    for func in $funcs; do
+      report_test_start "$func"
+
+      local start_time end_time duration
+      start_time=$(date +%s%N)
+
+      if $func; then
+        end_time=$(date +%s%N)
+        duration=$(( (end_time - start_time) / 1000000 ))
+        report_test_pass "$func" "$duration"
+        ((TESTS_PASSED++)) || true
+      else
+        end_time=$(date +%s%N)
+        duration=$(( (end_time - start_time) / 1000000 ))
+        report_test_fail "$func" "$duration"
+        ((TESTS_FAILED++)) || true
+      fi
+    done
+  )
+}
+
+# Main execution
+main() {
+  parse_args "$@"
+
+  report_header
+
+  if [[ "$RUN_ALL" == true || -n "$SELECTED_STACK" ]]; then
+    # Run stack tests
+    for test_file in "$STACKS_DIR"/*.test.sh; do
+      [[ -f "$test_file" ]] || continue
+      run_test_file "$test_file"
+    done
+
+    # Run e2e tests only when --all
+    if [[ "$RUN_ALL" == true ]]; then
+      for test_file in "$E2E_DIR"/*.test.sh; do
+        [[ -f "$test_file" ]] || continue
+        run_test_file "$test_file"
+      done
+    fi
+  else
+    echo "No test target specified. Use --stack <name> or --all"
+    exit 1
+  fi
+
+  report_footer "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
+
+  if [[ "$TESTS_FAILED" -gt 0 ]]; then
+    exit 1
+  fi
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,198 @@
+#!/usr/bin/env bash
+# Assertion library for HomeLab Stack integration tests
+
+# Color codes (disabled in CI)
+if [[ "${CI:-}" == "true" || "${CI_MODE:-false}" == "true" ]]; then
+  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' RESET=''
+else
+  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m'
+  CYAN='\033[0;36m' MAGENTA='\033[0;35m' BOLD='\033[1m' RESET='\033[0m'
+fi
+
+# Internal: Print error and return 1
+_assert_fail() {
+  local msg="$1"
+  echo -e "${RED}ASSERT FAIL: $msg${RESET}" >&2
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
+    return 1
+  fi
+  return 0
+}
+
+# assert_not_empty <value> [msg]
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-Value is empty}"
+  if [[ -z "$value" ]]; then
+    _assert_fail "$msg"
+    return 1
+  fi
+  return 0
+}
+
+# assert_exit_code <