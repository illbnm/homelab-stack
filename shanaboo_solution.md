```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,131 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Test Runner
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
+declare -g CI_MODE="${CI_MODE:-false}"
+declare -g VERBOSE="${VERBOSE:-false}"
+declare -g SELECTED_STACK=""
+declare -g RUN_ALL=false
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
+  if [[ -z "$SELECTED_STACK" ]] && [[ "$RUN_ALL" == false ]]; then
+    echo "Usage: $0 [--stack <name> | --all] [--ci] [--verbose]" >&2
+    echo "Available stacks: base, media, storage, monitoring, network, productivity, ai, sso, databases, notifications" >&2
+    exit 1
+  fi
+}
+
+# Run a single test file
+run_test_file() {
+  local file="$1"
+  local stack_name
+  stack_name="$(basename "$file" .test.sh)"
+
+  report_stack_start "$stack_name"
+
+  local -a test_funcs
+  mapfile -t test_funcs < <(grep -E '^test_\w+\(\)' "$file" | sed 's/().*//')
+
+  # Source the test file to load functions
+  # shellcheck source=/dev/null
+  source "$file"
+
+  local func total=0 passed=0 failed=0
+  for func in "${test_funcs[@]}"; do
+    total=$((total + 1))
+    if run_test "$func" "$stack_name"; then
+      passed=$((passed + 1))
+    else
+      failed=$((failed + 1))
+    fi
+  done
+
+  report_stack_end "$stack_name" "$total" "$passed" "$failed"
+}
+
+# Main
+main() {
+  parse_args "$@"
+
+  report_header
+
+  local -a test_files=()
+
+  if [[ "$RUN_ALL" == true ]]; then
+    for f in stacks/*.test.sh; do
+      [[ -f "$f" ]] && test_files+=("$f")
+    done
+  else
+    local stack_file="stacks/${SELECTED_STACK}.test.sh"
+    if [[ ! -f "$stack_file" ]]; then
+      report_error "Stack test file not found: $stack_file"
+      exit 1
+    fi
+    test_files+=("$stack_file")
+  fi
+
+  for f in "${test_files[@]}"; do
+    run_test_file "$f"
+  done
+
+  # Run e2e tests if --all
+  if [[ "$RUN_ALL" == true ]]; then
+    for f in e2e/*.test.sh; do
+      [[ -f "$f" ]] && run_test_file "$f"
+    done
+  fi
+
+  report_footer
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,189 @@
+#!/usr/bin/env bash
+# Assertion library for HomeLab Stack integration tests
+
+source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
+
+# Internal: track assertion state
+declare -g _ASSERT_FAILED=0
+
+_reset_assert_state() {
+  _ASSERT_FAILED=0
+}
+
+_mark_failed() {
+  _ASSERT_FAILED=1
+}
+
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-assert_eq failed: expected '$expected', got '$actual'}"
+
+  if [[ "$actual" == "$expected" ]]; then
+    return 0
+  else
+    _mark_failed
+    report_fail "$msg"
+    return 1
+  fi
+}
+
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-assert_not_empty failed: value is empty}"
+
+  if [[ -n "$value" ]]; then
+    return 0
+  else
+    _mark_failed
+    report_fail "$msg"
+    return 1
+  fi
+}
+
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-assert_exit_code failed: expected 0, got $code}"
+
+  if [[ "$code" -eq 0 ]]; then
+    return 0
+  else
+    _mark_failed
+    report_fail "$msg"
+    return 1
+  fi
+}
+
+assert_container_running() {
+  local name="$1"
+  local msg="${2:-Container $name is not running}"
+
+  if docker ps --format '{{.Names}}' | grep -qx "$name"; then
+    return 0
+  else
+    _mark_failed
+    report_fail "$msg"
+    return 1
+  fi
+}
+
+assert_container_healthy() {
+  local name="$1"
+  local timeout="${2:-60}"
+  local msg="${3:-Container $name is not healthy after ${timeout}s}"
+
+  local start_time end_time
+  start_time=$(date +%s)
+  end_time=$((start_time + timeout))
+
+  while [[ $(date +%s) -lt $end_time ]]; do
+    local status
+    status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
+    if [[ "$status" == "healthy" ]]; then
+      return 0
+    fi
+    sleep 2