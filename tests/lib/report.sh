#!/usr/bin/env bash
# report.sh — Test result reporting (terminal + JSON)
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-tests/results}"
REPORT_JSON="${RESULTS_DIR}/report.json"
STACK_RESULTS=()

record_result() {
  STACK_RESULTS+=("$1|$2|$3|$4|${5:-}")
}

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests     ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
}

print_summary() {
  echo ""
  echo "──────────────────────────────────────────"
  printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, \033[33m%d skipped\033[0m\n" \
    "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
  echo "Total:   $TESTS_TOTAL"
  echo "──────────────────────────────────────────"

  mkdir -p "$RESULTS_DIR"
  local ts json first=true entry stack test status duration detail
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  json="{\"timestamp\":\"$ts\",\"summary\":{\"total\":$TESTS_TOTAL,\"passed\":$TESTS_PASSED,\"failed\":$TESTS_FAILED,\"skipped\":$TESTS_SKIPPED},\"results\":["

  for entry in "${STACK_RESULTS[@]}"; do
    IFS='|' read -r stack test status duration detail <<< "$entry"
    [[ "$first" == true ]] && first=false || json+=","
    json+="{\"stack\":\"$stack\",\"test\":\"$test\",\"status\":\"$status\",\"duration_ms\":$duration,\"detail\":\"${detail//\"/\\\"}\"}"
  done
  json+="]}"

  echo "$json" > "$REPORT_JSON"
  echo "JSON report: $REPORT_JSON"
}
