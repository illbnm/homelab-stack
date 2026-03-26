#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script — 全量备份脚本
# 支持: PostgreSQL, MariaDB, Redis, Docker 卷, 配置文件
# 用法: ./backup.sh --target <all|databases|volumes|configs> [选项]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
RETENTION_WEEKS="${RETENTION_WEEKS:-12}"
RETENTION_MONTHS="${RETENTION_MONTHS:-12}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

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

# =============================================================================
# Usage
# =============================================================================
usage() {
  cat << EOF
用法: $(basename "$0") --target <target> [选项]

备份目标:
  all         备份所有内容（数据库 + 卷 + 配置）
  databases   仅备份数据库（PostgreSQL + MariaDB + Redis）
  volumes     仅备份 Docker 卷
  configs     仅备份配置文件
  restic      使用 Restic 备份（增量快照）
  rclone      同步到云存储

选项:
  --dry-run       预览要备份的内容，不实际执行
  --list          列出所有备份
  --verify        验证备份完整性
  --compress      压缩备份文件（默认启用）
  --encrypt       加密备份（需要配置 Duplicati）
  -h, --help      显示帮助信息

示例:
  $(basename "$0") --target all
  $(basename "$0") --target databases --dry-run
  $(basename "$0") --target restic
  $(basename "$0") --list
  $(basename "$0") --verify

EOF
}

# =============================================================================
# Pre-flight Checks
# =============================================================================
check_prereqs() {
  log_step "检查前置条件..."

  # Check docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    exit 1
  fi

  # Check docker compose
  if ! docker compose version &> /dev/null; then
    log_error "Docker Compose 未安装或版本过旧"
    exit 1
  fi

  # Create backup dir
  mkdir -p "$BACKUP_PATH"/{sql/postgres,sql/mariadb,volumes,configs}

  log_info "前置检查通过"
}

# =============================================================================
# Database Backup Functions
# =============================================================================
backup_postgres() {
  log_step "备份 PostgreSQL..."

  local pg_container="${POSTGRES_CONTAINER:-homelab-postgres}"
  local pg_user="${POSTGRES_ROOT_USER:-postgres}"
  local pg_pass="${POSTGRES_ROOT_PASSWORD:-}"
  local output_file="$BACKUP_PATH/sql/postgres/postgres_${TIMESTAMP}.sql.gz"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${pg_container}$"; then
    if [[ -n "$pg_pass" ]]; then
      docker exec "$pg_container" \
        sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U $pg_user" 2>/dev/null | \
        gzip > "$output_file"
    else
      docker exec "$pg_container" pg_dumpall -U "$pg_user" 2>/dev/null | \
        gzip > "$output_file"
    fi

    local size=$(du -sh "$output_file" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "PostgreSQL 备份完成: $output_file ($size)"
  else
    log_warn "PostgreSQL 容器未运行，跳过"
  fi
}

backup_mariadb() {
  log_step "备份 MariaDB..."

  local maria_container="${MARIADB_CONTAINER:-homelab-mariadb}"
  local maria_pass="${MARIADB_ROOT_PASSWORD:-}"
  local output_file="$BACKUP_PATH/sql/mariadb/mariadb_${TIMESTAMP}.sql.gz"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${maria_container}$"; then
    if [[ -n "$maria_pass" ]]; then
      docker exec "$maria_container" \
        mariadb-dump --all-databases -u root -p"$maria_pass" 2>/dev/null | \
        gzip > "$output_file"
    else
      docker exec "$maria_container" \
        mariadb-dump --all-databases -u root 2>/dev/null | \
        gzip > "$output_file"
    fi

    local size=$(du -sh "$output_file" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "MariaDB 备份完成: $output_file ($size)"
  else
    log_warn "MariaDB 容器未运行，跳过"
  fi
}

backup_redis() {
  log_step "备份 Redis..."

  local redis_container="${REDIS_CONTAINER:-homelab-redis}"
  local redis_pass="${REDIS_PASSWORD:-}"
  local output_file="$BACKUP_PATH/sql/redis/redis_${TIMESTAMP}.rdb"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${redis_container}$"; then
    # Trigger BGSAVE
    if [[ -n "$redis_pass" ]]; then
      docker exec "$redis_container" \
        redis-cli -a "$redis_pass" --no-auth-warning BGSAVE 2>/dev/null
    else
      docker exec "$redis_container" redis-cli BGSAVE 2>/dev/null
    fi

    sleep 2

    # Copy RDB file
    docker cp "$redis_container:/data/dump.rdb" "$output_file" 2>/dev/null || {
      log_warn "Redis RDB 备份失败"
      return 1
    }

    local size=$(du -sh "$output_file" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "Redis 备份完成: $output_file ($size)"
  else
    log_warn "Redis 容器未运行，跳过"
  fi
}

backup_databases() {
  backup_postgres
  backup_mariadb
  backup_redis
}

# =============================================================================
# Volume Backup Functions
# =============================================================================
backup_volumes() {
  log_step "备份 Docker 卷..."

  local volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | \
    grep -vE '^(traefik-logs|portainer-data|homelab-postgres|homelab-redis|homelab-mariadb)' || true)

  if [[ -z "$volumes" ]]; then
    log_warn "没有找到需要备份的卷"
    return
  fi

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  备份卷: $vol"

    local output_file="$BACKUP_PATH/volumes/vol_${vol}.tar.gz"

    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH/volumes:/backup:rw" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || {
      log_warn "  卷 $vol 备份失败"
      continue
    }

    local size=$(du -sh "$output_file" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "  卷 $vol 备份完成 ($size)"
  done <<< "$volumes"
}

# =============================================================================
# Config Backup Functions
# =============================================================================
backup_configs() {
  log_step "备份配置文件..."

  local config_output="$BACKUP_PATH/configs.tar.gz"

  tar czf "$config_output" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='*.log' \
    --exclude='.git' \
    config/ stacks/ scripts/ .env.example README.md 2>/dev/null || {
    log_warn "配置文件备份失败"
    return 1
  }

  local size=$(du -sh "$config_output" 2>/dev/null | cut -f1 || echo "N/A")
  log_info "配置文件备份完成: $config_output ($size)"
}

# =============================================================================
# Restic Backup Functions
# =============================================================================
backup_restic() {
  log_step "执行 Restic 增量备份..."

  local restic_repo="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"
  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -z "$restic_pass" ]]; then
    log_error "RESTIC_PASSWORD 未设置"
    return 1
  fi

  # Check if backup stack is running
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'resticker'; then
    # Use resticker container
    docker compose -f "$BASE_DIR/stacks/backup/docker-compose.yml" exec resticker \
      restic backup /data \
      --repo /repo \
      --password "$restic_pass" \
      --tag "manual-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || {
      log_warn "Resticker 备份失败，尝试直接运行"
      # Fallback: run restic directly
      restic backup /opt/homelab/data \
        --repo "$restic_repo" \
        --password "$restic_pass" \
        --tag "manual-$(date +%Y%m%d_%H%M%S)"
    }
  else
    # Check if restic is installed
    if command -v restic &> /dev/null; then
      restic backup /opt/homelab/data \
        --repo "$restic_repo" \
        --password "$restic_pass" \
        --tag "manual-$(date +%Y%m%d_%H%M%S)"
    else
      log_error "Restic 未安装，请安装: https://restic.readthedocs.io/"
      return 1
    fi
  fi

  log_info "Restic 备份完成"

  # Apply retention policy
  log_step "应用保留策略..."
  if command -v restic &> /dev/null; then
    restic forget \
      --repo "$restic_repo" \
      --password "$restic_pass" \
      --keep-daily "$RETENTION_DAYS" \
      --keep-weekly "$RETENTION_WEEKS" \
      --keep-monthly "$RETENTION_MONTHS" \
      --prune 2>/dev/null || log_warn "保留策略应用失败"
  fi
}

