#!/usr/bin/env bash
# tests/lib/report.sh
# Formats test output and generates JSON artifacts

log_pass() {
    local stack="$1"
    local name="$2"
    local duration="$3"
    echo -e "[$stack] ▶ $name 	✅ PASS (${duration}s)"
}

log_fail() {
    local stack="$1"
    local name="$2"
    local err="$3"
    echo -e "[$stack] ▶ $name 	❌ FAIL: $err"
}
