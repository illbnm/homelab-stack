#!/usr/bin/env bash
# =============================================================================
# report.sh — 测试结果输出 (终端彩色 + JSON)
# =============================================================================

print_summary() {
  local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

  echo ""
  echo "=============================================="
  echo -e "  Tests: ${GREEN}${TESTS_PASSED} passed${NC}, ${RED}${TESTS_FAILED} failed${NC}, ${YELLOW}${TESTS_SKIPPED} skipped${NC} (${total} total)"
  echo "=============================================="

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failures:${NC}"
    for f in "${FAILURES[@]}"; do
      echo -e "  ${RED}✗${NC} ${f}"
    done
  fi

  echo ""
}

generate_json_report() {
  local output_file="${1:-test-results.json}"
  local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

  cat > "$output_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total": ${total},
    "passed": ${TESTS_PASSED},
    "failed": ${TESTS_FAILED},
    "skipped": ${TESTS_SKIPPED}
  },
  "failures": [
$(printf '    "%s",\n' "${FAILURES[@]}" | sed '$ s/,$//')
  ],
  "success": $([ $TESTS_FAILED -eq 0 ] && echo "true" || echo "false")
}
EOF

  echo "JSON report: ${output_file}"
}
