```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Runner
+# Usage: ./run-tests.sh [--stack <name> | --all] [--ci] [--verbose]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+cd "$SCRIPT_DIR"
+
+# Source libraries
+source lib/assert.sh
+source lib/docker.sh
+source lib/report.sh
+
+# Globals
+declare -g CI_MODE=false
+declare -g VERBOSE=false
+declare -g SELECTED_STACK=""
+declare -g RUN_ALL=false
+declare -g TOTAL_PASSED=0
+declare -g TOTAL_FAILED=0
+declare -g TOTAL_SKIPPED=0
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
+      *)
+        echo "Unknown option: $1" >&2
+        echo "Usage: $0 [--stack <name> | --all] [--ci] [--verbose]" >&2
+        exit 1
+        ;;
+    esac
+  done
+
+  if [[ -z "$SELECTED_STACK" && "$RUN_ALL" == false ]]; then
+    echo "Error: Must specify --stack <name> or --all" >&2
+    echo "Usage: $0 [--stack <name> | --all] [--ci] [--verbose]" >&2
+    exit 1
+  fi
+}
+
+# Load environment variables
+load_env() {
+  if [[ -f "$SCRIPT_DIR/../.env" ]]; then
+    set -a
+    source "$SCRIPT_DIR/../.env"
+    set +a
+  fi
+
+  # CI defaults
+  if [[ "$CI_MODE" == true ]]; then
+    export TEST_TIMEOUT=300
+    export TEST_BASE_URL="${TEST_BASE_URL:-http://localhost}"
+  fi
+}
+
+# Run a single test file
+run_test_file() {
+  local file="$1"
+  local stack_name
+  stack_name=$(basename "$file" .test.sh)
+
+  report_stack_header "$stack_name"
+
+  # Source the test file to register functions
+  local -a test_funcs=()
+  local func
+
+  # Extract test function names
+  while IFS= read -r func; do
+    test_funcs+=("$func")
+  done < <(grep -oP '^test_\w+\(\)' "$file" | sed 's/()//')
+
+  # Run each test
+  for func in "${test_funcs[@]}"; do
+    local start_time end_time duration
+    start_time=$(date +%s%N)
+
+    if "$func" 2>/dev/null; then
+      end_time=$(date +%s%N)
+      duration=$(((end_time - start_time) / 1000000))
+      report_test_pass "$stack_name" "$func" "$duration"
+      ((TOTAL_PASSED++))
+    else
+      end_time=$(date +%s%N)
+      duration=$(((end_time - start_time) / 1000000))
+      report_test_fail "$stack_name" "$func" "$duration" "Test failed"
+      ((TOTAL_FAILED++))
+    fi
+  done
+}
+
+# Main execution
+main() {
+  parse_args "$@"
+  load_env
+
+  report_header
+
+  # Collect test files
+  local -a test_files=()
+
+  if [[ "$RUN_ALL" == true ]]; then
+    for f in stacks/*.test.sh; do
+      [[ -f "$f" ]] && test_files+=("$f")
+    done
+  else
+    local stack_file="stacks/${SELECTED_STACK}.test.sh"
+    if [[ -f "$stack_file" ]]; then
+      test_files+=("$stack_file")
+    else
+      echo "Error: Test file not found: $stack_file" >&2
+      exit 1
+    fi
+  fi
+
+  # Run e2e tests if --all
+  if [[ "$RUN_ALL" == true ]]; then
+    for f in e2e/*.test.sh; do
+      [[ -f "$f" ]] && test_files+=("$f")
+    done
+  fi
+
+  # Execute tests
+  for f in "${test_files[@]}"; do
+    run_test_file "$f"
+  done
+
+  # Summary
+  report_footer "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED"
+
+  # Exit code
+  [[ "$TOTAL_FAILED" -eq 0 ]]
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+# Assertion library for HomeLab Stack integration tests
+
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-assert_eq failed: expected '$expected', got '$actual'}"
+
+  if [[ "$actual" != "$expected" ]]; then
+    echo "FAIL: $msg" >&2
+    return 1
+  fi
+}
+
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-assert_not_empty failed: value is empty}"
+
+  if [[ -z "$value" ]]; then
+    echo "FAIL: $msg" >&2
+    return 1
+  fi
+}
+
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-assert_exit_code failed: exit code $code != 0}"
+
+  if [[ "$code" -ne 0 ]]; then
+    echo "FAIL: $msg" >&2
+    return 1
+  fi
+}
+
+assert_container_running() {
+  local name="$1"
+  local msg="${2:-Container $name is not running}"
+
+  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+    echo "FAIL: $msg" >&2
+    return 1
+  fi