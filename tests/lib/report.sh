#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Generator
# =============================================================================

REPORT_DIR="${REPORT_DIR:-/tmp/homelab-test-reports}"
REPORT_FILE="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S).json"

generate_report() {
    local total="$1" passed="$2" failed="$3" skipped="$4" duration="$5"
    local status="pass"
    [[ "$failed" -gt 0 ]] && status="fail"

    mkdir -p "$REPORT_DIR"
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "$status",
  "duration_seconds": $duration,
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped
  },
  "failed_tests": $(printf '%s\n' "${FAILED_TESTS[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "hostname": "$(hostname)",
  "docker_version": "$(docker --version 2>/dev/null | grep -oP '[\d.]+')",
  "os": "$(uname -srm)"
}
EOF
    echo -e "\n📄 Report saved: $REPORT_FILE"
}

print_summary() {
    local total="$1" passed="$2" failed="$3" skipped="$4" duration="$5"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 Test Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Passed:  $passed"
    echo "  ❌ Failed:  $failed"
    echo "  ⏭  Skipped: $skipped"
    echo "  📦 Total:   $total"
    echo "  ⏱  Duration: ${duration}s"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$failed" -gt 0 ]]; then
        echo ""
        echo "  Failed tests:"
        for t in "${FAILED_TESTS[@]}"; do
            echo "    ✗ $t"
        done
        echo ""
    fi

    if [[ "$failed" -eq 0 ]]; then
        echo -e "  \033[0;32m🎉 ALL TESTS PASSED\033[0m"
    else
        echo -e "  \033[0;31m💥 $failed TEST(S) FAILED\033[0m"
    fi
    echo ""
}
