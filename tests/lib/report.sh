#!/usr/bin/env bash
# =============================================================================
# report.sh - 结果输出库 (JSON + 终端彩色) for HomeLab Stack Integration Tests
# =============================================================================

# 颜色定义
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_BOLD='\033[1m'
export COLOR_DIM='\033[2m'
export COLOR_RESET='\033[0m'

# Emoji 定义
export EMOJI_PASS="✅"
export EMOJI_FAIL="❌"
export EMOJI_SKIP="⏭️"
export EMOJI_INFO="ℹ️"
export EMOJI_WARN="⚠️"
export EMOJI_ROCKET="🚀"
export EMOJI_CLOCK="🕐"
export EMOJI_DOCKER="🐳"
export EMOJI_STACK="📦"
export EMOJI_CHECK="🔍"
export EMOJI_NET="🌐"

# 输出模式
export REPORT_MODE="${REPORT_MODE:-terminal}"
export JSON_OUTPUT_FILE="${JSON_OUTPUT_FILE:-}"
export TEST_START_TIME=""
export CURRENT_STACK=""
export CURRENT_TEST=""
export TEST_START_STAMP=""
export TEST_GROUP_START_TIME=""

# -----------------------------------------------------------------------------
# 报告初始化
# -----------------------------------------------------------------------------
report_init() {
    TEST_START_TIME=$(date +%s)
    if [[ -n "$JSON_OUTPUT_FILE" ]]; then
        echo "[]" > "$JSON_OUTPUT_FILE"
    fi
}

report_set_mode() {
    local mode="$1"
    case "$mode" in
        terminal|json|quiet) REPORT_MODE="$mode" ;;
        *) echo "Unknown report mode: $mode" >&2 ;;
    esac
}

report_set_json_file() {
    JSON_OUTPUT_FILE="$1"
}

# -----------------------------------------------------------------------------
# 格式化输出函数
# -----------------------------------------------------------------------------
format_duration() {
    local seconds="$1"
    if (( seconds < 1 )); then
        echo "0.1s"
    elif (( seconds < 60 )); then
        printf "%.1fs" "$seconds"
    elif (( seconds < 3600 )); then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        printf "%dm %ds" "$mins" "$secs"
    else
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        printf "%dh %dm" "$hours" "$mins"
    fi
}

get_elapsed() {
    local now
    now=$(date +%s)
    echo $((now - TEST_START_TIME))
}

get_test_duration() {
    local start="$1"
    local end="${2:-$(date +%s)}"
    echo $((end - start))
}

# -----------------------------------------------------------------------------
# 终端输出函数
# -----------------------------------------------------------------------------
print_header() {
    local title="${1:-HomeLab Stack — Integration Tests}"
    local width="${2:-50}"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    local border=""
    for ((i=0; i<width; i++)); do border+="═"; done
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╔${border}╗${COLOR_RESET}"
    printf "${COLOR_BOLD}${COLOR_CYAN}║${COLOR_RESET} %-${width}s ${COLOR_BOLD}${COLOR_CYAN}║${COLOR_RESET}\n" "$title"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╚${border}╝${COLOR_RESET}"
    echo ""
}

print_divider() {
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    local char="${1:-─}"
    local len="${2:-50}"
    local line=""
    for ((i=0; i<len; i++)); do line+="$char"; done
    echo -e "${COLOR_DIM}${line}${COLOR_RESET}"
}

print_group_header() {
    local group_name="$1"
    local description="${2:-}"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}[$group_name]${COLOR_RESET} ${COLOR_CYAN}${description}${COLOR_RESET}"
    print_divider "─" 50
}

print_test_result() {
    local test_name="$1"
    local status="$2"
    local duration="${3:-0}"
    local message="${4:-}"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    local color status_icon
    case "$status" in
        PASS) color="$COLOR_GREEN"; status_icon="$EMOJI_PASS" ;;
        FAIL) color="$COLOR_RED"; status_icon="$EMOJI_FAIL" ;;
        SKIP) color="$COLOR_YELLOW"; status_icon="$EMOJI_SKIP" ;;
        INFO) color="$COLOR_BLUE"; status_icon="$EMOJI_INFO" ;;
        *) color="$COLOR_RESET"; status_icon="$EMOJI_CHECK" ;;
    esac
    local duration_str; duration_str=$(format_duration "$duration")
    printf "${COLOR_BOLD}%-35s${COLOR_RESET} " "$test_name"
    printf "${color}%s${COLOR_RESET} " "$status_icon"
    printf "${COLOR_BOLD}${color}%s${COLOR_RESET}" "$status"
    printf " ${COLOR_DIM}(%s)${COLOR_RESET}" "$duration_str"
    if [[ -n "$message" ]]; then
        printf " ${COLOR_DIM}- %s${COLOR_RESET}" "$message"
    fi
    echo ""
}

print_summary_header() {
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    echo ""
    print_divider "═" 50
    echo -e "${COLOR_BOLD}${COLOR_CYAN}测试摘要${COLOR_RESET}"
    print_divider "─" 50
}

