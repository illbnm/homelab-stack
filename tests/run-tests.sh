#!/usr/bin/env bash
# =============================================================================
# run-tests.sh - HomeLab Stack Integration Tests 入口脚本
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

DEFAULT_STACK_TIMEOUT=300
export TEST_TIMEOUT="${TEST_TIMEOUT:-$DEFAULT_STACK_TIMEOUT}"
REPORT_MODE="${REPORT_MODE:-terminal}"
SKIP_SLOW="${SKIP_SLOW_TESTS:-0}"
TARGET_STACK=""
RUN_E2E_ONLY=false
RUN_ALL_STACKS=false

# 颜色
if [[ -t 1 ]]; then
    COLOR_RED='\033[0;31m'; COLOR_GREEN='\033[0;32m'; COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'; COLOR_CYAN='\033[0;36m'; COLOR_BOLD='\033[1m'; COLOR_RESET='\033[0m'
else
    COLOR_RED=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_BLUE=''; COLOR_CYAN=''; COLOR_BOLD=''; COLOR_RESET=''
fi

show_help() {
    cat <<EOF
${COLOR_BOLD}HomeLab Stack — Integration Tests${COLOR_RESET}

${COLOR_BOLD}用法:${COLOR_RESET}
  $0 [选项]

${COLOR_BOLD}选项:${COLOR_RESET}
  ${COLOR_GREEN}--stack <name>${COLOR_RESET}     运行指定 stack 的测试
  ${COLOR_GREEN}--all${COLOR_RESET}              运行所有 stack 测试
  ${COLOR_GREEN}--e2e${COLOR_RESET}              只运行 E2E 测试
  ${COLOR_GREEN}--quick${COLOR_RESET}            快速测试（跳过慢速测试）
  ${COLOR_GREEN}--list${COLOR_RESET}             列出所有可用测试
  ${COLOR_GREEN}--json <file>${COLOR_RESET}     输出 JSON 格式报告
  ${COLOR_GREEN}--quiet${COLOR_RESET}            静默模式
  ${COLOR_GREEN}--help${COLOR_RESET}             显示帮助
EOF
}

list_tests() {
    echo "${COLOR_BOLD}可用测试:${COLOR_RESET}"
    echo ""
    echo "${COLOR_CYAN}Stack Tests:${COLOR_RESET}"
    for test_file in "$SCRIPT_DIR"/stacks/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            local name; name=$(basename "$test_file" .test.sh)
            echo "  - $name"
        fi
    done
    echo ""
    echo "${COLOR_CYAN}E2E Tests:${COLOR_RESET}"
    for test_file in "$SCRIPT_DIR"/e2e/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            local name; name=$(basename "$test_file" .test.sh)
            echo "  - $name"
        fi
    done
}

check_dependencies() {
    local missing=()
    if ! docker_available; then missing+=("docker"); fi
    if ! command -v jq &>/dev/null; then missing+=("jq"); fi
    if ! command -v curl &>/dev/null; then missing+=("curl"); fi
    if ((${#missing[@]} > 0)); then
        echo "${COLOR_RED}错误: 缺少必需依赖: ${missing[*]}${COLOR_RESET}" >&2
        exit 1
    fi
}

check_docker_daemon() {
    if ! docker info &>/dev/null; then
        echo "${COLOR_RED}错误: 无法连接到 Docker daemon${COLOR_RESET}" >&2
        exit 1
    fi
    local version; version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    echo "${COLOR_GREEN}✓${COLOR_RESET} Docker $version"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack) TARGET_STACK="$2"; shift 2 ;;
            --all) RUN_ALL_STACKS=true; shift ;;
            --e2e) RUN_E2E_ONLY=true; shift ;;
            --quick) SKIP_SLOW=1; shift ;;
            --list) list_tests; exit 0 ;;
            --json) report_set_json_file "$2"; REPORT_MODE=json; shift 2 ;;
            --quiet) REPORT_MODE=quiet; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) echo "${COLOR_RED}未知选项: $1${COLOR_RESET}" >&2; show_help; exit 1 ;;
        esac
    done
}

