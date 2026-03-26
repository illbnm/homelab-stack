#!/usr/bin/env bash
# =============================================================================
# HomeLab Restore Script — 数据恢复脚本
# 支持: 数据库, Docker 卷, 配置文件, Restic 快照
# 用法: ./restore.sh --target <target> [选项]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RESTIC_REPO="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"

# Load env file if exists
if [[ -f "$BASE_DIR/.env" ]]; then
  set -a
  source "$BASE_DIR/.env"
  set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }
log_confirm() { echo -e "${YELLOW}[CONFIRM]${NC} $*"; }

# =============================================================================
# Usage
# =============================================================================
usage() {
  cat << EOF
用法: $(basename "$0") --target <target> [选项]

恢复目标:
  all         恢复所有内容
  databases   仅恢复数据库（PostgreSQL + MariaDB + Redis）
  volumes     仅恢复 Docker 卷
  configs     仅恢复配置文件
  restic      从 Restic 快照恢复

选项:
  --backup-id <id>    指定要恢复的备份/快照 ID
  --list              列出可用的备份/快照
  --dry-run           预览恢复内容，不实际执行
  --restore-path <p>  恢复到的目标路径（默认原位置）
  -h, --help          显示帮助信息

示例:
  $(basename "$0") --target all --backup-id 20260326_020000
  $(basename "$0") --target databases --list
  $(basename "$0") --target restic --backup-id latest
  $(basename "$0") --target restic --restore-path /tmp/restore

重要提示:
  恢复操作会覆盖现有数据！
  建议在恢复前创建当前数据的快照。

EOF
}

# =============================================================================
# Pre-flight Checks
# =============================================================================
check_prereqs() {
  log_step "检查前置条件..."

  if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    exit 1
  fi

  log_info "前置检查通过"
}

# =============================================================================
# List Available Backups
# =============================================================================
list_backups() {
  echo ""
  echo "=== 本地备份目录 ==="
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -type d -printf "%T+ %p\n" 2>/dev/null | sort -r | head -20 || echo "无备份"
  else
    echo "备份目录不存在: $BACKUP_DIR"
  fi

  echo ""
  echo "=== 本地备份文件 ==="
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.rdb" \) 2>/dev/null | \
      sed "s|$BACKUP_DIR/||" | sort -r | head -30 || echo "无备份文件"
  fi

  echo ""
  echo "=== Restic 快照 ==="
  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -n "$restic_pass" ]]; then
    if command -v restic &> /dev/null; then
      restic snapshots --repo "$RESTIC_REPO" --password "$restic_pass" 2>/dev/null || \
        echo "无法列出 Restic 快照"
    else
      # Try via docker
      docker run --rm \
        -v "$RESTIC_REPO:/repo:ro" \
        rclone/rclone:1.68.0 \
        --version &>/dev/null && {
        echo "rclone 可用但 restic 命令未安装"
      } || echo "Restic 未安装"
    fi
  else
    echo "RESTIC_PASSWORD 未设置"
  fi

  echo ""
}

# =============================================================================
# Restore Databases
# =============================================================================
restore_databases() {
  local backup_id="${1:-}"

  log_step "恢复数据库..."

  if [[ -z "$backup_id" ]]; then
    # Find latest backup
    local latest_postgres=$(find "$BACKUP_DIR" -name "postgres_*.sql.gz" 2>/dev/null | sort -r | head -1)
    local latest_maria=$(find "$BACKUP_DIR" -name "mariadb_*.sql.gz" 2>/dev/null | sort -r | head -1)
    local latest_redis=$(find "$BACKUP_DIR" -name "redis_*.rdb" 2>/dev/null | sort -r | head -1)
  else
    local latest_postgres=$(find "$BACKUP_DIR" -name "postgres_${backup_id}*.sql.gz" 2>/dev/null | sort -r | head -1)
    local latest_maria=$(find "$BACKUP_DIR" -name "mariadb_${backup_id}*.sql.gz" 2>/dev/null | sort -r | head -1)
    local latest_redis=$(find "$BACKUP_DIR" -name "redis_${backup_id}*.rdb" 2>/dev/null | sort -r | head -1)
  fi

  # Restore PostgreSQL
  if [[ -n "$latest_postgres" ]] && [[ -f "$latest_postgres" ]]; then
    log_confirm "恢复 PostgreSQL: $latest_postgres"
    local pg_container="${POSTGRES_CONTAINER:-homelab-postgres}"
    local pg_pass="${POSTGRES_ROOT_PASSWORD:-}"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${pg_container}$"; then
      gunzip -c "$latest_postgres" | docker exec -i "$pg_container" \
        psql -U "${POSTGRES_ROOT_USER:-postgres}" 2>/dev/null || {
        log_warn "PostgreSQL 恢复失败，尝试其他方式"
        gunzip -c "$latest_postgres" | docker exec -i "$pg_container" sh -c \
          "PGPASSWORD='$pg_pass' psql -U postgres" 2>/dev/null || \
          log_error "PostgreSQL 恢复失败"
      }
      log_info "PostgreSQL 恢复完成"
    else
      log_warn "PostgreSQL 容器未运行，跳过"
    fi
  else
    log_warn "未找到 PostgreSQL 备份"
  fi

  # Restore MariaDB
  if [[ -n "$latest_maria" ]] && [[ -f "$latest_maria" ]]; then
    log_confirm "恢复 MariaDB: $latest_maria"
    local maria_container="${MARIADB_CONTAINER:-homelab-mariadb}"
    local maria_pass="${MARIADB_ROOT_PASSWORD:-}"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${maria_container}$"; then
      gunzip -c "$latest_maria" | docker exec -i "$maria_container" \
        mariadb -u root -p"$maria_pass" 2>/dev/null || {
        log_warn "MariaDB 恢复失败"
      }
      log_info "MariaDB 恢复完成"
    else
      log_warn "MariaDB 容器未运行，跳过"
    fi
  else
    log_warn "未找到 MariaDB 备份"
  fi

  # Restore Redis
  if [[ -n "$latest_redis" ]] && [[ -f "$latest_redis" ]]; then
    log_confirm "恢复 Redis: $latest_redis"
    local redis_container="${REDIS_CONTAINER:-homelab-redis}"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${redis_container}$"; then
      docker cp "$latest_redis" "$redis_container:/data/dump.rdb" 2>/dev/null || {
        log_warn "Redis 恢复失败"
      }
      log_info "Redis 恢复完成（可能需要重启 Redis）"
    else
      log_warn "Redis 容器未运行，跳过"
    fi
  else
    log_warn "未找到 Redis 备份"
  fi
}

