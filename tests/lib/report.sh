#!/usr/bin/env bash
# HomeLab Stack — 测试报告生成

set -euo pipefail

# 生成 JSON 报告
generate_json_report() {
  local output_file="$1"
  local stack_name="$2"
  local total="$3"
  local passed="$4"
  local failed="$5"
  local skipped="$6"
  local duration="$7"
  
  cat > "$output_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "stack": "$stack_name",
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped
  },
  "duration_seconds": $duration,
  "status": "$([ "$failed" -eq 0 ] && echo "PASS" || echo "FAIL")"
}
EOF
}

# 生成终端报告
generate_terminal_report() {
  local stack_name="$1"
  local total="$2"
  local passed="$3"
  local failed="$4"
  local skipped="$5"
  local duration="$6"
  
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "Stack: $stack_name"
  echo "──────────────────────────────────────"
  echo "Results: $passed passed, $failed failed, $skipped skipped"
  echo "Total: $total tests"
  echo "Duration: ${duration}s"
  echo "──────────────────────────────────────"
  
  if [[ "$failed" -eq 0 ]]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    return 0
  else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    return 1
  fi
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
