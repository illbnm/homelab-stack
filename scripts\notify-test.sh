#!/usr/bin/env bash
# =============================================================================
# notify-test.sh — 通知系统集成测试脚本
# =============================================================================
#
# 用法: scripts/notify-test.sh [backend]
#   backend: ntfy | gotify | all (默认: ntfy)
#
# 此脚本测试通知系统的完整功能，包括：
#   - 基本消息发送
#   - 不同优先级
#   - 多标签
#   - 各后端连通性
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY="${SCRIPT_DIR}/notify.sh"

if [[ ! -x "${NOTIFY}" ]]; then
  chmod +x "${NOTIFY}"
fi

BACKEND="${1:-ntfy}"
PASS_COUNT=0
FAIL_COUNT=0

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test()    { echo -e "${BLUE}[TEST]${NC}  $*"; }
log_pass()    { echo -e "${GREEN}[PASS]${NC}  $*"; PASS_COUNT=$((PASS_COUNT+1)); }
log_fail()    { echo -e "${RED}[FAIL]${NC}  $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
log_section() { echo -e "\n${YELLOW}══ $* ══${NC}"; }

# -----------------------------------------------------------------------------
run_test() {
  local desc="$1"
  shift
  log_test "${desc}"
  if "$@"; then
    log_pass "${desc}"
  else
    log_fail "${desc}"
  fi
}

# -----------------------------------------------------------------------------
log_section "通知系统集成测试 (backend: ${BACKEND})"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 测试 1: 基本消息
run_test "基本消息发送" \
  "${NOTIFY}" homelab-test "集成测试" "基本消息发送测试" default white_check_mark "${BACKEND}"

# 测试 2: 低优先级
run_test "低优先级消息" \
  "${NOTIFY}" homelab-test "低优先级测试" "这是一条低优先级消息" low information_source "${BACKEND}"

# 测试 3: 高优先级
run_test "高优先级告警" \
  "${NOTIFY}" homelab-test "高优先级测试" "这是一条高优先级告警" high warning "${BACKEND}"

# 测试 4: 紧急告警
run_test "紧急告警" \
  "${NOTIFY}" homelab-critical "紧急测试" "这是一条紧急告警 — 请忽略" urgent rotating_light "${BACKEND}"

# 测试 5: 多标签
run_test "多标签消息" \
  "${NOTIFY}" homelab-test "多标签测试" "包含多个 emoji 标签" default "tada,white_check_mark,rocket" "${BACKEND}"

# 测试 6: Watchtower 模拟
run_test "Watchtower 更新模拟" \
  "${NOTIFY}" watchtower "容器已更新" "jellyfin:latest → 10.9.0 已成功更新" default "arrow_up,package" "${BACKEND}"

# 测试 7: 备份完成模拟
run_test "备份完成通知" \
  "${NOTIFY}" backup "备份完成" "每日备份成功完成，大小: 2.3 GB，耗时: 45s" default "floppy_disk" "${BACKEND}"

# -----------------------------------------------------------------------------
log_section "测试结果摘要"
echo -e "  通过: ${GREEN}${PASS_COUNT}${NC}"
echo -e "  失败: ${RED}${FAIL_COUNT}${NC}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo -e "${GREEN}✅ 所有测试通过！通知系统运行正常。${NC}"
  exit 0
else
  echo -e "${RED}❌ 有 ${FAIL_COUNT} 个测试失败，请检查配置。${NC}"
  echo ""
  echo "常见问题排查:"
  echo "  1. 检查 .env 文件中的 NTFY_TOKEN / NTFY_USER / NTFY_PASS"
  echo "  2. 确认 ntfy/Gotify 服务正在运行: docker compose -f stacks/notifications/docker-compose.yml ps"
  echo "  3. 检查主题权限: docker exec ntfy ntfy access"
  echo "  4. 查看详细日志: docker logs ntfy --tail 30"
  exit 1
fi