print_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="${4:-$(get_elapsed)}"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    print_summary_header
    local total=$((passed + failed + skipped))
    echo -e "  ${EMOJI_CHECK} 总计: ${COLOR_BOLD}$total${COLOR_RESET} 测试"
    echo ""
    echo -e "  $EMOJI_PASS ${COLOR_GREEN}通过: $passed${COLOR_RESET}"
    if (( failed > 0 )); then
        echo -e "  $EMOJI_FAIL ${COLOR_RED}失败: $failed${COLOR_RESET}"
    else
        echo -e "  $EMOJI_FAIL ${COLOR_DIM}失败: $failed${COLOR_RESET}"
    fi
    if (( skipped > 0 )); then
        echo -e "  $EMOJI_SKIP ${COLOR_YELLOW}跳过: $skipped${COLOR_RESET}"
    fi
    echo ""
    echo -e "  ${EMOJI_CLOCK} 耗时: ${COLOR_BOLD}$(format_duration "$duration")${COLOR_RESET}"
    print_divider "═" 50
    if (( failed == 0 )); then
        echo ""
        echo -e "${COLOR_BOLD}${COLOR_GREEN}$EMOJI_ROCKET 所有测试通过!${COLOR_RESET}"
    else
        echo ""
        echo -e "${COLOR_BOLD}${COLOR_RED}$EMOJI_FAIL 有测试失败，请检查日志${COLOR_RESET}"
    fi
    echo ""
}

print_info() {
    local message="$1"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    echo -e "${COLOR_BLUE}$EMOJI_INFO${COLOR_RESET} ${COLOR_DIM}$message${COLOR_RESET}"
}

print_warn() {
    local message="$1"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    echo -e "${COLOR_YELLOW}$EMOJI_WARN${COLOR_RESET} ${COLOR_YELLOW}$message${COLOR_RESET}"
}

print_error() {
    local message="$1"
    echo -e "${COLOR_RED}$EMOJI_FAIL${COLOR_RESET} ${COLOR_RED}$message${COLOR_RESET}"
}

# -----------------------------------------------------------------------------
# JSON 输出函数
# -----------------------------------------------------------------------------
json_add_record() {
    local test_name="$1"
    local status="$2"
    local duration="$3"
    local message="${4:-}"
    local stack="${5:-$CURRENT_STACK}"
    local record
    record=$(cat <<EOF
{
    "name": "$test_name",
    "status": "$status",
    "duration": $duration,
    "message": "$message",
    "stack": "$stack",
    "timestamp": "$(date -Iseconds)"
}
EOF
)
    if [[ -n "$JSON_OUTPUT_FILE" ]]; then
        local tmp_file; tmp_file=$(mktemp)
        jq --argjson record "$record" '. += [$record]' "$JSON_OUTPUT_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$JSON_OUTPUT_FILE"
    fi
}

json_output_report() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="${4:-$(get_elapsed)}"
    cat <<EOF
{
    "summary": {
        "passed": $passed,
        "failed": $failed,
        "skipped": $skipped,
        "total": $((passed + failed + skipped)),
        "duration": $duration,
        "exit_code": $(if ((failed > 0)); then echo 1; else echo 0; fi)
    },
    "results": [],
    "metadata": {
        "docker_version": "$(get_docker_version 2>/dev/null || echo 'unknown')",
        "docker_compose_version": "$(get_docker_compose_version 2>/dev/null || echo 'unknown')",
        "hostname": "$(hostname)",
        "timestamp": "$(date -Iseconds)"
    }
}
EOF
}

# -----------------------------------------------------------------------------
# 进度显示
# -----------------------------------------------------------------------------
test_group_start() {
    local group_name="$1"
    CURRENT_STACK="$group_name"
    TEST_GROUP_START_TIME=$(date +%s)
}

test_group_end() {
    local group_name="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    if [[ "$REPORT_MODE" == "quiet" ]]; then return; fi
    local duration=$(($(date +%s) - TEST_GROUP_START_TIME))
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}[$group_name]${COLOR_RESET} 完成 "
    echo -e "  ${COLOR_GREEN}$EMOJI_PASS $passed${COLOR_RESET} ${COLOR_RED}$EMOJI_FAIL $failed${COLOR_RESET} ${COLOR_YELLOW}$EMOJI_SKIP $skipped${COLOR_RESET} ${COLOR_DIM}($(format_duration $duration))${COLOR_RESET}"
}

test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TEST_START_STAMP=$(date +%s)
    if [[ "$REPORT_MODE" == "terminal" ]]; then
        printf "${COLOR_BOLD}%-35s${COLOR_RESET} ${COLOR_CYAN}▶${COLOR_RESET} " "$test_name"
    fi
}

test_end() {
    local test_name="$1"
    local status="$2"
    local message="${3:-}"
    local duration
    if [[ -n "$TEST_START_STAMP" ]]; then
        duration=$(($(date +%s) - TEST_START_STAMP))
    else
        duration=0
    fi
    json_add_record "$test_name" "$status" "$duration" "$message" "$CURRENT_STACK"
    if [[ "$REPORT_MODE" == "terminal" ]]; then
        print_test_result "$test_name" "$status" "$duration" "$message"
    elif [[ "$REPORT_MODE" == "quiet" ]]; then
        if [[ "$status" == "FAIL" ]]; then
            print_test_result "$test_name" "$status" "$duration" "$message"
        fi
    fi
}

export -f report_init report_set_mode report_set_json_file
export -f format_duration get_elapsed get_test_duration
export -f print_header print_divider print_group_header print_test_result
export -f print_summary_header print_summary print_info print_warn print_error
export -f json_add_record json_output_report
export -f test_group_start test_group_end test_start test_end
