#!/usr/bin/env bash
# =============================================================================
# Localize Images — 镜像源替换工具
# Replaces gcr.io/ghcr.io images with CN mirrors in all compose files.
#
# Usage:
#   ./scripts/localize-images.sh --cn        # Replace with CN mirrors
#   ./scripts/localize-images.sh --restore   # Restore original images
#   ./scripts/localize-images.sh --dry-run   # Preview changes
#   ./scripts/localize-images.sh --check     # Check if replacement needed
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }

# ─── Mirror Mapping ─────────────────────────────────────────────────────────
# Registry-level replacements (order matters: more specific first)
declare -a MAPPING_FROM=(
  "gcr.io/"
  "ghcr.io/"
  "quay.io/"
  "registry.k8s.io/"
  "k8s.gcr.io/"
)
declare -a MAPPING_TO=(
  "m.daocloud.io/gcr.io/"
  "m.daocloud.io/ghcr.io/"
  "m.daocloud.io/quay.io/"
  "m.daocloud.io/registry.k8s.io/"
  "m.daocloud.io/k8s.gcr.io/"
)

BACKUP_SUFFIX=".orig"

# ─── Find all compose files ─────────────────────────────────────────────────
find_compose_files() {
  find "$ROOT_DIR/stacks" -name "docker-compose*.yml" -type f 2>/dev/null
}

# ─── Count replaceable images ───────────────────────────────────────────────
count_replaceable() {
  local count=0
  while IFS= read -r file; do
    for pattern in "${MAPPING_FROM[@]}"; do
      local matches
      matches=$(grep -c "image:.*${pattern}" "$file" 2>/dev/null || echo 0)
      count=$((count + matches))
    done
  done < <(find_compose_files)
  echo "$count"
}

# ─── Check mode ─────────────────────────────────────────────────────────────
do_check() {
  log_step "Checking images in compose files..."
  local total=0
  local files_with_foreign=0

  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"
    local file_count=0
    for pattern in "${MAPPING_FROM[@]}"; do
      local matches
      matches=$(grep -c "image:.*${pattern}" "$file" 2>/dev/null || echo 0)
      file_count=$((file_count + matches))
    done
    if [[ $file_count -gt 0 ]]; then
      echo -e "  ${YELLOW}[NEEDS CN]${NC} $rel_path — $file_count foreign images"
      total=$((total + file_count))
      files_with_foreign=$((files_with_foreign + 1))
    else
      echo -e "  ${GREEN}[OK]${NC}       $rel_path"
    fi
  done < <(find_compose_files)

  echo ""
  if [[ $total -gt 0 ]]; then
    echo -e "  ${YELLOW}Found $total images in $files_with_foreign files that need CN mirrors${NC}"
    echo "  Run: $0 --cn"
    return 1
  else
    log_info "All images are already using accessible registries"
    return 0
  fi
}

# ─── Dry-run mode ────────────────────────────────────────────────────────────
do_dry_run() {
  log_step "Dry-run: Preview CN mirror replacements"
  local total=0

  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"
    for i in "${!MAPPING_FROM[@]}"; do
      local from="${MAPPING_FROM[$i]}"
      local to="${MAPPING_TO[$i]}"
      while IFS= read -r line; do
        local original=$(echo "$line" | sed 's/.*image: *//' | tr -d '"'\'' ')
        local replaced="${original/$from/$to}"
        echo -e "  ${YELLOW}$rel_path${NC}"
        echo -e "    - $original"
        echo -e "    + $replaced"
        total=$((total + 1))
      done < <(grep "image:.*${from}" "$file" 2>/dev/null || true)
    done
  done < <(find_compose_files)

  echo ""
  echo "  Total: $total images would be replaced"
  echo "  Run: $0 --cn  to apply"
}

# ─── CN mode: Replace with mirrors ──────────────────────────────────────────
do_cn() {
  log_step "Replacing images with CN mirrors..."
  local total=0

  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"
    local changed=false

    # Backup original if not already backed up
    if [[ ! -f "${file}${BACKUP_SUFFIX}" ]]; then
      cp "$file" "${file}${BACKUP_SUFFIX}"
    fi

    for i in "${!MAPPING_FROM[@]}"; do
      local from="${MAPPING_FROM[$i]}"
      local to="${MAPPING_TO[$i]}"
      local count
      count=$(grep -c "image:.*${from}" "$file" 2>/dev/null || echo 0)
      if [[ $count -gt 0 ]]; then
        sed -i'' "s|${from}|${to}|g" "$file"
        total=$((total + count))
        changed=true
      fi
    done

    if $changed; then
      echo -e "  ${GREEN}[UPDATED]${NC} $rel_path"
    fi
  done < <(find_compose_files)

  echo ""
  log_info "Replaced $total images with CN mirrors"
  echo "  Originals backed up with ${BACKUP_SUFFIX} suffix"
  echo "  To restore: $0 --restore"
}

# ─── Restore mode ───────────────────────────────────────────────────────────
do_restore() {
  log_step "Restoring original images..."
  local restored=0

  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"
    local backup="${file}${BACKUP_SUFFIX}"
    if [[ -f "$backup" ]]; then
      mv "$backup" "$file"
      echo -e "  ${GREEN}[RESTORED]${NC} $rel_path"
      restored=$((restored + 1))
    fi
  done < <(find_compose_files)

  if [[ $restored -eq 0 ]]; then
    log_warn "No backup files found (${BACKUP_SUFFIX}). Nothing to restore."
  else
    log_info "Restored $restored files to original images"
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 <mode>"
  echo ""
  echo "Modes:"
  echo "  --cn       Replace gcr.io/ghcr.io/quay.io with CN mirrors"
  echo "  --restore  Restore original image references from backups"
  echo "  --dry-run  Preview what would be changed"
  echo "  --check    Check if replacement is needed"
  exit 1
}

[[ $# -lt 1 ]] && usage

case "$1" in
  --cn)      do_cn ;;
  --restore) do_restore ;;
  --dry-run) do_dry_run ;;
  --check)   do_check ;;
  *)         usage ;;
esac
