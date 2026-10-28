#!/usr/bin/env bash

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

report_test() {
  local name="$1"
  local status="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ "$status" -eq 0 ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo "  ✅ PASS: $name"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo "  ❌ FAIL: $name"
  fi
}

report_summary() {
  echo "================================================="
  echo "               TEST SUITE SUMMARY               "
  echo "================================================="
  echo "Total Tests:  $TOTAL_TESTS"
  echo "Passed:       $PASSED_TESTS"
  echo "Failed:       $FAILED_TESTS"
  echo "================================================="

  # Output JSON summary
  cat <<EOF > test-report.json
{
  "total": $TOTAL_TESTS,
  "passed": $PASSED_TESTS,
  "failed": $FAILED_TESTS,
  "status": "$([ "$FAILED_TESTS" -eq 0 ] && echo "SUCCESS" || echo "FAILED")"
}
EOF

  if [ "$FAILED_TESTS" -gt 0 ]; then
    return 1
  fi
  return 0
}
