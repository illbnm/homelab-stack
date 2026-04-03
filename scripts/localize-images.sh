#!/usr/bin/env bash
# =============================================================================
# Localize Images — Replace gcr.io/ghcr.io with Chinese mirror equivalents
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "  ${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "  ${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
log_fail()  { echo -e "  ${RED}[FAIL]${NC} $*"; }

# Default mirror prefixes for Chinese network
CN_MIRROR="${CN_MIRROR:-m.daocloud.io}"
FALLBACK_CN_MIRROR="${FALLBACK_CN_MIRROR:-docker.m.daocloud.io}"

usage() {
  cat <<EOF
Usage: $0 [--cn|--restore|--dry-run|--check] [--mirror <url>]

Replace gcr.io / ghcr.io / k8s.gcr.io / quay.io image prefixes in all
docker-compose files with Chinese mirror equivalents.

Modes:
  --cn         Replace with Chinese mirror (default: m.daocloud.io)
  --restore    Restore original image prefixes from backup
  --dry-run    Preview changes without modifying files
  --check      Report current mirror status without changes
  --backup     Create backup of all compose files before modification

Options:
  --mirror     Override default CN mirror URL
               Examples:
                 --mirror m.daocloud.io
                 --mirror gcr.m.daocloud.io
                 --mirror docker.m.daocloud.io

Examples:
  $0 --cn                    # Replace with m.daocloud.io
  $0 --cn --mirror gcr.m.daocloud.io
  $0 --restore               # Restore originals
  $0 --dry-run --cn          # Preview changes
  $0 --check                 # Show current status
EOF
  exit 1
}

# Registry to mirror prefix mapping
declare -A REGISTRY_MIRRORS=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

# Find all docker-compose files
find_compose_files() {
  find "$SCRIPT_DIR/../stacks" -maxdepth 3 -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null
}

# Check if a file needs localization
check_needs_localization() {
  local file=$1
  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    if grep -qE "^\s+image:\s*${registry}[/:]" "$file" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# Replace registry prefix in a file
replace_registry() {
  local file=$1
  local dry_run=${2:-false}

  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    local mirror="${REGISTRY_MIRRORS[$registry]}"
    # Replace lines like: image: gcr.io/xxx or image: ghcr.io/xxx
    if grep -qE "^\s+image:\s*${registry}[/:]" "$file" 2>/dev/null; then
      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY] Would replace: ${registry} -> ${mirror} in $file"
        grep -nE "^\s+image:\s*${registry}[/:]" "$file" 2>/dev/null | head -5
      else
        sed -i "s|${registry}|${mirror}|g" "$file"
        log_ok "Replaced ${registry} -> ${mirror} in $file"
      fi
    fi
  done
}

# Restore original
restore_registry() {
  local file=$1
  local dry_run=${2:-false}

  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    local mirror="${REGISTRY_MIRRORS[$registry]}"
    if grep -qE "^\s+image:\s*${mirror}[/:]" "$file" 2>/dev/null; then
      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY] Would restore: ${mirror} -> ${registry} in $file"
      else
        sed -i "s|${mirror}|${registry}|g" "$file"
        log_ok "Restored ${mirror} -> ${registry} in $file"
      fi
    fi
  done
}

# Check mode — report current status
do_check() {
  log_info "Checking compose files for external registries..."
  echo ""
  local found=0
  while IFS= read -r file; do
    for registry in "${!REGISTRY_MIRRORS[@]}"; do
      local mirror="${REGISTRY_MIRRORS[$registry]}"
      if grep -qE "^\s+image:\s*${registry}[/:]" "$file" 2>/dev/null; then
        log_warn "$(realpath --relative-to="$SCRIPT_DIR/.." "$file") uses ${registry} — needs CN mirror"
        ((found++))
      elif grep -qE "^\s+image:\s*${mirror}[/:]" "$file" 2>/dev/null; then
        log_ok "$(realpath --relative-to="$SCRIPT_DIR/.." "$file") already using mirror"
      fi
    done
  done < <(find_compose_files)

  if [[ $found -eq 0 ]]; then
    log_ok "All compose files already use CN mirrors or don't need localization"
  fi
  echo ""
  echo "Registry mirror mapping:"
  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    echo "  ${registry} -> ${REGISTRY_MIRRORS[$registry]}"
  done
}

# Backup compose files
do_backup() {
  local backup_dir="$SCRIPT_DIR/../.localization-backup"
  mkdir -p "$backup_dir"
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  log_info "Backing up compose files to $backup_dir/"
  while IFS= read -r file; do
    local rel_path
    rel_path=$(realpath --relative-to="$SCRIPT_DIR/.." "$file")
    local dir="$backup_dir/${timestamp}/$(dirname "$rel_path")"
    mkdir -p "$dir"
    cp "$file" "$dir/"
    log_ok "Backed up $rel_path"
  done < <(find_compose_files)
}

# CN mode
do_cn() {
  local dry_run=${1:-false}
  local count=0

  while IFS= read -r file; do
    if check_needs_localization "$file"; then
      log_info "Processing: $file"
      replace_registry "$file" "$dry_run"
      ((count++))
    fi
  done < <(find_compose_files)

  if [[ $count -eq 0 ]]; then
    log_ok "No files need localization"
  elif [[ "$dry_run" != "true" ]]; then
    log_ok "Done — modified $count file(s)"
    log_info "Run 'docker-compose -f <file> pull' to fetch localized images"
  fi
}

# Restore mode
do_restore() {
  local dry_run=${1:-false}
  local count=0

  # Try backup dir first
  local backup_dir="$SCRIPT_DIR/../.localization-backup"
  local latest_backup
  latest_backup=$(ls -dt "${backup_dir}"/*/ 2>/dev/null | head -1)

  if [[ -n "$latest_backup" ]]; then
    log_info "Found backup at $latest_backup"
    if [[ "$dry_run" != "true" ]]; then
      while IFS= read -r file; do
        local rel_path
        rel_path=$(realpath --relative-to="$SCRIPT_DIR/.." "$file")
        local backup_file="${latest_backup}${rel_path}"
        if [[ -f "$backup_file" ]]; then
          cp "$backup_file" "$file"
          log_ok "Restored $rel_path from backup"
          ((count++))
        fi
      done < <(find_compose_files)
    fi
  else
    # No backup, do in-place replacement
    while IFS= read -r file; do
      restore_registry "$file" "$dry_run"
      ((count++))
    done < <(find_compose_files)
  fi

  if [[ "$dry_run" != "true" ]]; then
    log_ok "Restored $count file(s)"
  fi
}

# Main
DRY_RUN=false
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn)       MODE="cn" ;;
    --restore)  MODE="restore" ;;
    --dry-run)  DRY_RUN=true ;;
    --check)    MODE="check" ;;
    --backup)   MODE="backup" ;;
    --mirror)   CN_MIRROR="$2"; shift ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
  shift
done

# If no mode, default to check
MODE="${MODE:-check}"

case "$MODE" in
  cn)       do_cn "$DRY_RUN" ;;
  restore)  do_restore "$DRY_RUN" ;;
  check)    do_check ;;
  backup)   do_backup ;;
esac
