#!/usr/bin/env bash
# report.sh — 结果输出 for HomeLab Stack Integration Tests
# 终端彩色输出 + JSON 双报告

set -euo pipefail

# ─── 颜色定义 ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── 头部 ────────────────────────────────────────────────────
report_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   HomeLab Stack — Integration Tests           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${DIM}Stack:${NC}   ${BOLD}${STACK_NAME:-all}${NC}"
    echo -e "  ${DIM}Time:${NC}    $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  ${DIM}Host:${NC}    $(hostname)"
    echo ""
}

# ─── 测试分组标题 ─────────────────────────────────────────────
report_section() {
    local name="$1"
    echo ""
    echo -e "${MAGENTA}═══ $name ═══${NC}"
}

# ─── 单行测试结果（与 assert.sh 协同）────────────────────────
# 由 assert.sh 直接调用

# ─── 分隔线 ───────────────────────────────────────────────────
report_divider() {
    echo ""
    echo -e "${DIM}──────────────────────────────────────────────${NC}"
}

# ─── 最终汇总 ────────────────────────────────────────────────
report_summary() {
    local passed="$1" failed="$2" skipped="$3" duration="$4"
    local total=$((passed + failed + skipped))
    
    report_divider
    
    # 彩色数字
    local pass_str="${GREEN}${passed} passed${NC}"
    local fail_str="${RED}${failed} failed${NC}"
    local skip_str="${YELLOW}${skipped} skipped${NC}"
    
    if [[ $failed -gt 0 ]]; then
        echo -e "  ${BOLD}Results:${NC}  $pass_str, $fail_str, $skip_str"
        echo -e "  ${BOLD}Status:${NC}  ${RED}❌ FAILED${NC}"
    elif [[ $skipped -gt 0 ]]; then
        echo -e "  ${BOLD}Results:${NC}  $pass_str, $fail_str, $skip_str"
        echo -e "  ${BOLD}Status:${NC}  ${YELLOW}⚠️  PARTIAL${NC}"
    else
        echo -e "  ${BOLD}Results:${NC}  $pass_str, $fail_str, $skip_str"
        echo -e "  ${BOLD}Status:${NC}  ${GREEN}✅ ALL PASSED${NC}"
    fi
    
    echo -e "  ${BOLD}Duration:${NC} ${duration}s"
    report_divider
    echo ""
}

# ─── JSON 报告 ────────────────────────────────────────────────
report_json() {
    local output_file="${1:-tests/results/report.json}"
    local passed="$2" failed="$3" skipped="$4" duration="$5"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local status="success"
    [[ $failed -gt 0 ]] && status="failed"
    [[ $skipped -gt 0 && $failed -eq 0 ]] && status="partial"
    
    # 收集所有环境信息
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    
    mkdir -p "$(dirname "$output_file")"
    
    cat > "$output_file" <<EOF
{
  "timestamp": "$timestamp",
  "tool": "homelab-integration-tests",
  "version": "1.0.0",
  "stack": "${STACK_NAME:-all}",
  "host": "$(hostname)",
  "docker_version": "$docker_version",
  "summary": {
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped,
    "total": $((passed + failed + skipped)),
    "duration_seconds": $duration
  },
  "status": "$status"
}
EOF
    
    echo -e "${DIM}JSON report → $output_file${NC}"
}

# ─── 简洁进度输出（用于 CI）──────────────────────────────────
report_ci() {
    local passed="$1" failed="$2" skipped="$3"
    
    echo "TESTS_PASSED=$passed"
    echo "TESTS_FAILED=$failed"
    echo "TESTS_SKIPPED=$skipped"
    
    if [[ $failed -gt 0 ]]; then
        echo "STATUS=failed"
        exit 1
    fi
    exit 0
}
