#!/usr/bin/env bash
# =============================================================================
# Image Localization Script
# Replaces gcr.io/ghcr.io images with CN mirrors in compose files
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
STACKS_DIR="$SCRIPT_DIR/../stacks"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Registry replacement rules
replace_registry() {
  local content=$1

  # Replace gcr.io → gcr.m.daocloud.io
  content="${content//gcr\.io\//gcr.m.daocloud.io/}"

  # Replace ghcr.io → ghcr.m.daocloud.io
  content="${content//ghcr\.io\//ghcr.m.daocloud.io/}"

  # Replace k8s.gcr.io → Aliyun mirror
  content="${content//k8s\.gcr\.io\//registry.cn-hangzhou.aliyuncs.com\/google_containers/}"

  # Replace quay.io → quay.m.daocloud.io
  content="${content//quay\.io\//quay.m.daocloud.io/}"

  echo "$content"
}

find_compose_files() {
  find "$STACKS_DIR" -type f \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) 2>/dev/null
}

check_needs_replacement() {
  local file=$1
  grep -qE 'gcr\.io|ghcr\.io|k8s\.gcr\.io|quay\.io' "$file" 2>/dev/null
}

action_check() {
  log_info "检查镜像源..."
  local found=0

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if check_needs_replacement "$file"; then
      log_warn "发现需要替换的镜像: $file"
      grep -E 'image:.*gcr\.io|image:.*ghcr\.io|image:.*k8s\.gcr\.io|image:.*quay\.io' "$file" || true
      ((found++)) || true
    fi
  done < <(find_compose_files)

  if [[ $found -gt 0 ]]; then
    echo -e "\n${YELLOW}检测到 $found 个文件需要镜像替换${NC}"
    echo "运行: $0 --cn 进行替换"
    exit 1
  else
    log_info "所有镜像已使用国内源 ✓"
    exit 0
  fi
}

action_dry_run() {
  log_info "预览镜像替换 (dry-run)..."

  while IFS= read -r file; do
    [[ -z "$file" ]] || [[ ! -f "$file" ]] && continue

    if check_needs_replacement "$file"; then
      echo -e "\n${BOLD}文件: $file${NC}"
      local original changed
      original=$(cat "$file")
      changed=$(replace_registry "$original")

      if [[ "$original" != "$changed" ]]; then
        echo "将会替换:"
        diff -u <(echo "$original") <(echo "$changed") || true
      fi
    fi
  done < <(find_compose_files)

  log_info "预览完成，未修改任何文件"
}

action_cn() {
  log_info "替换为国内镜像..."
  local replaced=0

  while IFS= read -r file; do
    [[ -z "$file" ]] || [[ ! -f "$file" ]] && continue

    if check_needs_replacement "$file"; then
      log_info "处理: $file"

      # Backup
      cp "$file" "${file}.bak"

      # Replace
      local content
      content=$(cat "$file")
      content=$(replace_registry "$content")
      echo "$content" > "$file"

      log_info "✓ 已替换并备份到: ${file}.bak"
      ((replaced++)) || true
    fi
  done < <(find_compose_files)

  if [[ $replaced -eq 0 ]]; then
    log_info "没有需要替换的文件"
  else
    log_info "镜像替换完成 ✓ (共 $replaced 个文件)"
  fi
}

action_restore() {
  log_info "恢复原始镜像..."
  local restored=0

  while IFS= read -r bak_file; do
    [[ -z "$bak_file" ]] && continue

    local original_file="${bak_file%.bak}"
    if [[ -f "$bak_file" ]]; then
      mv "$bak_file" "$original_file"
      log_info "✓ 已恢复: $original_file"
      ((restored++)) || true
    fi
  done < <(find "$STACKS_DIR" -name "*.bak" 2>/dev/null)

  if [[ $restored -eq 0 ]]; then
    log_info "没有需要恢复的文件"
  else
    log_info "恢复完成 ✓ (共 $restored 个文件)"
  fi
}

usage() {
  cat <<EOF
用法:
  $0 --cn        替换为国内镜像
  $0 --restore   恢复原始镜像
  $0 --dry-run   预览变更不实际修改
  $0 --check     检测当前是否需要替换
  $0 --help      显示此帮助信息

示例:
  $0 --check
  $0 --dry-run
  $0 --cn
  $0 --restore
EOF
  exit 0
}

# Parse arguments
case "${1:-}" in
  --cn)
    action_cn
    ;;
  --restore)
    action_restore
    ;;
  --dry-run)
    action_dry_run
    ;;
  --check)
    action_check
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage
    ;;
esac
