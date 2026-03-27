#!/bin/bash
# =============================================================================
# Report Library — HomeLab Stack Integration Tests
# =============================================================================
# Description: Colored terminal output + JSON report generation
# Usage: source this library in test scripts
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-${SCRIPT_DIR}/../results}"
JSON_REPORT="${RESULTS_DIR}/report.json"
SUITE_START_TIME=""

mkdir -p "$RESULTS_DIR"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_DIM='\033[2m'

# Unicode box-drawing
BOX_TOP="╔══════════════════════════════════════════════════════════════════╗"
BOX_MID="╟──────────────────────────────────────────────────────────────────╢"
BOX_BOT="╚══════════════════════════════════════════════════════════════════╝"

# -----------------------------------------------------------------------------
# report_banner — 打印测试横幅
# Usage: report_banner [title]
# -----------------------------------------------------------------------------
report_banner() {
    local title="${1:-HomeLab Stack — Integration Tests}"
    echo ""
    echo -e "${C_BOLD}${C_BLUE}${BOX_TOP}${C_RESET}"
    printf "${C_BOLD}${C_BLUE}║%*s${C_RESET}\n" 66 "HomeLab Stack — Integration Tests"
    echo -e "${C_BOLD}${C_BLUE}${BOX_BOT}${C_RESET}"
    SUITE_START_TIME=$(date +%s)
}

# -----------------------------------------------------------------------------
# suite_header — 打印suite标题
# Usage: suite_header <suite_name>
# -----------------------------------------------------------------------------
suite_header() {
    local name="$1"
    local len=${#name}
    local pad=$((66 - len))
    echo ""
    echo -e "${C_BOLD}${C_BLUE}╠══════════════════════════════════════╣${C_RESET}"
    printf "${C_BOLD}${C_BLUE}║  %s${C_RESET}" "$name"
    printf "%${pad}s╢\n" " "
    echo -e "${C_BOLD}${C_BLUE}╠══════════════════════════════════════╣${C_RESET}"
}

# -----------------------------------------------------------------------------
# test_result — 打印单个测试结果
# Usage: test_result <pass|fail|skip> <name> [duration]
# -----------------------------------------------------------------------------
test_result() {
    local status="$1"
    local name="$2"
    local duration="${3:-0.0}"

    local icon color
    case "$status" in
        pass)
            icon="✅"
            color="$C_GREEN"
            ;;
        fail)
            icon="❌"
            color="$C_RED"
            ;;
        skip)
            icon="⏭️"
            color="$C_YELLOW"
            ;;
    esac

    local dur_str=""
    if [[ -n "$duration" && "$duration" != "0.0" ]]; then
        dur_str=" (${duration}s)"
    fi

    echo -e "  ${color}${icon}${C_RESET} ${name}${C_DIM}${dur_str}${C_RESET}"
}

# -----------------------------------------------------------------------------
# suite_summary — 打印suite汇总
# Usage: suite_summary <passed> <failed> <skipped>
# -----------------------------------------------------------------------------
suite_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"

    echo ""
    echo -e "${C_DIM}────────────────────────────────────────${C_RESET}"

    local total=$((passed + failed + skipped))
    if [[ $failed -gt 0 ]]; then
        echo -e "${C_RED}❌ Failed: $failed / $total${C_RESET}"
    fi
    if [[ $skipped -gt 0 ]]; then
        echo -e "${C_YELLOW}⏭️  Skipped: $skipped / $total${C_RESET}"
    fi
    echo -e "${C_GREEN}✅ Passed: $passed / $total${C_RESET}"
}

# -----------------------------------------------------------------------------
# report_summary — 打印最终汇总
# Usage: report_summary <passed> <failed> <skipped> <duration>
# -----------------------------------------------------------------------------
report_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="$4"

    echo ""
    echo -e "${C_BOLD}${C_BLUE}${BOX_TOP}${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}║  RESULTS${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}${BOX_MID}${C_RESET}"

    local total=$((passed + failed + skipped))
    printf "${C_BOLD}${C_GREEN}║  ✅ Passed:  %-5d %-40s${C_RESET}\n" "$passed" "/ $total"
    if [[ $failed -gt 0 ]]; then
        printf "${C_BOLD}${C_RED}║  ❌ Failed:  %-5d${C_RESET}\n" "$failed"
    fi
    if [[ $skipped -gt 0 ]]; then
        printf "${C_BOLD}${C_YELLOW}║  ⏭️  Skipped: %-5d${C_RESET}\n" "$skipped"
    fi
    printf "${C_BOLD}${C_BLUE}║  ⏱️  Duration: %s seconds${C_RESET}\n" "$duration"
    echo -e "${C_BOLD}${C_BLUE}${BOX_BOT}${C_RESET}"
}

# -----------------------------------------------------------------------------
# generate_json_report — 生成JSON报告
# Usage: generate_json_report <passed> <failed> <skipped> <duration>
# -----------------------------------------------------------------------------
generate_json_report() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="$4"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local status="pass"
    [[ $failed -gt 0 ]] && status="fail"

    cat > "$JSON_REPORT" <<EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "summary": {
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped,
    "total": $((passed + failed + skipped))
  },
  "duration_seconds": $duration,
  "suites": [
    $(cat "${RESULTS_DIR}/suite_results.json" 2>/dev/null || echo "")
  ]
}
EOF
    echo -e "${C_CYAN}📄 JSON report: $JSON_REPORT${C_RESET}"
}

# -----------------------------------------------------------------------------
# suite_start_json — 开始记录suite结果
# Usage: suite_start_json <suite_name>
# -----------------------------------------------------------------------------
suite_start_json() {
    local suite="$1"
    echo "{\"suite\": \"$suite\", \"tests\": []}" > "${RESULTS_DIR}/current_suite.json"
}

# -----------------------------------------------------------------------------
# suite_end_json — 结束并追加suite结果
# Usage: suite_end_json <suite_name> <passed> <failed> <skipped>
# -----------------------------------------------------------------------------
suite_end_json() {
    local suite="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"

    local results_file="${RESULTS_DIR}/suite_results.json"
    local suite_json
    suite_json=$(cat "${RESULTS_DIR}/current_suite.json" 2>/dev/null)

    echo "[{\"suite\": \"$suite\", \"passed\": $passed, \"failed\": $failed, \"skipped\": $skipped}]" >> "$results_file"
}
