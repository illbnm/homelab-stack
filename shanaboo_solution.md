 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# HomeLab Stack — Integration Tests Runner
+# Usage: ./run-tests.sh [--stack <name> | --all] [--verbose] [--ci]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+
+# Source libraries
+# shellcheck source=lib/assert.sh
+source "${SCRIPT_DIR}/lib/assert.sh"
+# shellcheck source=lib/docker.sh
+source "${SCRIPT_DIR}/lib/docker.sh"
+# shellcheck source=lib/report.sh
+source "${SCRIPT_DIR}/lib/report.sh"
+
+# Globals
+VERBOSE=${VERBOSE:-0}
+CI_MODE=${CI_MODE:-0}
+SELECTED_STACK=""
+RUN_ALL=0
+TOTAL_TESTS=0
+PASSED_TESTS=0
+FAILED_TESTS=0
+START_TIME=""
+
+########################################
+# Parse CLI arguments
+########################################
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
+      --ci)
+        CI_MODE=1
+        shift
+        ;;
+      *)
+        echo "Unknown option: $1" >&2
+        echo "Usage: $0 [--stack <name> | --all] [--verbose] [--ci]" >&2
+        exit 1
+        ;;
+    esac
+  done
+
+  if [[ -z "${SELECTED_STACK}" && "${RUN_ALL}" -eq 0 ]]; then
+    echo "Usage: $0 [--stack <name> | --all] [--verbose] [--ci]" >&2
+    exit 1
+  fi
+}
+
+########################################
+# Run a single test file
+########################################
+run_test_file() {
+  local file="$1"
+  local stack_name
+  stack_name=$(basename "${file}" .test.sh)
+
+  report_section "${stack_name}"
+
+  # shellcheck source=/dev/null
+  source "${file}"
+
+  # Find and run all test_* functions
+  local funcs
+  funcs=$(compgen -A function | grep '^test_' || true)
+
+  for func in ${funcs}; do
+    ((TOTAL_TESTS++)) || true
+    local test_start
+    test_start=$(date +%s)
+
+    if ${func} 2>/dev/null; then
+      local test_end
+      test_end=$(date +%s)
+      local duration=$((test_end - test_start))
+      report_pass "${stack_name}" "${func}" "${duration}"
+      ((PASSED_TESTS++)) || true
+    else
+      local test_end
+      test_end=$(date +%s)
+      local duration=$((test_end - test_start))
+      report_fail "${stack_name}" "${func}" "${duration}"
+      ((FAILED_TESTS++)) || true
+    fi
+  done
+}
+
+########################################
+# Main
+########################################
+main() {
+  parse_args "$@"
+
+  report_header
+  START_TIME=$(date +%s)
+
+  if [[ "${RUN_ALL}" -eq 1 ]]; then
+    for f in "${SCRIPT_DIR}"/stacks/*.test.sh; do
+      [[ -f "${f}" ]] && run_test_file "${f}"
+    done
+    # E2E tests only in --all or explicit
+    for f in "${SCRIPT_DIR}"/e2e/*.test.sh; do
+      [[ -f "${f}" ]] && run_test_file "${f}"
+    done
+  else
+    local test_file="${SCRIPT_DIR}/stacks/${SELECTED_STACK}.test.sh"
+    if [[ ! -f "${test_file}" ]]; then
+      echo "ERROR: No test file found for stack '${SELECTED_STACK}'" >&2
+      exit 1
+    fi
+    run_test_file "${test_file}"
+  fi
+
+  local end_time
+  end_time=$(date +%s)
+  local total_duration=$((end_time - START_TIME))
+
+  report_summary "${TOTAL_TESTS}" "${PASSED_TESTS}" "${FAILED_TESTS}" "${total_duration}"
+  report_json "${TOTAL_TESTS}" "${PASSED_TESTS}" "${FAILED_TESTS}" "${total_duration}"
+
+  [[ "${FAILED_TESTS}" -eq 0 ]] || exit 1
+}
+
+main "$@"
+
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+# assert.sh — Assertion library for HomeLab Stack tests
+
+set -euo pipefail
+
+########################################
+# Internal helpers
+########################################
+_assert_fail() {
+  local msg="${1:-Assertion failed}"
+  echo "  ❌ FAIL: ${msg}" >&2
+  return 1
+}
+
+########################################
+# assert_eq <actual> <expected> [msg]
+########################################
+assert_eq() {
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-Expected '${expected}' but got '${actual}'}"
+  if [[ "${actual}" != "${expected}" ]]; then
+    _assert_fail "${msg}"
+  fi
+}
+
+########################################
+# assert_not_empty <value> [msg]
+########################################
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-Expected non-empty value}"
+  if [[ -z "${value}" ]]; then
+    _assert_fail "${msg}"
+  fi
+}
+
+########################################
+# assert_exit_code <code> [msg]
+########################################
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-Expected exit code ${code} but got $?"
+  if [[ "${code}" -ne 0 ]]; then
+    _assert_fail "${msg}"
+  fi
+}
+
+########################################
+# assert_container_running <name>
+########################################
+assert_container_running() {
+  local name="$1"
+  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+    _assert_fail "Container '${name}' is not running"
+  fi
+}
+
+########################################
+# assert_container_healthy <name>
+# Waits up to 60 seconds for healthy status
+