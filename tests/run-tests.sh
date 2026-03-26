#!/usr/bin/env bash
# run-tests.sh — HomeLab Stack 集成测试入口
# 用法: ./run-tests.sh [--stack <name>] [--all] [--json] [--ci] [--help]
#
# 支持 PUA 压力模式：并行穷尽测试，不漏任何失败

set -euo pipefail

# ─── 变量 ────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
STACK_NAME=""
RUN_ALL=false
JSON_OUTPUT=false
CI_MODE=false
FAILED_STACKS=()

# 全局计数
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_START_TIME=$(date +%s)

# ─── 加载库 ──────────────────────────────────────────────────
source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"
source "$TESTS_DIR/lib/report.sh"

# ─── 帮助文档 ────────────────────────────────────────────────
show_help() {
    cat <<'EOF'
HomeLab Stack — Integration Tests

用法:
  ./run-tests.sh [选项]

选项:
  --stack <name>     运行指定 stack 的测试 (e.g., --stack base)
  --all              运行所有 stack 的测试
  --json             输出 JSON 报告到 tests/results/report.json
  --ci               CI 模式：简洁输出，exit code 0/1
  --help, -h         显示本帮助

示例:
  ./run-tests.sh --stack base           # 测试 base 栈
  ./run-tests.sh --stack monitoring      # 测试监控栈
  ./run-tests.sh --all                   # 测试所有栈
  ./run-tests.sh --all --json            # 全部测试 + JSON 报告

每个测试文件对应一个 stack：
  stacks/base.test.sh
  stacks/media.test.sh
  stacks/monitoring.test.sh
  ...以此类推

PUA 原则：
  - Level 1 必须通过（容器运行 + healthcheck）
  - Level 2 必须通过（HTTP 端点可达）
  - Level 3 尽力（服务间互通）
  - Level 4 E2E 尽力（SSO 流程等）
EOF
}

# ─── 参数解析 ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            STACK_NAME="$2"; shift 2 ;;
        --all) RUN_ALL=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --ci) CI_MODE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "未知参数: $1"; show_help; exit 1 ;;
    esac
done

# ─── 环境检查 ────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    
    command -v docker &>/dev/null || missing+=("docker")
    command -v jq &>/dev/null || missing+=("jq")
    command -v curl &>/dev/null || missing+=("curl")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}" >&2
        exit 1
    fi
    
    # 检查 docker compose v2
    if ! docker compose version &>/dev/null; then
        echo -e "${RED}❌ Docker Compose v2 is required${NC}" >&2
        exit 1
    fi
}

# ─── 运行单个测试文件 ────────────────────────────────────────
run_stack_test() {
    local stack="$1"
    local test_file="$TESTS_DIR/stacks/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}⚠️  No test file for stack: $stack${NC}"
        return 0
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Testing stack: $stack${NC}"
    
    # 设置环境
    export STACK_NAME="$stack"
    export STACK_DIR="$ROOT_DIR/stacks/$stack"
    
    # 执行测试（source 以继承 assert 变量）
    local test_start=$(date +%s)
    if source "$test_file"; then
        local test_duration=$(($(date +%s) - test_start))
        echo -e "${GREEN}✅ Stack '$stack' passed ($test_duration s)${NC}"
    else
        FAILED_STACKS+=("$stack")
        echo -e "${RED}❌ Stack '$stack' failed${NC}"
    fi
    
    unset STACK_NAME STACK_DIR
}

# ─── 主流程 ──────────────────────────────────────────────────
main() {
    check_dependencies
    report_header
    
    if [[ "$RUN_ALL" == "true" ]]; then
        # 测试所有 stack
        local stacks=$(ls "$ROOT_DIR/stacks/" 2>/dev/null || echo "")
        for stack in $stacks; do
            if [[ -d "$ROOT_DIR/stacks/$stack" ]]; then
                run_stack_test "$stack" || true
            fi
        done
    elif [[ -n "$STACK_NAME" ]]; then
        run_stack_test "$STACK_NAME"
    else
        echo -e "${RED}❌ 请指定 --stack <name> 或 --all${NC}"
        show_help
        exit 1
    fi
    
    # 最终统计
    local total_duration=$(($(date +%s) - TOTAL_START_TIME))
    report_summary "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$total_duration"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        report_json "$TESTS_DIR/results/report.json" \
            "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$total_duration"
    fi
    
    if [[ "$CI_MODE" == "true" ]]; then
        report_ci "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
    fi
    
    # Exit code
    if [[ ${#FAILED_STACKS[@]} -gt 0 ]] || [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main
