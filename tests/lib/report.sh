#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Report.sh — 测试结果报告生成
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 报告文件路径
REPORT_DIR="${REPORT_DIR:-tests/results}"
JSON_REPORT="${REPORT_DIR}/report.json"
TERM_WIDTH=$(tput cols 2>/dev/null || echo "80")

# 初始化报告数据
declare -A REPORT_DATA
REPORT_DATA["start_time"]="$(date -Iseconds)"
REPORT_DATA["total"]=0
REPORT_DATA["passed"]=0
REPORT_DATA["failed"]=0
REPORT_DATA["skipped"]=0
REPORT_DATA["duration"]=0
REPORT_DATA["suites"]=""
REPORT_DATA["tests"]=""

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

_report_format_json() {
  python3 -m json.tool 2>/dev/null || jq . 2>/dev/null || cat
}

_report_escape_json() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "$1"
}

# ═══════════════════════════════════════════════════════════════════════════
# 报告生成
# ═══════════════════════════════════════════════════════════════════════════

# report_init [suite_name]
report_init() {
  local suite_name="${1:-default}"
  REPORT_DATA["current_suite"]="$suite_name"
  REPORT_DATA["suite_$suite_name,tests"]=0
  REPORT_DATA["suite_$suite_name,passed"]=0
  REPORT_DATA["suite_$suite_name,failed"]=0
  REPORT_DATA["suite_$suite_name,skipped"]=0
  REPORT_DATA["suite_$suite_name,start"]="$(date +%s)"
}

# report_add_test <test_name> <status> <duration_sec> [message]
report_add_test() {
  local test_name="$1"
  local status="$2"
  local duration="$3"
  local message="${4:-}"

  local suite="${REPORT_DATA[current_suite]:-default}"

  # 更新总数
  ((REPORT_DATA["total"]++))
  ((REPORT_DATA["$status"]++))

  # 更新 suite 统计
  ((REPORT_DATA["suite_$suite,tests"]++))
  ((REPORT_DATA["suite_$suite,$status"]++))

  # 记录测试详情
  local test_entry="{\"name\":\"$test_name\",\"status\":\"$status\",\"duration\":$duration"
  if [[ -n "$message" ]]; then
    test_entry+=",\"message\":$(_report_escape_json "$message")"
  fi
  test_entry+="}"

  if [[ -z "${REPORT_DATA[tests]:-}" ]]; then
    REPORT_DATA["tests"]="$test_entry"
  else
    REPORT_DATA["tests"]="${REPORT_DATA[tests]},$test_entry"
  fi
}

# report_finish_suite [suite_name]
report_finish_suite() {
  local suite_name="${1:-${REPORT_DATA[current_suite]:-default}}"
  local end_time=$(date +%s)
  local start_time="${REPORT_DATA[suite_$suite_name,start]:-$end_time}"
  local duration=$((end_time - start_time))

  REPORT_DATA["suite_$suite_name,duration"]="$duration"
}

# report_write_json
report_write_json() {
  mkdir -p "$REPORT_DIR"

  local end_time=$(date +%s)
  local start_iso="${REPORT_DATA[start_time]}"
  local total_duration=$((end_time - $(date -d "$start_iso" +%s 2>/dev/null || echo "$end_time")))

  # 构建 suites 数组
  local suites_json=""
  for key in "${!REPORT_DATA[@]}"; do
    if [[ "$key" =~ ^suite_(.+),(tests|passed|failed|skipped|duration)$ ]]; then
      local suite_name="${BASH_REMATCH[1]}"
      # 这里简化处理，实际需要更复杂的数组构建
    fi
  done

  # 构建完整 JSON
  cat > "$JSON_REPORT" <<EOF
{
  "start_time": "${REPORT_DATA[start_time]}",
  "end_time": "$(date -Iseconds)",
  "duration": $total_duration,
  "total": ${REPORT_DATA[total]},
  "passed": ${REPORT_DATA[passed]},
  "failed": ${REPORT_DATA[failed]},
  "skipped": ${REPORT_DATA[skipped]},
  "suites": [],
  "tests": [${REPORT_DATA[tests]:-[]}]
}
EOF

  echo "📄 JSON report written to $JSON_REPORT"
}

# ═══════════════════════════════════════════════════════════════════════════
# 终端输出
# ═══════════════════════════════════════════════════════════════════════════

report_print_header() {
  clear
  _report_print_header
}

report_print_summary() {
  local total=${REPORT_DATA[total]:-0}
  local passed=${REPORT_DATA[passed]:-0}
  local failed=${REPORT_DATA[failed]:-0}
  local skipped=${REPORT_DATA[skipped]:-0}
  local duration=${REPORT_DATA[duration]:-0}

  echo
  echo "────────────────────────────────────────────────────────────────────────────────────────────"
  echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}, ${YELLOW}${skipped} skipped${NC} in ${BOLD}${duration}s${NC}"
  echo "────────────────────────────────────────────────────────────────────────────────────────────"
  echo

  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}❌ TESTS FAILED${NC}"
    return 1
  else
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    return 0
  fi
}

# 打印带颜色的测试行
_report_print_test_line() {
  local status="$1"
  local suite="$2"
  local test="$3"
  local duration="$4"

  local color="${NC}"
  local icon="  "

  if [[ "$status" == "passed" ]]; then
    color="${GREEN}"
    icon="✅"
  elif [[ "$status" == "failed" ]]; then
    color="${RED}"
    icon="❌"
  elif [[ "$status" == "skipped" ]]; then
    color="${YELLOW}"
    icon="⏭️ "
  fi

  # 计算缩进
  local suite_display="[$suite]"
  local line="${icon} ${BOLD}${suite_display}${NC} ${test}"

  echo -e "  $color$line${NC} (${duration}s)"
}

# ═══════════════════════════════════════════════════════════════════════════
# 导出
# ═══════════════════════════════════════════════════════════════════════════

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This library is meant to be sourced, not executed directly."
  exit 1
fi