#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — 批量替换 gcr.io / ghcr.io 镜像为国内源
# 支持: --cn / --restore / --dry-run / --check
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
CONFIG_FILE="$BASE_DIR/config/cn-mirrors.yml"
STACKS_DIR="$BASE_DIR/stacks"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[localize]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[localize]${NC} $*"; }
log_error() { echo -e "${RED}[localize]${NC} $*" >&2; }
log_ok()    { echo -e "${GREEN}[localize]${NC} ${BOLD}✓${NC} $*"; }

DRY_RUN=false
MODE=""
CHANGES=0

usage() {
  cat << USAGE_EOF
用法: $0 <命令> [选项]

命令:
  --cn          替换为国内镜像 (DaoCloud)
  --restore     恢复原始镜像
  --dry-run     预览变更（不实际修改）
  --check       检测当前是否需要替换

示例:
  \$0 --cn          # 替换所有 compose 文件
  \$0 --dry-run     # 预览变更
  \$0 --restore     # 恢复原始镜像
  \$0 --check       # 检测当前状态
USAGE_EOF
}

MODE="${1:-}"
shift 2>/dev/null || true
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  usage
  exit 1
fi

# Write python helper to temp file
PYTHON_HELPER=$(mktemp --suffix=.py)
cat > "$PYTHON_HELPER" << 'PYEOF'
import sys, re, json

CONFIG_FILE = sys.argv[1]
ACTION = sys.argv[2]

REGISTRY_FALLBACKS = {
    'gcr.io': 'm.daocloud.io/gcr.io',
    'ghcr.io': 'm.daocloud.io/ghcr.io',
    'k8s.gcr.io': 'k8s-gcr.m.daocloud.io',
    'registry.k8s.io': 'k8s.m.daocloud.io',
    'quay.io': 'quay.m.daocloud.io',
    'docker.io': 'docker.m.daocloud.io',
}

# Read explicit mapping from cn-mirrors.yml
CN_MAPPINGS = {}

try:
    with open(CONFIG_FILE) as f:
        current_key = None
        for line in f:
            line = line.rstrip()
            stripped = line.lstrip()
            leading_spaces = len(line) - len(stripped)
            # Top-level keys (no leading spaces)
            if leading_spaces == 0 and ':' in stripped:
                if stripped.startswith('mirrors:') or stripped.startswith('registry'):
                    continue
                m = re.match(r'^([a-zA-Z0-9_.:/$@-]+):$', stripped)
                if m and ':' in m.group(1):
                    current_key = m.group(1)
                    CN_MAPPINGS[current_key] = None
            elif current_key and stripped.startswith('cn:'):
                val = stripped.split('cn:', 1)[1].strip()
                CN_MAPPINGS[current_key] = val
except Exception as e:
    sys.stderr.write(f'Warning: could not parse {CONFIG_FILE}: {e}\n')

def replace_to_cn(img):
    if img in CN_MAPPINGS and CN_MAPPINGS[img]:
        return CN_MAPPINGS[img]
    for registry, mirror in REGISTRY_FALLBACKS.items():
        if img.startswith(registry + '/') or img == registry:
            return img.replace(registry, mirror, 1)
    if img.startswith('lscr.io/'):
        return img.replace('lscr.io/', 'm.daocloud.io/lscr/', 1)
    return img

def restore_from_cn(img):
    for prefix, orig in [
        ('m.daocloud.io/', ''),
        ('docker.m.daocloud.io/', ''),
        ('quay.m.daocloud.io/', ''),
    ]:
        if img.startswith(prefix):
            stripped = img[len(prefix):]
            # Check if this maps back to an original
            for orig_key, cn_val in CN_MAPPINGS.items():
                if cn_val == img:
                    return orig_key
            return stripped
    # Try reverse mapping
    for orig, cn in CN_MAPPINGS.items():
        if cn and img == cn:
            return orig
    return img

# Process file argument
file_path = sys.argv[3]
out_lines = []
changed_count = 0

with open(file_path) as f:
    for line in f:
        m = re.match(r'^(\s*image:\s*)(.+)$', line)
        if m:
            img = m.group(2).rstrip().strip('"').strip("'")
            if ACTION == 'cn':
                new_img = replace_to_cn(img)
            elif ACTION == 'restore':
                new_img = restore_from_cn(img)
            else:
                new_img = img

            if new_img != img:
                out_lines.append(m.group(1) + new_img + '\n')
                sys.stdout.write(f'CHG: {img} -> {new_img}\n')
                changed_count += 1
            else:
                out_lines.append(line)
        else:
            out_lines.append(line)

# Write result
result = ''.join(out_lines)
with open(file_path + '.tmp', 'w') as f:
    f.write(result)

