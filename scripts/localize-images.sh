#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — 将 compose 文件中的 gcr.io/ghcr.io 替换为国内镜像
#
# Usage:
#   ./scripts/localize-images.sh --cn       替换为国内镜像
#   ./scripts/localize-images.sh --restore  恢复原始镜像
#   ./scripts/localize-images.sh --dry-run  预览变更
#   ./scripts/localize-images.sh --check    检测是否需要替换
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
MIRROR_MAP="${PROJECT_DIR}/config/cn-mirrors.yml"
BACKUP_DIR="${PROJECT_DIR}/.image-backup"

log()  { echo "[localize] $*"; }
ok()   { echo "[localize] ✅ $*"; }

# ── Mirror mappings ──────────────────────────────────────────────────────────

declare -A MIRRORS=(
  ["gcr.io/"]="m.daocloud.io/gcr.io/"
  ["ghcr.io/"]="m.daocloud.io/ghcr.io/"
  ["quay.io/"]="m.daocloud.io/quay.io/"
  ["registry.k8s.io/"]="m.daocloud.io/registry.k8s.io/"
)

find_compose_files() {
  find "${PROJECT_DIR}/stacks" -name "docker-compose.yml" -type f
}

do_check() {
  log "检测需要替换的镜像..."
  local count=0
  while IFS= read -r file; do
    for prefix in "${!MIRRORS[@]}"; do
      if grep -q "image:.*${prefix}" "$file" 2>/dev/null; then
        local matches=$(grep "image:.*${prefix}" "$file" | sed 's/^[[:space:]]*//')
        echo "  ${file}: ${matches}"
        ((count++))
      fi
    done
  done < <(find_compose_files)

  if [[ $count -eq 0 ]]; then
    ok "所有镜像已是国内源或无需替换"
  else
    log "发现 ${count} 个需要替换的镜像"
    log "运行 ./scripts/localize-images.sh --cn 进行替换"
  fi
}

do_cn() {
  log "替换为国内镜像..."
  mkdir -p "$BACKUP_DIR"

  while IFS= read -r file; do
    local relpath="${file#${PROJECT_DIR}/}"
    local backup="${BACKUP_DIR}/${relpath//\//_}"

    # Backup original
    cp "$file" "$backup"

    for prefix in "${!MIRRORS[@]}"; do
      local replacement="${MIRRORS[$prefix]}"
      if grep -q "${prefix}" "$file"; then
        sed -i "s|${prefix}|${replacement}|g" "$file"
        ok "${relpath}: ${prefix} → ${replacement}"
      fi
    done
  done < <(find_compose_files)

  ok "替换完成！备份在 ${BACKUP_DIR}/"
}

do_restore() {
  log "恢复原始镜像..."

  if [[ ! -d "$BACKUP_DIR" ]]; then
    log "无备份文件，无需恢复"
    return 0
  fi

  while IFS= read -r file; do
    local relpath="${file#${PROJECT_DIR}/}"
    local backup="${BACKUP_DIR}/${relpath//\//_}"

    if [[ -f "$backup" ]]; then
      cp "$backup" "$file"
      ok "恢复: ${relpath}"
    fi
  done < <(find_compose_files)

  rm -rf "$BACKUP_DIR"
  ok "恢复完成！"
}

do_dry_run() {
  log "[DRY-RUN] 预览变更（不实际修改）..."

  while IFS= read -r file; do
    local relpath="${file#${PROJECT_DIR}/}"
    for prefix in "${!MIRRORS[@]}"; do
      local replacement="${MIRRORS[$prefix]}"
      if grep -q "${prefix}" "$file"; then
        grep "${prefix}" "$file" | while read -r line; do
          local trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
          local new=$(echo "$trimmed" | sed "s|${prefix}|${replacement}|g")
          echo "  ${relpath}:"
          echo "    - ${trimmed}"
          echo "    + ${new}"
        done
      fi
    done
  done < <(find_compose_files)
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  --cn)      do_cn ;;
  --restore) do_restore ;;
  --dry-run) do_dry_run ;;
  --check)   do_check ;;
  *)
    echo "Usage: $0 {--cn|--restore|--dry-run|--check}"
    echo ""
    echo "  --cn       替换为国内镜像"
    echo "  --restore  恢复原始镜像"
    echo "  --dry-run  预览变更不实际修改"
    echo "  --check    检测当前是否需要替换"
    exit 1
    ;;
esac
