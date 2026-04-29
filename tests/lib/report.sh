#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE=""
REPORT_JSON=""
REPORT_SUITE=""
REPORT_RESULTS=()

report_init() {
    REPORT_RESULTS_DIR="${RESULTS_DIR:-tests/results}"
    mkdir -p "$REPORT_RESULTS_DIR"
    REPORT_FILE="$REPORT_RESULTS_DIR/report.txt"
    REPORT_JSON="$REPORT_RESULTS_DIR/report.json"
    REPORT_RESULTS=()
    echo "" > "$REPORT_FILE"
}

report_suite() {
    REPORT_SUITE="$1"
}

report_add() {
    local test_name="$1" status="$2" duration="${3:-0}"
    REPORT_RESULTS+=("${REPORT_SUITE}|${test_name}|${status}|${duration}")
}

report_print_summary() {
    source "${TEST_LIB_DIR}/assert.sh"
    local total=$(( ASSERT_PASS + ASSERT_FAIL + ASSERT_SKIP ))
    local duration=$(( SECONDS - ASSERT_START_TIME ))

    echo ""
    echo "──────────────────────────────────────"
    echo -e "Results: \033[32m$ASSERT_PASS passed\033[0m, \033[31m$ASSERT_FAIL failed\033[0m, \033[33m$ASSERT_SKIP skipped\033[0m"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────"

    echo "Results: $ASSERT_PASS passed, $ASSERT_FAIL failed, $ASSERT_SKIP skipped" > "$REPORT_FILE"
    echo "Duration: ${duration}s" >> "$REPORT_FILE"
}

report_write_json() {
    local total=$(( ASSERT_PASS + ASSERT_FAIL + ASSERT_SKIP ))
    local duration=$(( SECONDS - ASSERT_START_TIME ))
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$REPORT_JSON" <<EOF
{
  "timestamp": "$timestamp",
  "total": $total,
  "passed": $ASSERT_PASS,
  "failed": $ASSERT_FAIL,
  "skipped": $ASSERT_SKIP,
  "duration_seconds": $duration,
  "results": [
$(local first=true; for r in "${REPORT_RESULTS[@]:-}"; do
    IFS='|' read -r suite test status dur <<< "$r"
    if [[ "$first" == "true" ]]; then first=false; else echo ","; fi
    printf '    {"suite": "%s", "test": "%s", "status": "%s", "duration": %s}' "$suite" "$test" "$status" "$dur"
done)
  ]
}
EOF
}