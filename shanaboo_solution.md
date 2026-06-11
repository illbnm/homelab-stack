 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,138 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+cd "$SCRIPT_DIR"
+
+# shellcheck source=lib/assert.sh
+source lib/assert.sh
+# shellcheck source=lib/docker.sh
+source lib/docker.sh
+# shellcheck source=lib/report.sh
+source lib/report.sh
+
+########################################
+# Parse arguments
+########################################
+STACK=""
+RUN_ALL=false
+RUN_E2E=false
+
+while [[ $# -gt 0 ]]; do
+  case "$1" in
+    --stack)
+      STACK="$2"
+      shift 2
+      ;;
+    --all)
+      RUN_ALL=true
+      shift
+      ;;
+    --e2e)
+      RUN_E2E=true
+      shift
+      ;;
+    *)
+      echo "Usage: $0 [--stack <name>] [--all] [--e2e]" >&2
+      exit 1
+      ;;
+  esac
+done
+
+########################################
+# Determine which tests to run
+########################################
+declare -a TEST_FILES=()
+
+if [[ "$RUN_ALL" == true ]]; then
+  for f in stacks/*.test.sh; do
+    [[ -f "$f" ]] && TEST_FILES+=("$f")
+  done
+elif [[ -n "$STACK" ]]; then
+  if [[ -f "stacks/${STACK}.test.sh" ]]; then
+    TEST_FILES+=("stacks/${STACK}.test.sh")
+  else
+    echo "Error: No test file found for stack '$STACK'" >&2
+    exit 1
+  fi
+else
+  # Default: run all stack tests
+  for f in stacks/*.test.sh; do
+    [[ -f "$f" ]] && TEST_FILES+=("$f")
+  done
+fi
+
+if [[ "$RUN_E2E" == true ]]; then
+  for f in e2e/*.test.sh; do
+    [[ -f "$f" ]] && TEST_FILES+=("$f")
+  done
+fi
+
+########################################
+# Execute tests
+########################################
+report_header
+
+TOTAL_PASSED=0
+TOTAL_FAILED=0
+TOTAL_SKIPPED=0
+
+for test_file in "${TEST_FILES[@]}"; do
+  stack_name=$(basename "$test_file" .test.sh)
+  report_stack_start "$stack_name"
+
+  # Source the test file in a subshell to isolate functions
+  (
+    # shellcheck source=/dev/null
+    source "$test_file"
+
+    # Find all test functions
+    declare -a tests=()
+    while IFS= read -r line; do
+      func_name="${line%%()*}"
+      tests+=("$func_name")
+    done < <(grep -E '^test_[a-zA-Z0-9_]+\(\)' "$test_file" || true)
+
+    for test_func in "${tests[@]}"; do
+      report_test_start "$stack_name" "$test_func"
+
+      set +e
+      "$test_func" 2>/dev/null
+      exit_code=$?
+      set -e
+
+      if [[ $exit_code -eq 0 ]]; then
+        report_test_pass "$stack_name" "$test_func"
+      elif [[ $exit_code -eq 2 ]]; then
+        report_test_skip "$stack_name" "$test_func"
+      else
+        report_test_fail "$stack_name" "$test_func"
+      fi
+    done
+  )
+done
+
+report_summary "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED"
+
+[[ "$TOTAL_FAILED" -eq 0 ]] || exit 1
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# shellcheck source=report.sh
+source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
+
+########################################
+# Basic assertions
+########################################
+
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-assert_eq failed: expected '$expected', got '$actual'}"
+
+  if [[ "$actual" != "$expected" ]]; then
+    echo "$msg" >&2
+    return 1
+  fi
+}
+
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-assert_not_empty failed: value is empty}"
+
+  if [[ -z "$value" ]]; then
+    echo "$msg" >&2
+    return 1
+  fi
+}
+
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-assert_exit_code failed: expected exit code 0, got $code}"
+
+  if [[ "$code" -ne 0 ]]; then
+    echo "$msg" >&2
+    return 1
+  fi
+}
+
+########################################
+# Docker assertions
+########################################
+
+assert_container_running() {
+  local name="$1"
+  local msg="${2:-Container $name is not running}"
+
+  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+    echo "$msg" >&2
+    return 1
+  fi
+}
+
+assert_container_healthy() {
+  local name="$1"
+  local timeout="${2:-60}"
+  local msg="${3:-Container $name is not healthy after ${timeout}s}"
+
+  local start_time
+  start_time=$(date +%s)
+
+  while true; do
+    local status
+    status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
+
+    if [[ "$status" == "healthy" ]]; then
+      return 0
+    fi
+
+    local current_time
+    current_time=$(date +%s)
+    if (( current_time - start_time >= timeout )); then
+      echo "$msg" >&2
+      return 1
+    fi
+
+    sleep 2
+  done
+}
+
+########################################
+# HTTP assertions
+########################################
+
+assert_http_200() {
+  local url="$1"
+  local timeout="${2:-30}"
+  local msg="${3:-HTTP $url did not return 200}"
+
+ 