if changed_count > 0:
    sys.stdout.write(f'COUNT: {changed_count}\n')
PYEOF

CHANGES=0

# Process a single compose file
process_compose_file() {
  local file="$1"

  [[ ! -f "$file" ]] && return 0

  # Check if file has any target images
  local has_targets=false
  while IFS= read -r line; do
    for reg in gcr.io ghcr.io k8s.gcr.io registry.k8s.io quay.io lscr.io; do
      if echo "$line" | grep -q "$reg"; then
        has_targets=true
        break 2
      fi
    done
  done < <(grep -E '^\s+image:' "$file" 2>/dev/null || true)

  [[ "$has_targets" == "false" ]] && return 0

  log_info "Processing: $file"

  # Run python to process the file
  local python_output
  python_output=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" "$MODE" "$file" 2>&1)
  local python_stderr=$(echo "$python_output" | grep -v '^CHG:\|^COUNT:')
  local changes=$(echo "$python_output" | grep '^COUNT:' | cut -d' ' -f2 || echo 0)

  # Print change list
  echo "$python_output" | grep '^CHG:' | while IFS= read -r line; do
    local orig new_img
    orig=$(echo "$line" | sed 's/^CHG: //' | cut -d' ' -f1)
    new_img=$(echo "$line" | sed 's/^CHG: //' | cut -d' ' -f3)
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "  $orig → $new_img"
    fi
  done

  if [[ -n "$python_stderr" ]]; then
    echo "$python_stderr" | head -3 | sed 's/^/  /'
  fi

  if [[ "$changes" =~ ^[0-9]+$ && "$changes" -gt 0 ]]; then
    CHANGES=$((CHANGES + changes))
    if [[ "$DRY_RUN" != "true" ]]; then
      mv "$file.tmp" "$file"
      log_ok "  $changes image(s) updated"
    fi
  else
    rm -f "$file.tmp"
  fi
}

# Check mode
check_mode() {
  log_info "Checking for gcr.io/ghcr.io images in compose files..."
  local found_any=false

  while IFS= read -r file; do
    while IFS= read -r line; do
      if [[ "$line" =~ image:[[:space:]]*(.+) ]]; then
        local img="${BASH_REMATCH[1]}"
        img="${img//\"/}"
        img="${img//\'/}"
        img="${img// /}"

        for reg in gcr.io ghcr.io k8s.gcr.io registry.k8s.io quay.io lscr.io; do
          if [[ "$img" == *"$reg"* ]]; then
            echo -e "  ${RED}✗${NC} $file: $img"
            found_any=true
            break
          fi
        done
      fi
    done < <(grep -E '^\s+image:' "$file" 2>/dev/null || true)
  done < <(find "$STACKS_DIR" -name 'docker-compose*.yml' -not -path '*/.git/*' 2>/dev/null)

  if [[ "$found_any" == "false" ]]; then
    log_ok "All compose files are CN-localized"
    return 0
  else
    log_warn "Found images that need CN localization"
    return 1
  fi
}

# Main
case "$MODE" in
  --cn|--restore)
    echo ""
    if [[ "$MODE" == "--cn" ]]; then
      echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
      echo -e "${BOLD}║         CN Localization — Replacing Foreign Images    ║${NC}"
      echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    else
      echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
      echo -e "${BOLD}║         Restoring Original Foreign Images            ║${NC}"
      echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""

    [[ "$DRY_RUN" == "true" ]] && log_info "[DRY RUN] No files will be modified"

    while IFS= read -r file; do
      process_compose_file "$file"
    done < <(find "$STACKS_DIR" -name 'docker-compose*.yml' -not -path '*/.git/*' 2>/dev/null)

    echo ""
    if [[ "$CHANGES" -gt 0 ]]; then
      log_ok "Total: $CHANGES image(s) processed"
      [[ "$DRY_RUN" != "true" ]] && \
        log_info "Run 'docker compose -f <stack>/docker-compose.yml config --quiet' to verify"
    else
      log_info "No images needed ${MODE#--} — all files already up to date"
    fi
    ;;

  --check)
    check_mode
    ;;

  --dry-run)
    DRY_RUN=true
    MODE="--cn"
    echo -e "${BOLD}[DRY RUN] Previewing CN localization changes${NC}"
    echo ""
    while IFS= read -r file; do
      process_compose_file "$file"
    done < <(find "$STACKS_DIR" -name 'docker-compose*.yml' -not -path '*/.git/*' 2>/dev/null)
    [[ "$CHANGES" -eq 0 ]] && log_info "No changes needed"
    ;;

  *)
    log_error "Unknown mode: $MODE"
    usage
    exit 1
    ;;
esac

rm -f "$PYTHON_HELPER"
