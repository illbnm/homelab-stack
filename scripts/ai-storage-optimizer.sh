#!/bin/bash
# =============================================================================
# HomeLab AI Storage Optimizer
# Cleans up temporary files, unused models, and Docker resources.
# Usage: ./ai-storage-optimizer.sh [--dry-run]
# =============================================================================
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Colors
RED=''; GREEN=''; YELLOW=''; RESET=''
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }

run_or_dry() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

log_info "=== AI Storage Optimizer ==="
$DRY_RUN && log_warn "DRY RUN 模式 - 不会实际删除"

echo ""
log_info "1. 清理 Docker 系统..."
run_or_dry "docker system prune -f --volumes 2>/dev/null || true"

echo ""
log_info "2. 清理 Ollama 临时文件 (>7天)..."
run_or_dry "docker exec ollama find /tmp -type f -mtime +7 -delete 2>/dev/null || true"

echo ""
log_info "3. 清理 Open WebUI 临时文件 (>7天)..."
run_or_dry "docker exec open-webui find /tmp -type f -mtime +7 -delete 2>/dev/null || true"

echo ""
log_info "4. 清理 Stable Diffusion 输出 (>30天)..."
run_or_dry "docker exec stable-diffusion find /app/outputs -type f -mtime +30 -delete 2>/dev/null || true"

echo ""
log_info "5. 清理未使用的 Docker 镜像..."
run_or_dry "docker image prune -f 2>/dev/null || true"

echo ""
log_info "6. 清理构建缓存..."
run_or_dry "docker builder prune -f 2>/dev/null || true"

echo ""
log_info "=== 清理完成 ==="
echo ""
log_info "当前存储使用:"
docker system df -v | grep -E "(ollama|webui|sd|perplexica|SIZE)" || true