run_stack_test_file() {
    local test_file="$1"
    local test_name; test_name=$(basename "$test_file" .test.sh)
    TESTS_PASSED=0; TESTS_FAILED=0; TESTS_SKIPPED=0; TEST_RESULTS=()
    local group_start; group_start=$(date +%s)
    (
        set +e
        source "$test_file"
        if declare -f test_main &>/dev/null; then
            test_main
        fi
    )
    local exit_code=$?
    local duration=$(($(date +%s) - group_start))
    test_group_end "$test_name" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    return $exit_code
}

run_stack_tests() {
    local stacks=()
    if [[ -n "$TARGET_STACK" ]]; then
        IFS=',' read -ra stacks <<< "$TARGET_STACK"
    fi
    local total_passed=0; total_failed=0; total_skipped=0; total_duration=0
    local has_failures=false
    
    local stack_files=(
        "base.test.sh" "media.test.sh" "storage.test.sh" "monitoring.test.sh"
        "network.test.sh" "productivity.test.sh" "ai.test.sh" "sso.test.sh"
        "databases.test.sh" "notifications.test.sh" "dashboard.test.sh" "home-automation.test.sh"
    )
    
    for stack_file in "${stack_files[@]}"; do
        local stack_name="${stack_file%.test.sh}"
        if [[ "$RUN_ALL_STACKS" == "true" ]] || [[ " ${stacks[*]} " =~ " $stack_name " ]]; then
            if [[ -f "$SCRIPT_DIR/stacks/$stack_file" ]]; then
                test_group_start "$stack_name"
                run_stack_test_file "$SCRIPT_DIR/stacks/$stack_file" || has_failures=true
                total_passed=$((total_passed + TESTS_PASSED))
                total_failed=$((total_failed + TESTS_FAILED))
                total_skipped=$((total_skipped + TESTS_SKIPPED))
            fi
        fi
    done
    
    print_summary "$total_passed" "$total_failed" "$total_skipped" "$(get_elapsed)"
    if [[ "$has_failures" == "true" ]] || (( total_failed > 0 )); then
        return 1
    fi
    return 0
}

run_e2e_tests() {
    test_group_start "e2e"
    local total_passed=0; total_failed=0; total_skipped=0; has_failures=false
    for test_file in "$SCRIPT_DIR"/e2e/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            TESTS_PASSED=0; TESTS_FAILED=0; TESTS_SKIPPED=0; TEST_RESULTS=()
            local e2e_name; e2e_name=$(basename "$test_file" .test.sh)
            (
                set +e
                source "$test_file"
                if declare -f test_main &>/dev/null; then
                    test_main
                fi
            )
            if (( $? != 0 )); then has_failures=true; fi
            total_passed=$((total_passed + TESTS_PASSED))
            total_failed=$((total_failed + TESTS_FAILED))
            total_skipped=$((total_skipped + TESTS_SKIPPED))
        fi
    done
    test_group_end "e2e" "$total_passed" "$total_failed" "$total_skipped"
    if [[ "$has_failures" == "true" ]]; then return 1; fi
    return 0
}

main() {
    parse_args "$@"
    report_init
    print_header
    check_dependencies
    check_docker_daemon
    echo ""
    print_info "测试目录: $SCRIPT_DIR"
    print_info "项目目录: $PROJECT_ROOT"
    if [[ -n "$TARGET_STACK" ]]; then print_info "目标 Stack: $TARGET_STACK"
    elif [[ "$RUN_E2E_ONLY" == "true" ]]; then print_info "模式: E2E 测试"
    else print_info "模式: 所有 Stack 测试"; fi
    if [[ "$SKIP_SLOW" == "1" ]]; then print_info "快速模式: 已启用"; fi
    echo ""
    local exit_code=0
    if [[ "$RUN_E2E_ONLY" == "true" ]]; then
        run_e2e_tests || exit_code=$?
    else
        run_stack_tests || exit_code=$?
    fi
    if [[ "$REPORT_MODE" == "json" ]]; then
        echo ""
        json_output_report "$total_passed" "$total_failed" "$total_skipped"
    fi
    exit $exit_code
}

main "$@"