# =============================================================================
# Rclone Sync Functions
# =============================================================================
sync_rclone() {
  log_step "同步到云存储..."

  local rclone_dest="${RCLONE_DESTINATION:-backup}"
  local rclone_config="${RCLONE_CONFIG_PATH:-$BASE_DIR/config/rclone/rclone.conf}"

  if [[ ! -f "$rclone_config" ]]; then
    log_error "Rclone 配置文件不存在: $rclone_config"
    return 1
  fi

  docker run --rm \
    -v "$BACKUP_DIR:/data:ro" \
    -v "$rclone_config:/config/rclone.conf:ro" \
    rclone/rclone:1.68.0 \
    sync /data "$rclone_dest:/homelab-backups/$(hostname)-$(date +%Y%m%d)" \
    --config /config/rclone.conf \
    --progress \
    --transfers 4 \
    --checkers 8 \
    --drive-chunk-size 64M 2>/dev/null || {
    log_warn "Rclone 同步失败"
    return 1
  }

  log_info "云存储同步完成"
}

# =============================================================================
# Cleanup Old Backups
# =============================================================================
cleanup_old() {
  log_step "清理过期备份..."

  # Cleanup local backups
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
  fi

  # Cleanup Restic old snapshots
  local restic_repo="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"
  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -n "$restic_pass" ]] && command -v restic &> /dev/null; then
    restic forget \
      --repo "$restic_repo" \
      --password "$restic_pass" \
      --keep-daily "$RETENTION_DAYS" \
      --keep-weekly "$RETENTION_WEEKS" \
      --keep-monthly "$RETENTION_MONTHS" \
      --prune 2>/dev/null || true
  fi

  log_info "清理完成"
}

# =============================================================================
# List Backups
# =============================================================================
list_backups() {
  echo ""
  echo "=== 本地备份 ==="
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -type d -printf "%T+ %p\n" 2>/dev/null | sort -r | head -20 || echo "无备份"
  else
    echo "备份目录不存在: $BACKUP_DIR"
  fi

  echo ""
  echo "=== Restic 快照 ==="
  local restic_repo="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"
  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -n "$restic_pass" ]] && command -v restic &> /dev/null; then
    restic snapshots --repo "$restic_repo" --password "$restic_pass" 2>/dev/null || echo "无法列出快照"
  else
    echo "Restic 未配置或未安装"
  fi

  echo ""
}

