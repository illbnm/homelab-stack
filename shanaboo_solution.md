 ```diff
--- /dev/null
+++ b/tests/run-tests.sh
@@ -0,0 +1,170 @@
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
+CI_MODE=false
+VERBOSE=false
+SELECTED_STACK=""
+RUN_ALL=false
+TOTAL_TESTS=0
+PASSED_TESTS=0
+FAILED_TESTS=0
+START_TIME=""
+
+usage() {
+    cat <<EOF
+Usage: $(basename "$0") [OPTIONS]
+
+Options:
+    --stack <name>   Run tests for a specific stack
+    --all            Run all tests
+    --ci             CI mode (no colors, JSON output)
+    --verbose        Verbose output
+    -h, --help       Show this help
+
+Examples:
+    ./run-tests.sh --stack base
+    ./run-tests.sh --all
+    ./run-tests.sh --all --ci
+EOF
+}
+
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
+                usage
+                exit 0
+                ;;
+            *)
+                echo "Unknown option: $1" >&2
+                usage
+                exit 1
+                ;;
+        esac
+    done
+}
+
+discover_tests() {
+    local stack="$1"
+    find "stacks/${stack}.test.sh" -type f 2>/dev/null
+}
+
+run_test_file() {
+    local file="$1"
+    local stack_name
+    stack_name=$(basename "$file" .test.sh)
+
+    # shellcheck source=/dev/null
+    source "$file"
+}
+
+run_all_tests() {
+    local test_files=()
+    while IFS= read -r -d '' file; do
+        test_files+=("$file")
+    done < <(find stacks -name '*.test.sh' -print0 | sort)
+
+    for file in "${test_files[@]}"; do
+        run_test_file "$file"
+    done
+}
+
+main() {
+    parse_args "$@"
+
+    if [[ "$CI_MODE" == true ]]; then
+        export NO_COLOR=1
+    fi
+
+    report_header
+    START_TIME=$(date +%s)
+
+    if [[ -n "$SELECTED_STACK" ]]; then
+        local test_file="stacks/${SELECTED_STACK}.test.sh"
+        if [[ ! -f "$test_file" ]]; then
+            echo "Error: No tests found for stack '$SELECTED_STACK'" >&2
+            exit 1
+        fi
+        run_test_file "$test_file"
+    elif [[ "$RUN_ALL" == true ]]; then
+        run_all_tests
+    else
+        echo "Error: Must specify --stack <name> or --all" >&2
+        usage
+        exit 1
+    fi
+
+    local end_time
+    end_time=$(date +%s)
+    report_footer "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS" "$((end_time - START_TIME))"
+}
+
+main "$@"
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,218 @@
+#!/usr/bin/env bash
+# HomeLab Stack — Assertion Library
+
+source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
+
+# Track assertion results
+ASSERT_TOTAL=0
+ASSERT_PASSED=0
+ASSERT_FAILED=0
+
+assert_eq() {
+    local actual="$1"
+    local expected="$2"
+    local msg="${3:-assert_eq}"
+    ASSERT_TOTAL=$((ASSERT_TOTAL + 1))
+
+    if [[ "$actual" == "$expected" ]]; then
+        ASSERT_PASSED=$((ASSERT_PASSED + 1))
+        report_pass "$msg" "expected='$expected', got='$actual'"
+        return 0
+    else
+        ASSERT_FAILED=$((ASSERT_FAILED + 1))
+        report_fail "$msg" "expected='$expected', got='$actual'"
+        return 1
+    fi
+}
+
+assert_not_empty() {
+    local value="$1"
+    local msg="${2:-assert_not_empty}"
+    ASSERT_TOTAL=$((ASSERT_TOTAL + 1))
+
+    if [[ -n "$value" ]]; then
+        ASSERT_PASSED=$((ASSERT_PASSED + 1))
+        report_pass "$msg"
+        return 0
+    else
+        ASSERT_FAILED=$((ASSERT_FAILED + 1))
+        report_fail "$msg" "value is empty"
+        return 1
+    fi
+}
+
+assert_exit_code() {
+    local code="$1"
+    local msg="${2:-assert_exit_code}"
+    ASSERT_TOTAL=$((ASSERT_TOTAL + 1))
+
+    if [[ "$code" -eq 0 ]]; then
+        ASSERT_PASSED=$((ASSERT_PASSED + 1))
+        report_pass "$msg"
+        return 0
+    else
+        ASSERT_FAILED=$((ASSERT_FAILED + 1))
+        report_fail "$msg" "exit code: $code"
+        return 1
+    fi
+}
+
+assert_container_running() {
+    local name="$1"
+    local msg="${2:-Container $name running}"
+    ASSERT_TOTAL=$((ASSERT_TOTAL + 1))
+
+    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+        ASSERT_PASSED=$((ASSERT_PASSED + 1))
+        report_pass "$msg"
+        return 0
+    else
+        ASSERT_FAILED=$((ASSERT_FAILED + 1))
+        report_fail "$msg" "container not found in running containers"
+        return 1
+    fi
+}
+
+assert_container_healthy() {
+    local name="$1"
+    local msg="${2:-Container $name healthy}"
+    local timeout="${3:-60}"
+    ASSERT_TOTAL=$((ASSERT_TOTAL +