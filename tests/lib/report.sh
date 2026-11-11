#!/usr/bin/env bash
# ==============================================================================
# tests/lib/report.sh — Console & JSON test summary generator
# ==============================================================================

write_json_report() {
  local out_file="$1"
  local passed="${TESTS_PASSED:-0}"
  local failed="${TESTS_FAILED:-0}"
  local skipped="${TESTS_SKIPPED:-0}"
  local total=$((passed + failed + skipped))
  cat > "$out_file" <<EOF
{
  "total": ${total},
  "passed": ${passed},
  "failed": ${failed},
  "skipped": ${skipped},
  "status": "$( [[ "$failed" -eq 0 ]] && echo "passed" || echo "failed" )"
}
EOF
}

print_test_summary() {
  local passed="${TESTS_PASSED:-0}"
  local failed="${TESTS_FAILED:-0}"
  local skipped="${TESTS_SKIPPED:-0}"
  echo "=================================================================="
  echo "Homelab Stack Test Summary: PASSED=${passed} FAILED=${failed} SKIPPED=${skipped}"
  echo "=================================================================="
}
