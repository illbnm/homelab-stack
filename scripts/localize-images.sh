#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# localize-images.sh — 镜像替换/恢复工具
#
# 用法:
#   ./localize-images.sh --cn        # 替换为国内镜像
#   ./localize-images.sh --restore   # 恢复原始镜像
#   ./localize-images.sh --dry-run   # 预览变更
#   ./localize-images.sh --check     # 检测当前状态
#
# 功能:
# - 扫描所有 docker-compose.yml 文件
# - 替换 gcr.io/ghcr.io 等为国内镜像
# - 维护 .images.original 备份文件
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 配置
MIRROR_MAP="/Users/apple/.openclaw/workspace/homelab-bounty/config/cn-mirrors.yml"
STACKS_DIR="/Users/apple/.openclaw/workspace/homelab-bounty/stacks"

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

log() {
  echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

success() {
  echo -e "${GREEN}[OK]${NC} $*"
}

# 加载镜像映射
load_mirror_map() {
  if [[ ! -f "$MIRROR_MAP" ]]; then
    error "镜像映射文件不存在: $MIRROR_MAP"
  fi

  # 解析 YAML，提取 mirrors 映射
  # 使用 yq 或 python
  if command -v yq &>/dev/null; then
    yq eval '.mirrors | to_entries | .[] | "\(.key)=\(.value)"' "$MIRROR_MAP"
  elif command -v python3 &>/dev/null; then
    python3 -c "
import yaml, sys
with open('$MIRROR_MAP') as f:
  data = yaml.safe_load(f)
  for k, v in data.get('mirrors', {}).items():
    print(f'{k}={v}')
"
  else
    error "需要 yq 或 python3 来解析 YAML"
  fi
}

# 备份文件
backup_file() {
  local file="$1"
  if [[ ! -f "${file}.images.original" ]]; then
    cp "$file" "${file}.images.original"
    log "已备份: $file → ${file}.images.original"
  fi
}

# ═════════════════════════════════════════════.yml

check_mode() {
  log "检查当前镜像状态..."
  echo

  local total_changes=0
  local need_change=0

  # 加载镜像映射
  declare -A mirror_map
  while IFS='=' read -r orig mirror; do
    mirror_map["$orig"]="$mirror"
  done < <(load_mirror_map)

  # 扫描所有 compose 文件
  while IFS= read -r file; do
    echo -e "${BLUE}检查: $file${NC}"
    local file_changes=0

    for orig in "${!mirror_map[@]}"; do
      if grep -q "image: *${orig}" "$file"; then
        local count=$(grep -c "image: *${orig}" "$file")
        echo -e "  ⚠️  发现需要替换的镜像: $orig → ${mirror_map[$orig]} (${count} 处)"
        ((file_changes++))
        ((need_change++))
      fi
    done

    if [[ $file_changes -eq 0 ]]; then
      echo -e "  ✅ 无需要替换的镜像"
    fi
    ((total_changes++))
  done < <(find "$STACKS_DIR" -name 'docker-compose.yml' -type f)

  echo
  log "总结: 扫描了 $total_changes 个 compose 文件"
  if [[ $need_change -gt 0 ]]; then
    warn "发现 $need_change 个文件需要替换镜像"
    echo "运行: $0 --cn 进行替换"
    return 1
  else
    success "所有镜像已经是国内源或无需替换"
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 替换模式
# ═══════════════════════════════════════════════════════════════════════════

cn_mode() {
  log "替换为国内镜像..."
  echo

  # 加载镜像映射
  declare -A mirror_map
  while IFS='=' read -r orig mirror; do
    mirror_map["$orig"]="$mirror"
  done < <(load_mirror_map)

  local total_files=0
  local changed_files=0

  # 扫描所有 compose 文件
  while IFS= read -r file; do
    echo -e "${BLUE}处理: $file${NC}"
    local file_changed=false
    backup_file "$file"

    # 对每个镜像进行替换
    for orig in "${!mirror_map[@]}"; do
      if grep -q "image: *${orig}" "$file"; then
        local count=$(grep -c "image: *${orig}" "$file")
        sed -i "" "s|image: *${orig}|image: ${mirror_map[$orig]}|g" "$file" 2>/dev/null || \
        sed -i "s|image: *${orig}|image: ${mirror_map[$orig]}|g" "$file"
        echo -e "  ✅ 替换: $orig → ${mirror_map[$orig]} (${count} 处)"
        file_changed=true
      fi
    done

    if $file_changed; then
      ((changed_files++))
      success "文件已更新"
    else
      echo "  无变化"
    fi
    ((total_files++))
  done < <(find "$STACKS_DIR" -name 'docker-compose.yml' -type f)

  echo
  success "完成！已处理 $total_files 个文件，修改了 $changed_files 个文件"
  log "原始备份保存在 *.images.original"
  echo "如需恢复，运行: $0 --restore"
}

# ═══════════════════════════════════════════════════════════════════════════
# 恢复模式
# ═══════════════════════════════════════════════════════════════════════════

restore_mode() {
  log "恢复原始镜像配置..."
  echo

  local total_files=0
  local restored_files=0

  while IFS= read -r file; do
    echo -e "${BLUE}恢复: $file${NC}"
    local backup="${file}.images.original"

    if [[ -f "$backup" ]]; then
      cp "$backup" "$file"
      success "已恢复备份"
      ((restored_files++))
    else
      warn "未找到备份文件，跳过"
    fi
    ((total_files++))
  done < <(find "$STACKS_DIR" -name 'docker-compose.yml' -type f)

  echo
  success "完成！已恢复 $restored_files/$total_files 个文件"
}

# ═══════════════════════════════════════════════════════════════════════════
# Dry-run 模式
# ═══════════════════════════════════════════════════════════════════════════

dry_run_mode() {
  log "预览模式 - 不会实际修改文件"
  echo

  # 加载镜像映射
  declare -A mirror_map
  while IFS='=' read -r orig mirror; do
    mirror_map["$orig"]="$mirror"
  done < <(load_mirror_map)

  local total_changes=0

  while IFS= read -r file; do
    echo -e "${BLUE}=== $file ===${NC}"
    local file_has_changes=false

    for orig in "${!mirror_map[@]}"; do
      if grep -q "image: *${orig}" "$file"; then
        local count=$(grep -c "image: *${orig}" "$file")
        echo -e "  ${YELLOW}将替换:${NC} $orig → ${mirror_map[$orig]} (${count} 处)"
        file_has_changes=true
        ((total_changes++))
      fi
    done

    if ! $file_has_changes; then
      echo "  无需修改"
    fi
    echo
  done < <(find "$STACKS_DIR" -name 'docker-compose.yml' -type f)

  echo "──────────────────────────────────────"
  log "总计发现 $total_changes 处替换"
  echo "运行 '$0 --cn' 执行替换"
}

# ═══════════════════════════════════════════════════════════════════════════
# 主逻辑
# ═══════════════════════════════════════════════════════════════════════════

show_help() {
  cat <<EOF
镜像替换工具 — 将 Docker 镜像替换为国内源

用法: $0 [OPTION]

选项:
  --cn          替换为国内镜像 (默认 DaoCloud)
  --restore     恢复原始镜像 (从备份)
  --dry-run     预览变更，不修改文件
  --check       检查当前镜像状态
  --help        显示此帮助

示例:
  $0 --check          # 检查哪些文件需要替换
  $0 --dry-run        # 预览将发生什么
  $0 --cn             # 执行替换
  $0 --restore        # 恢复原始配置

注意:
  - 此脚本会修改 stacks/ 下所有 docker-compose.yml 文件
  - 替换前自动创建 .images.original 备份
  - 镜像映射表位于 config/cn-mirrors.yml

EOF
}

main() {
  case "${1:-}" in
    --cn)
      cn_mode
      ;;
    --restore)
      restore_mode
      ;;
    --dry-run)
      dry_run_mode
      ;;
    --check)
      check_mode
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    "")
      error "缺少选项，使用 --help 查看用法"
      ;;
    *)
      error "未知选项: $1"
      ;;
  esac
}

main "$@"