# =============================================================================
# Restore Volumes
# =============================================================================
restore_volumes() {
  local backup_id="${1:-}"
  local restore_path="${2:-}"

  log_step "恢复 Docker 卷..."

  if [[ -z "$backup_id" ]]; then
    log_error "需要指定 --backup-id"
    return 1
  fi

  if [[ -z "$restore_path" ]]; then
    log_error "需要指定 --restore-path"
    return 1
  fi

  local volume_backup=$(find "$BACKUP_DIR" -name "*${backup_id}*.tar.gz" 2>/dev/null | head -1)

  if [[ -z "$volume_backup" ]] || [[ ! -f "$volume_backup" ]]; then
    log_error "未找到卷备份: $backup_id"
    return 1
  fi

  log_confirm "恢复卷: $volume_backup -> $restore_path"

  # Extract to temp location first
  local temp_dir="/tmp/homelab-restore-$$"
  mkdir -p "$temp_dir"

  tar xzf "$volume_backup" -C "$temp_dir" 2>/dev/null || {
    log_error "卷备份解压失败"
    rm -rf "$temp_dir"
    return 1
  }

  # Get the first item from the archive (volume name)
  local vol_name=$(tar tzf "$volume_backup" 2>/dev/null | head -1 | cut -d/ -f2)
  if [[ -n "$vol_name" ]]; then
    docker volume create "$vol_name" 2>/dev/null || true

    docker run --rm \
      -v "$vol_name:/data:rw" \
      -v "$temp_dir:/backup:ro" \
      alpine:3.19 \
      sh -c "rm -rf /data/* && tar xzf /backup/*.tar.gz -C /data" 2>/dev/null || {
      log_error "卷恢复失败"
    }

    log_info "卷 $vol_name 恢复完成"
  fi

  rm -rf "$temp_dir"
}

# =============================================================================
# Restore Configs
# =============================================================================
restore_configs() {
  local backup_id="${1:-}"

  log_step "恢复配置文件..."

  if [[ -z "$backup_id" ]]; then
    local latest_config=$(find "$BACKUP_DIR" -name "configs_*.tar.gz" 2>/dev/null | sort -r | head -1)
  else
    local latest_config=$(find "$BACKUP_DIR" -name "configs_${backup_id}*.tar.gz" 2>/dev/null | sort -r | head -1)
  fi

  if [[ -z "$latest_config" ]] || [[ ! -f "$latest_config" ]]; then
    log_error "未找到配置文件备份"
    return 1
  fi

  log_confirm "恢复配置文件: $latest_config"
  log_warn "此操作会覆盖现有配置文件！"

  tar xzf "$latest_config" -C "$BASE_DIR" 2>/dev/null || {
    log_error "配置文件恢复失败"
    return 1
  }

  log_info "配置文件恢复完成"
}

