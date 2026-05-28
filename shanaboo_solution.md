```diff
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,218 @@
+#!/usr/bin/env bash
+# tests/lib/assert.sh — Assertion library for HomeLab Stack integration tests
+
+set -euo pipefail
+
+# Source report helpers for output functions
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+# shellcheck source=report.sh
+source "${SCRIPT_DIR}/report.sh"
+
+# Global counters
+TESTS_PASSED=0
+TESTS_FAILED=0
+TESTS_SKIPPED=0
+
+# -----------------------------------------------------------------------------
+# Core assertions
+# -----------------------------------------------------------------------------
+
+assert_eq() {
+    local actual="$1"
+    local expected="$2"
+    local msg="${3:-assert_eq}"
+
+    if [[ "$actual" == "$expected" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — expected: '$expected', got: '$actual'"
+        return 1
+    fi
+}
+
+assert_not_empty() {
+    local value="$1"
+    local msg="${2:-assert_not_empty}"
+
+    if [[ -n "$value" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — value is empty"
+        return 1
+    fi
+}
+
+assert_exit_code() {
+    local code="$1"
+    local msg="${2:-assert_exit_code}"
+    local expected="${3:-0}"
+
+    if [[ "$code" -eq "$expected" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — expected exit code $expected, got: $code"
+        return 1
+    fi
+}
+
+# -----------------------------------------------------------------------------
+# Docker assertions
+# -----------------------------------------------------------------------------
+
+assert_container_running() {
+    local name="$1"
+    local msg="${2:-Container $name running}"
+
+    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — container not found in running state"
+        return 1
+    fi
+}
+
+assert_container_healthy() {
+    local name="$1"
+    local msg="${2:-Container $name healthy}"
+    local timeout="${3:-60}"
+    local start_time
+    start_time=$(date +%s)
+
+    while true; do
+        local status
+        status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
+
+        if [[ "$status" == "healthy" ]]; then
+            _pass "$msg"
+            return 0
+        fi
+
+        local current_time
+        current_time=$(date +%s)
+        if (( current_time - start_time >= timeout )); then
+            _fail "$msg — health check failed after ${timeout}s (status: $status)"
+            return 1
+        fi
+
+        sleep 2
+    done
+}
+
+# -----------------------------------------------------------------------------
+# HTTP assertions
+# -----------------------------------------------------------------------------
+
+assert_http_200() {
+    local url="$1"
+    local timeout="${2:-30}"
+    local msg="${3:-HTTP 200 $url}"
+
+    local http_code
+    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
+
+    if [[ "$http_code" == "200" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — got HTTP $http_code"
+        return 1
+    fi
+}
+
+assert_http_response() {
+    local url="$1"
+    local pattern="$2"
+    local msg="${3:-HTTP response matches '$pattern'}"
+    local timeout="${4:-30}"
+
+    local response
+    response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null || true)
+
+    if echo "$response" | grep -q "$pattern"; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — pattern not found in response"
+        return 1
+    fi
+}
+
+# -----------------------------------------------------------------------------
+# JSON assertions
+# -----------------------------------------------------------------------------
+
+assert_json_value() {
+    local json="$1"
+    local jq_path="$2"
+    local expected="$3"
+    local msg="${4:-JSON value at $jq_path}"
+
+    if ! command -v jq &>/dev/null; then
+        _skip "$msg — jq not installed"
+        return 0
+    fi
+
+    local actual
+    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
+
+    if [[ "$actual" == "$expected" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — expected: '$expected', got: '$actual'"
+        return 1
+    fi
+}
+
+assert_json_key_exists() {
+    local json="$1"
+    local jq_path="$2"
+    local msg="${3:-JSON key exists at $jq_path}"
+
+    if ! command -v jq &>/dev/null; then
+        _skip "$msg — jq not installed"
+        return 0
+    fi
+
+    if echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — key not found"
+        return 1
+    fi
+}
+
+assert_no_errors() {
+    local json="$1"
+    local msg="${2:-No errors in response}"
+
+    if ! command -v jq &>/dev/null; then
+        _skip "$msg — jq not installed"
+        return 0
+    fi
+
+    local errors
+    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || true)
+
+    if [[ -z "$errors" ]]; then
+        _pass "$msg"
+        return 0
+    else
+        _fail "$msg — errors found: $errors"
+        return 1
+    fi
+}
+
+# -----------------------------------------------------------------------------
+# File assertions
+# -----------------------------------------------------------------------------
+
+assert_file_contains() {
+    local file="$1"
+    local pattern="$2"
+    local msg="${3:-File contains '$