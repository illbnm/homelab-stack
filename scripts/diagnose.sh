#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Diagnose
# 一键诊断：收集 Docker/系统/容器/网络/配置 状态
# 对应 Issue #8 [BOUNTY $250] Robustness — 环境鲁棒性
# 用法: scripts/diagnose.sh [--output <file>] [--stack <name>]
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[diagnose]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[diagnose]${NC} $*"; }
log_error() { echo -e "${RED}[diagnose]${NC} $*" >&2; }

OUTPUT=""
STACK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    --stack) STACK="$2"; shift 2 ;;
    *) log_warn "未知参数: $1"; shift ;;
  esac
done

# 若指定输出文件，重定向全部输出
if [[ -n "$OUTPUT" ]]; then
  exec > >(tee "$OUTPUT") 2>&1
  log_info "诊断报告写入: $OUTPUT"
fi

log_info "========== HomeLab Stack 一键诊断 =========="
log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 1. Docker 版本
echo ""
echo -e "${BLUE}== Docker 版本 ==${NC}"
if command -v docker &>/dev/null; then
  docker --version 2>&1 || log_warn "docker 版本获取失败"
  docker compose version 2>&1 || log_warn "docker compose 版本获取失败"
else
  log_error "docker 未安装"
fi

# 2. 系统信息
echo ""
echo -e "${BLUE}== 系统信息 ==${NC}"
echo "  OS: $(uname -s) $(uname -r) $(uname -m)"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo "  发行版: ${PRETTY_NAME:-未知}"
fi
echo "  内存: $(free -h 2>/dev/null | awk '/Mem/{print $2" 总量 / "$3" 已用"}')"
echo "  磁盘: $(df -h / 2>/dev/null | awk 'NR==2{print $2" 总量 / "$3" 已用 / "$4" 可用 / 使用率 "$5}')"

# 3. 所有容器状态
echo ""
echo -e "${BLUE}== 容器状态 ==${NC}"
if command -v docker &>/dev/null; then
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>&1 | head -30
else
  log_error "docker 未安装，无法查容器"
fi

# 4. 近期错误日志（docker events 或 journalctl）
echo ""
echo -e "${BLUE}== 近期错误日志 (最后 20 行) ==${NC}"
if command -v journalctl &>/dev/null; then
  journalctl -u docker --since "1 hour ago" 2>/dev/null | grep -iE "error|fail" | tail -20 || echo "  (无错误或 journalctl 受限)"
else
  docker events --since 1h 2>/dev/null | grep -iE "die|error|oom" | tail -20 || echo "  (无事件或 docker events 受限)"
fi

# 5. 网络连通性
echo ""
echo -e "${BLUE}== 网络连通性 ==${NC}"
if [[ -f "scripts/check-connectivity.sh" ]]; then
  bash scripts/check-connectivity.sh 2>&1 || true
else
  log_warn "scripts/check-connectivity.sh 不存在，跳过网络检测"
fi

# 6. 配置文件校验
echo ""
echo -e "${BLUE}== 配置文件校验 ==${NC}"
if [[ -f ".env" ]]; then
  # 校验 .env 是否有未赋值变量
  UNASSIGNED=$(grep -E "^[A-Z_]+=" .env | grep -E "=$" | wc -l)
  if [[ "$UNASSIGNED" -gt 0 ]]; then
    log_warn ".env 有 $UNASSIGNED 个空值变量（需检查）"
  else
    log_info ".env 校验通过（无空值变量）"
  fi
else
  log_warn ".env 不存在（未初始化）"
fi

# 7. Docker daemon 配置
echo ""
echo -e "${BLUE}== Docker daemon 配置 ==${NC}"
if [[ -f /etc/docker/daemon.json ]]; then
  cat /etc/docker/daemon.json 2>&1 | head -20
else
  log_warn "无 /etc/docker/daemon.json（未配置镜像加速）"
fi

log_info ""
log_info "========== 诊断完成 =========="