# =============================================================================
# Restore from Restic
# =============================================================================
restore_restic() {
  local snapshot_id="${1:-latest}"
  local restore_path="${2:-/tmp/homelab-restic-restore}"

  log_step "从 Restic 快照恢复..."

  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -z "$restic_pass" ]]; then
    log_error "RESTIC_PASSWORD 未设置"
    return 1
  fi

  # Create restore directory
  mkdir -p "$restore_path"

  # Try using restic directly
  if command -v restic &> /dev/null; then
    log_info "使用 Restic 恢复快照: $snapshot_id"

    restic restore "$snapshot_id" \
      --repo "$RESTIC_REPO" \
      --password "$restic_pass" \
      --target "$restore_path" 2>/dev/null || {
      log_error "Restic 恢复失败"
      return 1
    }

    log_info "快照恢复完成: $restore_path"
    log_info "恢复的文件:"
    ls -la "$restore_path" 2>/dev/null || true

  else
    # Fallback: try via docker
    log_warn "Restic 命令未安装，尝试通过 Docker 运行"

    docker run --rm \
      -v "$RESTIC_REPO:/repo:ro" \
      -v "$restore_path:/restore:rw" \
      alpine:3.19 \
      sh -c "apk add --no-cache restic && restic restore '$snapshot_id' --repo /repo --password '$restic_pass' --target /restore" 2>/dev/null || {
      log_error "Restic Docker 恢复失败"
      return 1
    }

    log_info "快照恢复完成: $restore_path"
  fi
}

# =============================================================================
# Interactive Restore
# =============================================================================
interactive_restore() {
  echo ""
  echo "=== HomeLab 交互式恢复 ==="
  echo ""

  echo "可用的恢复目标:"
  echo "  1. 所有内容 (all)"
  echo "  2. 数据库 (databases)"
  echo "  3. Docker 卷 (volumes)"
  echo "  4. 配置文件 (configs)"
  echo "  5. Restic 快照 (restic)"
  echo "  6. 退出"
  echo ""

  read -p "请选择恢复目标 [1-6]: " choice

  case "$choice" in
    1) target="all" ;;
    2) target="databases" ;;
    3) target="volumes" ;;
    4) target="configs" ;;
    5) target="restic" ;;
    6) echo "退出"; exit 0 ;;
    *) log_error "无效选择"; exit 1 ;;
  esac

  echo ""
  echo "=== 可用的备份/快照 ==="
  list_backups

  read -p "请输入备份 ID 或快照 ID (留空使用最新): " backup_id

  if [[ "$target" == "volumes" ]]; then
    read -p "请输入要恢复的卷名称: " volume_name
    read -p "请输入恢复路径: " restore_path
    restore_volumes "$backup_id" "$restore_path"
  elif [[ "$target" == "restic" ]]; then
    read -p "请输入恢复目录 [默认: /tmp/homelab-restic-restore]: " restore_path
    restore_path="${restore_path:-/tmp/homelab-restic-restore}"
    restore_restic "$backup_id" "$restore_path"
  else
    "restore_${target}" "$backup_id"
  fi
}

# =============================================================================
# Dry Run
# =============================================================================
dry_run() {
  echo ""
  echo "=== 恢复预览 (DRY RUN) ==="
  echo ""

  echo "备份目录: $BACKUP_DIR"
  echo "Restic 仓库: $RESTIC_REPO"
  echo ""

  echo "--- 将恢复的数据库 ---"
  find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.rdb" 2>/dev/null | head -5 && echo "  ✓ 将恢复数据库文件"
  echo ""

  echo "--- 将恢复的卷 ---"
  find "$BACKUP_DIR" -name "vol_*.tar.gz" 2>/dev/null | head -5 && echo "  ✓ 将恢复卷"
  echo ""

  echo "--- 将恢复的配置 ---"
  find "$BACKUP_DIR" -name "configs_*.tar.gz" 2>/dev/null | head -5 && echo "  ✓ 将恢复配置文件"
  echo ""

  echo ""
  echo "实际执行请去掉 --dry-run 参数"
  echo ""
}

# =============================================================================
# Main
# =============================================================================
main() {
  local target=""
  local backup_id=""
  local restore_path=""
  local dry_run_flag=false
  local list_flag=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        target="$2"; shift 2 ;;
      --backup-id)
        backup_id="$2"; shift 2 ;;
      --restore-path)
        restore_path="$2"; shift 2 ;;
      --dry-run)
        dry_run_flag=true; shift ;;
      --list)
        list_flag=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        log_error "未知参数: $1"; usage; exit 1 ;;
    esac
  done

  # Handle special modes
  case "true" in
    $list_flag)
      list_backups
      exit 0
      ;;
    $dry_run_flag)
      dry_run
      exit 0
      ;;
  esac

  # Interactive if no target
  if [[ -z "$target" ]]; then
    interactive_restore
    exit 0
  fi

  # Run restore
  log_info "=========================================="
  log_info "HomeLab Restore — $target"
  log_info "备份 ID: ${backup_id:-latest}"
  log_info "=========================================="

  check_prereqs

  case "$target" in
    all)
      restore_databases "$backup_id"
      restore_configs "$backup_id"
      ;;
    databases)
      restore_databases "$backup_id"
      ;;
    volumes)
      restore_volumes "$backup_id" "$restore_path"
      ;;
    configs)
      restore_configs "$backup_id"
      ;;
    restic)
      restore_restic "$backup_id" "$restore_path"
      ;;
    *)
      log_error "未知恢复目标: $target"
      usage
      exit 1
      ;;
  esac

  echo ""
  log_info "=========================================="
  log_info "恢复完成"
  log_info "=========================================="
  echo ""
  log_warn "重要: 某些服务可能需要重启以加载恢复的数据"
  echo ""
}

main "$@"
