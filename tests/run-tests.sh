#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# run-tests.sh — HomeLab Stack 集成测试主入口
#
# 用法:
#   ./tests/run-tests.sh [OPTIONS]
#
# 选项:
#   --stack <name>      运行指定 stack 的测试 (默认: all)
#   --list              列出所有可测试的 stacks
#   --json              输出 JSON 报告到 tests/results/report.json
#   --help              显示此帮助信息
#
# 示例:
#   ./tests/run-tests.sh --stack base
#   ./tests/run-tests.sh --all --json
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
STACKS_DIR="$SCRIPT_DIR/stacks"
E2E_DIR="$SCRIPT_DIR/e2e"
RESULTS_DIR="$SCRIPT_DIR/results"

# 加载断言库和工具库
source "$LIB_DIR/assert.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/report.sh"

# 默认配置
RUN_STACK="all"
GENERATE_JSON=false
VERBOSE=false

# ═══════════════════════════════════════════════════════════════════════════
# 参数解析
# ═══════════════════════════════════════════════════════════════════════════

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        RUN_STACK="$2"
        shift 2
        ;;
      --all)
        RUN_STACK="all"
        shift
        ;;
      --list)
        list_stacks
        exit 0
        ;;
      --json)
        GENERATE_JSON=true
        shift
        ;;
      --verbose|-v)
        VERBOSE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

show_help() {
  grep '^#' "$0" | cut -c4- | head -n 30
}

list_stacks() {
  echo "Available test stacks:"
  for f in "$STACKS_DIR"/*.test.sh; do
    local name=$(basename "$f" .test.sh)
    echo "  - $name"
  done
  echo "E2E tests:"
  for f in "$E2E_DIR"/*.test.sh 2>/dev/null; do
    local name=$(basename "$f" .test.sh)
    echo "  - $name (e2e)"
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# 测试执行器
# ═══════════════════════════════════════════════════════════════════════════

run_test_file() {
  local test_file="$1"
  local suite_name=$(basename "$test_file" .test.sh)

  if $VERBOSE; then
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}▶ Suite: $suite_name${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
  fi

  report_init "$suite_name"

  # 加载测试文件（它会调用断言函数）
  if source "$test_file"; then
    # 测试文件应该调用 run_tests 函数
    if declare -F run_tests >/dev/null; then
      local suite_start=$(date +%s)
      run_tests
      local suite_end=$(date +%s)
      local suite_duration=$((suite_end - suite_start))
      report_finish_suite "$suite_name"
    else
      echo "⚠️  No run_tests function in $test_file"
    fi
  else
    echo "❌ Failed to source $test_file"
    return 1
  fi

  # 清理函数命名空间
  unset -f run_tests 2>/dev/null || true
}

run_all_stacks() {
  local failed_stacks=()

  for test_file in "$STACKS_DIR"/*.test.sh; do
    if [[ -f "$test_file" ]]; then
      run_test_file "$test_file" || failed_stacks+=("$(basename "$test_file" .test.sh)")
    fi
  done

  # E2E 测试可选运行
  if [[ -d "$E2E_DIR" ]] && [[ ${RUN_E2E:-false} == "true" ]]; then
    for test_file in "$E2E_DIR"/*.test.sh; do
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file" || failed_stacks+=("$(basename "$test_file" .test.sh) [e2e]")
      fi
    done
  fi

  # 总结
  if [[ ${#failed_stacks[@]} -gt 0 ]]; then
    echo
    echo -e "${RED}Failed stacks:${NC}"
    for s in "${failed_stacks[@]}"; do
      echo "  ❌ $s"
    done
    return 1
  fi
}

run_single_stack() {
  local stack_name="$RUN_STACK"
  local test_file="$STACKS_DIR/${stack_name}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    echo "❌ Stack test not found: $stack_name"
    echo "Use --list to see available stacks."
    exit 1
  fi

  run_test_file "$test_file"
}

# ═══════════════════════════════════════════════════════════════════════════
# 主逻辑
# ═══════════════════════════════════════════════════════════════════════════

main() {
  parse_args "$@"

  # 检查依赖
  if ! command -v docker &>/dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
  fi

  if ! command -v curl &>/dev/null; then
    echo "❌ curl is not installed"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "❌ jq is not installed (required for JSON assertions)"
    exit 1
  fi

  # 重置断言库统计
  assert_reset_stats

  # 开始时间
  local start_time=$(date +%s)
  REPORT_DATA["start_time"]="$(date -Iseconds)"

  echo
  _report_print_header
  echo -e "${CYAN}Running tests:${NC} ${BOLD}$RUN_STACK${NC}"
  echo

  # 执行测试
  local exit_code=0
  if [[ "$RUN_STACK" == "all" ]]; then
    run_all_stacks
    exit_code=$?
  else
    run_single_stack
    exit_code=$?
  fi

  local end_time=$(date +%s)
  local total_duration=$((end_time - start_time))
  REPORT_DATA["duration"]=$total_duration

  echo
  echo "────────────────────────────────────────────────────────────────────────────────────────────"
  echo -e "Total duration: ${BOLD}${total_duration}s${NC}"
  echo

  # 打印摘要
  report_print_summary
  exit_code=$?

  # 生成 JSON 报告
  if $GENERATE_JSON; then
    report_write_json
  fi

  exit $exit_code
}

# ═══════════════════════════════════════════════════════════════════════════
# 执行
# ═══════════════════════════════════════════════════════════════════════════

main "$@"