# =============================================================================
# Verify Backups
# =============================================================================
verify_backups() {
  log_step "验证备份完整性..."

  local errors=0

  # Verify local backups
  if [[ -d "$BACKUP_DIR" ]]; then
    log_info "检查本地备份文件..."
    local archives=$(find "$BACKUP_DIR" -maxdepth 2 -name "*.tar.gz" -o -name "*.sql.gz" 2>/dev/null)
    if [[ -n "$archives" ]]; then
      echo "$archives" | while IFS= read -r f; do
        if [[ -f "$f" ]]; then
          if tar tzf "$f" &>/dev/null || gzip -t "$f" &>/dev/null; then
            log_info "  ✓ $(basename "$f")"
          else
            log_error "  ✗ $(basename "$f") - 损坏"
            ((errors++))
          fi
        fi
      done
    else
      log_warn "无本地备份文件"
    fi
  fi

  # Verify Restic repo
  local restic_repo="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"
  local restic_pass="${RESTIC_PASSWORD:-}"

  if [[ -n "$restic_pass" ]] && command -v restic &> /dev/null; then
    log_info "检查 Restic 仓库..."
    if restic check --repo "$restic_repo" --password "$restic_pass" 2>/dev/null; then
      log_info "  ✓ Restic 仓库完整"
    else
      log_error "  ✗ Restic 仓库有问题"
      ((errors++))
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_info "所有备份验证通过 ✓"
  else
    log_error "$errors 个备份验证失败"
  fi
}

# =============================================================================
# Send Notification
# =============================================================================
send_notification() {
  local status="${1:-success}"
  local message="${2:-}"

  local ntfy_topic="${NTFY_TOPIC:-homelab-backups}"

  if [[ -n "$NTFY_AUTH_ENABLED" ]] && [[ "$NTFY_AUTH_ENABLED" != "false" ]]; then
    # Simple ntfy notification (anonymous)
    curl -s -X POST "https://ntfy.sh/$ntfy_topic" \
      -d "[$(hostname)] Backup $status: $message" \
      --no-progress-meter 2>/dev/null || true
  fi
}

# =============================================================================
# Dry Run
# =============================================================================
dry_run() {
  echo ""
  echo "=== 备份预览 (DRY RUN) ==="
  echo ""

  echo "备份目标目录: $BACKUP_PATH"
  echo ""

  echo "--- 数据库 ---"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|mariadb|redis' && echo "  ✓ 将备份数据库"
  echo ""

  echo "--- Docker 卷 ---"
  docker volume ls --format '{{.Name}}' 2>/dev/null | grep -vE '^(traefik-logs|portainer-data)' | head -5 && echo "  ✓ 将备份卷"
  echo ""

  echo "--- 配置文件 ---"
  echo "  ✓ 将备份: config/, stacks/, scripts/"
  echo ""

  echo "--- Restic ---"
  if [[ -n "${RESTIC_PASSWORD:-}" ]]; then
    echo "  ✓ 将创建 Restic 快照"
  else
    echo "  ✗ RESTIC_PASSWORD 未设置"
  fi

  echo ""
  echo "实际执行请去掉 --dry-run 参数"
  echo ""
}

# =============================================================================
# Main
# =============================================================================
main() {
  local target=""
  local dry_run_flag=false
  local list_flag=false
  local verify_flag=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        target="$2"; shift 2 ;;
      --dry-run)
        dry_run_flag=true; shift ;;
      --list)
        list_flag=true; shift ;;
      --verify)
        verify_flag=true; shift ;;
      --compress|-c)
        shift ;;
      --encrypt|-e)
        shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        log_error "未知参数: $1"; usage; exit 1 ;;
    esac
  done

  # Default target
  target="${target:-all}"

  # Handle special modes
  case "true" in
    $list_flag)
      list_backups
      exit 0
      ;;
    $verify_flag)
      verify_backups
      exit 0
      ;;
    $dry_run_flag)
      dry_run
      exit 0
      ;;
  esac

  # Run backup
  log_info "=========================================="
  log_info "HomeLab Backup — $target"
  log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
  log_info "=========================================="

  check_prereqs

  case "$target" in
    all)
      backup_databases
      backup_configs
      backup_volumes
      backup_restic
      cleanup_old
      ;;
    databases)
      backup_databases
      ;;
    volumes)
      backup_volumes
      ;;
    configs)
      backup_configs
      ;;
    restic)
      backup_restic
      cleanup_old
      ;;
    rclone)
      sync_rclone
      ;;
    *)
      log_error "未知备份目标: $target"
      usage
      exit 1
      ;;
  esac

  # Summary
  echo ""
  log_info "=========================================="
  log_info "备份完成"
  log_info "=========================================="
  du -sh "$BACKUP_PATH" 2>/dev/null || true
  ls -lh "$BACKUP_PATH"/*/*.gz "$BACKUP_PATH"/*/*.rdb 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}' || true
  echo ""

  send_notification "success" "$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)"
}

# Trap for errors
trap 'send_notification "failed" "Backup script error"; log_error "备份失败"; exit 1' ERR

main "$@"
