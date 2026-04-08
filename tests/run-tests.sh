#!/usr/bin/env bash
# HomeLab Stack — 测试入口

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 帮助信息
show_help() {
  cat <<EOF
HomeLab Stack — Integration Tests

用法:
  $0 [选项]

选项:
  --stack <name>    测试特定 stack (base, media, storage, etc.)
  --all             测试所有 stack
  --json            输出 JSON 报告
  --help            显示此帮助信息

示例:
  $0 --stack base              # 测试 base stack
  $0 --all                     # 测试所有 stack
  $0 --stack media --json      # 测试 media stack 并输出 JSON

EOF
  exit 0
}

# 解析参数
STACK=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK="$2"
      shift 2
      ;;
    --all)
      STACK="all"
      shift
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# 加载断言库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# 测试结果
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
START_TIME=$(date +%s)

# 运行测试
run_tests() {
  local stack="$1"
  local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
  
  if [[ -f "$test_file" ]]; then
    echo ""
    echo "Running tests for stack: $stack"
    echo "──────────────────────────────────────"
    source "$test_file"
  else
    echo -e "${YELLOW}⚠️  No tests found for stack: $stack${NC}"
    ((SKIPPED_TESTS++))
  fi
}

# 主逻辑
if [[ -z "$STACK" ]]; then
  echo "Error: Please specify --stack <name> or --all"
  show_help
fi

if [[ "$STACK" == "all" ]]; then
  # 测试所有 stack
  for test_file in "$SCRIPT_DIR/stacks"/*.test.sh; do
    if [[ -f "$test_file" ]]; then
      stack_name=$(basename "$test_file" .test.sh)
      run_tests "$stack_name"
    fi
  done
else
  # 测试特定 stack
  run_tests "$STACK"
fi

# 生成报告
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ "$OUTPUT_JSON" == true ]]; then
  mkdir -p "$SCRIPT_DIR/results"
  generate_json_report "$SCRIPT_DIR/results/report.json" "$STACK" "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED" "$DURATION"
  cat "$SCRIPT_DIR/results/report.json"
else
  generate_terminal_report "$STACK" "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED" "$DURATION"
fi

# 退出码
if [[ "$TESTS_FAILED" -gt 0 ]]; then
  exit 1
else
  exit 0
fi
