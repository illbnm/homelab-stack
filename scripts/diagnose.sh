#!/usr/bin/env bash
# diagnose.sh — One-click diagnostic report for homelab stack
# Usage: ./scripts/diagnose.sh [--output diagnose-report.txt]
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

OUTPUT=""
if [[ "${1:-}" == "--output" ]]; then
  OUTPUT="${2:-diagnose-report.txt}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPORT_FILE=$(mktemp)
trap 'rm -f "$REPORT_FILE"' EXIT

log() { echo -e "$*" | tee -a "$REPORT_FILE"; }
header() {
  log ""
  log "${BOLD}$1${RESET}"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

echo ""
echo -e "${BOLD}🔍 Homelab Stack 诊断报告${RESET}"
echo -e "   生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ═══ 1. Docker 版本 ═══
header "🐳 Docker 版本"
if command -v docker &>/dev/null; then
  log "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'Docker 未运行')"
  docker info --format '  OS: {{.OperatingSystem}}
  Storage Driver: {{.Driver}}
  CPUs: {{.NCPU}}
  Memory: {{.MemTotal}}' >> "$REPORT_FILE" 2>/dev/null || true
else
  log "${RED}Docker 未安装${RESET}"
fi

# ═══ 2. 系统信息 ═══
header "💻 系统信息"
if [[ -f /etc/os-release ]]; then
  log "  OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
fi
log "  内核: $(uname -r)"
log "  主机名: $(hostname)"

if command -v free &>/dev/null; then
  log "  内存:"
  free -h | tee -a "$REPORT_FILE"
elif [[ -f /proc/meminfo ]]; then
  log "  内存: $(grep MemTotal /proc/meminfo | awk '{print $2/1024/1024 " GB"}')"
fi

log ""
log "  磁盘:"
if command -v df &>/dev/null; then
  df -h / /var/lib/docker 2>/dev/null | tee -a "$REPORT_FILE" || df -h / | tee -a "$REPORT_FILE"
fi

# ═══ 3. 容器状态 ═══
header "📦 容器状态"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  log "  ${BOLD}所有容器:${RESET}"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | tee -a "$REPORT_FILE"

  log ""
  log "  ${BOLD}异常容器:${RESET}"
  unhealthy=$(docker ps -a --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null || true)
  stopped=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null || true)

  if [[ -n "$unhealthy" ]]; then
    log "  ${RED}不健康:${RESET} $unhealthy"
  fi
  if [[ -n "$stopped" ]]; then
    log "  ${YELLOW}已停止:${RESET} $stopped"
  fi
  if [[ -z "$unhealthy" && -z "$stopped" ]]; then
    log "  ${GREEN}✅ 所有容器正常${RESET}"
  fi
else
  log "${RED}Docker 不可用${RESET}"
fi

# ═══ 4. 近期错误日志 ═══
header "📝 近期错误日志"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)
  error_found=false
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    errors=$(docker logs --tail 100 "$container" 2>&1 | grep -iE "error|fatal|panic|exception|fail" | tail -5 || true)
    if [[ -n "$errors" ]]; then
      error_found=true
      log "  ${RED}── ${container} ──${RESET}"
      echo "$errors" | while IFS= read -r line; do
        log "    $line"
      done
      log ""
    fi
  done <<< "$containers"

  if ! $error_found; then
    log "  ${GREEN}✅ 未发现近期错误${RESET}"
  fi
else
  log "  Docker 不可用，跳过"
fi

# ═══ 5. 网络连通性 ═══
header "🌐 网络连通性"
if [[ -f "$SCRIPT_DIR/check-connectivity.sh" ]]; then
  log "  运行 check-connectivity.sh..."
  connectivity_output=$("$SCRIPT_DIR/check-connectivity.sh" 2>&1 || true)
  echo "$connectivity_output" >> "$REPORT_FILE"
  fail_count=$(echo "$connectivity_output" | grep -c '\[FAIL\]' || true)
  slow_count=$(echo "$connectivity_output" | grep -c '\[SLOW\]' || true)
  if [[ $fail_count -gt 0 ]]; then
    log "  ${RED}⚠️  ${fail_count} 个不可达，${slow_count} 个慢连接${RESET}"
  elif [[ $slow_count -gt 0 ]]; then
    log "  ${YELLOW}⚠️  ${slow_count} 个慢连接${RESET}"
  else
    log "  ${GREEN}✅ 全部可达${RESET}"
  fi
else
  log "  ${YELLOW}check-connectivity.sh 不存在，跳过${RESET}"
  log "  手动检查核心端点..."
  for host in hub.docker.com github.com gcr.io ghcr.io; do
    if curl --connect-timeout 5 -s -o /dev/null "https://$host/" 2>/dev/null; then
      log "  ${GREEN}[OK]${RESET}   $host"
    else
      log "  ${RED}[FAIL]${RESET} $host"
    fi
  done
fi

# ═══ 6. 配置文件校验 ═══
header "⚙️  配置文件校验"
compose_errors=0

while IFS= read -r compose_file; do
  [[ -z "$compose_file" ]] && continue
  normalized=$(echo "$compose_file" | tr '\\' '/')
  if docker compose -f "$normalized" config -q 2>/dev/null; then
    log "  ${GREEN}✓${RESET} $(basename "$normalized")"
  else
    log "  ${RED}✗${RESET} $(basename "$normalized") — 校验失败"
    compose_errors=$((compose_errors + 1))
  fi
done < <(find "$REPO_ROOT/stacks" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)

while IFS= read -r env_file; do
  [[ -z "$env_file" ]] && continue
  if [[ -f "$env_file" ]]; then
    log "  ${GREEN}✓${RESET} $(basename "$(dirname "$env_file")")/.env"
  else
    log "  ${YELLOW}⚠${RESET} $(basename "$(dirname "$env_file")")/.env (missing)"
  fi
done < <(find "$REPO_ROOT/stacks" -name ".env" 2>/dev/null)

if [[ $compose_errors -eq 0 ]]; then
  log "  ${GREEN}✅ 所有配置文件校验通过${RESET}"
fi

# ═══ 汇总 ═══
header "📊 汇总"
total_containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l || echo 0)
running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l || echo 0)
log "  容器总数: $total_containers | 运行中: $running_containers"
log "  报告时间: $(date '+%Y-%m-%d %H:%M:%S')"

if [[ -n "$OUTPUT" ]]; then
  sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g' "$REPORT_FILE" > "$OUTPUT"
  echo ""
  echo -e "${GREEN}${BOLD}📄 报告已写入: ${OUTPUT}${RESET}"
  echo ""
else
  cat "$REPORT_FILE"
fi
