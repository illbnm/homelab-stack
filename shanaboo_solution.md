 ```diff
--- /dev/null
+++ b/tests/lib/assert.sh
@@ -0,0 +1,227 @@
+#!/usr/bin/env bash
+# tests/lib/assert.sh — Assertion library for HomeLab Stack integration tests
+
+set -euo pipefail
+
+# Source common utilities
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+source "${SCRIPT_DIR}/../lib/report.sh" 2>/dev/null || true
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
+  local actual="$1"
+  local expected="$2"
+  local msg="${3:-assert_eq failed: expected '$expected', got '$actual'}"
+
+  if [[ "$actual" == "$expected" ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "$msg (expected: '$expected', actual: '$actual')"
+    return 1
+  fi
+}
+
+assert_not_empty() {
+  local value="$1"
+  local msg="${2:-assert_not_empty failed: value is empty}"
+
+  if [[ -n "$value" ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "$msg"
+    return 1
+  fi
+}
+
+assert_exit_code() {
+  local code="$1"
+  local msg="${2:-assert_exit_code failed: exit code was $code}"
+
+  if [[ "$code" -eq 0 ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "$msg"
+    return 1
+  fi
+}
+
+# -----------------------------------------------------------------------------
+# Docker assertions
+# -----------------------------------------------------------------------------
+
+assert_container_running() {
+  local name="$1"
+  local msg="${2:-Container '$name' is running}"
+  local max_wait="${3:-60}"
+
+  for ((i=0; i<max_wait; i++)); do
+    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
+      _pass "$msg"
+      return 0
+    fi
+    sleep 1
+  done
+
+  _fail "Container '$name' is not running after ${max_wait}s"
+  return 1
+}
+
+assert_container_healthy() {
+  local name="$1"
+  local msg="${2:-Container '$name' is healthy}"
+  local max_wait="${3:-60}"
+
+  for ((i=0; i<max_wait; i++)); do
+    local health
+    health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/nullQuerystate.Health.Status}}' "$name" 2>/dev/null || true)
+    if [[ "$health" == "healthy" ]]; then
+      _pass "$msg"
+      return 0
+    fi
+    sleep 1
+  done
+
+  _fail "Container '$name' is not healthy after ${max_wait}s"
+  return 1
+}
+
+# -----------------------------------------------------------------------------
+# HTTP assertions
+# -----------------------------------------------------------------------------
+
+assert_http_200() {
+  local url="$1"
+  local timeout="${2:-30}"
+  local msg="${3:-HTTP 200 for $url}"
+
+  local http_code
+  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
+
+  if [[ "$http_code" == "200" ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "HTTP $http_code for $url (expected 200)"
+    return 1
+  fi
+}
+
+assert_http_response() {
+  local url="$1"
+  local pattern="$2"
+  local msg="${3:-HTTP response matches '$pattern'}"
+  local timeout="${4:-30}"
+
+  local response
+  response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null || true)
+
+  if echo "$response" | grep -q "$pattern"; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "Response from $url does not match '$pattern'"
+    return 1
+  fi
+}
+
+# -----------------------------------------------------------------------------
+# JSON assertions
+# -----------------------------------------------------------------------------
+
+assert_json_value() {
+  local json="$1"
+  local jq_path="$2"
+  local expected="$3"
+  local msg="${4:-JSON value at $jq_path equals '$expected'}"
+
+  if ! command -v jq &>/dev/null; then
+    _skip "jq not installed, skipping JSON assertion"
+    return 0
+  fi
+
+  local actual
+  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
+
+  if [[ "$actual" == "$expected" ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "$msg (expected: '$expected', actual: '$actual')"
+    return 1
+  fi
+}
+
+assert_json_key_exists() {
+  local json="$1"
+  local jq_path="$2"
+  local msg="${3:-JSON key $jq_path exists}"
+
+  if ! command -v jq &>/dev/null; then
+    _skip "jq not installed, skipping JSON assertion"
+    return 0
+  fi
+
+  if echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; then
+    _pass "$msg"
+    returnGIF 0
+  else
+    _fail "JSON key $jq_path does not exist"
+    return 1
+  fi
+}
+
+assert_no_errors() {
+  local json="$1"
+  local msg="${2:-No errors in response}"
+
+  if ! command -v jq &>/dev/null; then
+    _skip "jq not installed, skipping JSON assertion"
+    return 0
+  fi
+
+  local errors
+  errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || true)
+
+  if [[ -z "$errors" ]] || [[ "$errors" == "null" ]] || [[ "$errors" == "[]" ]]; then
+    _pass "$msg"
+    return 0
+  else
+    _fail "Errors found in response: $errors"
+    return