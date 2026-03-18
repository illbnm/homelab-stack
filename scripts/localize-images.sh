#!/usr/bin/env bash
# =============================================================================
# Localize Images — 替换 compose 文件中的海外镜像为国内镜像
# 支持 --cn / --restore / --dry-run / --check 模式
# 映射表参考 config/cn-mirrors.yml
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[localize]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[localize]${NC} $*"; }
log_error() { echo -e "${RED}[localize]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
MIRRORS_FILE="$PROJECT_DIR/config/cn-mirrors.yml"

# 内置镜像映射表（覆盖项目中所有用到的 gcr.io/ghcr.io 镜像）
declare -A IMAGE_MAP=(
  # Dashboard
  ["ghcr.io/ajnart/homarr"]="ghcr.m.daocloud.io/ajnart/homarr"
  ["ghcr.io/gethomepage/homepage"]="ghcr.m.daocloud.io/gethomepage/homepage"
  # Notifications
  ["binwiederhier/ntfy"]="docker.m.daocloud.io/binwiederhier/ntfy"
  ["gotify/server"]="docker.m.daocloud.io/gotify/server"
  ["caronc/apprise"]="docker.m.daocloud.io/caronc/apprise"
  # SSO
  ["ghcr.io/goauthentik/server"]="ghcr.m.daocloud.io/goauthentik/server"
  ["ghcr.io/goauthentik/redis"]="ghcr.m.daocloud.io/goauthentik/redis"
  ["ghcr.io/goauthentik/postgres"]="ghcr.m.daocloud.io/goauthentik/postgres"
  # Monitoring
  ["grafana/grafana"]="docker.m.daocloud.io/grafana/grafana"
  ["prom/prometheus"]="docker.m.daocloud.io/prom/prometheus"
  ["prom/alertmanager"]="docker.m.daocloud.io/prom/alertmanager"
  ["grafana/loki"]="docker.m.daocloud.io/grafana/loki"
  ["grafana/alloy"]="docker.m.daocloud.io/grafana/alloy"
  ["quay.io/prometheus/node-exporter"]="quay.m.daocloud.io/prometheus/node-exporter"
  ["quay.io/influxdb/influxdb"]="quay.m.daocloud.io/influxdb/influxdb"
  # AI
  ["ghcr.io/open-webui/open-webui"]="ghcr.m.daocloud.io/open-webui/open-webui"
  ["ghcr.io/abiosoft/sd-webui-docker"]="ghcr.m.daocloud.io/abiosoft/sd-webui-docker"
  ["ollama/ollama"]="docker.m.daocloud.io/ollama/ollama"
  # Network / Infra
  ["traefik"]="docker.m.daocloud.io/library/traefik"
  ["portainer/portainer-ce"]="docker.m.daocloud.io/portainer/portainer-ce"
  ["containrrr/watchtower"]="docker.m.daocloud.io/containrrr/watchtower"
  ["ghcr.io/qdm12/gluetun"]="ghcr.m.daocloud.io/qdm12/gluetun"
  # Storage
  ["minio/minio"]="docker.m.daocloud.io/minio/minio"
  ["filebrowser/filebrowser"]="docker.m.daocloud.io/filebrowser/filebrowser"
  ["nextcloud"]="docker.m.daocloud.io/library/nextcloud"
  # Productivity
  ["gitea/gitea"]="docker.m.daocloud.io/gitea/gitea"
  ["vaultwarden/server"]="docker.m.daocloud.io/vaultwarden/server"
  ["outlinewiki/outline"]="ghcr.m.daocloud.io/outlinewiki/outline"
  # Media
  ["jellyfin/jellyfin"]="docker.m.daocloud.io/jellyfin/jellyfin"
  ["linuxserver/prowlarr"]="docker.m.daocloud.io/linuxserver/prowlarr"
  ["linuxserver/qbittorrent"]="docker.m.daocloud.io/linuxserver/qbittorrent"
  ["linuxserver/radarr"]="docker.m.daocloud.io/linuxserver/radarr"
  ["linuxserver/sonarr"]="docker.m.daocloud.io/linuxserver/sonarr"
  ["lscr.io/linuxserver/bookstack"]="lscr.m.daocloud.io/linuxserver/bookstack"
  # Home Automation
  ["homeassistant/home-assistant"]="docker.m.daocloud.io/homeassistant/home-assistant"
  ["nodered/node-red"]="docker.m.daocloud.io/nodered/node-red"
  ["eclipse-mosquitto"]="docker.m.daocloud.io/library/eclipse-mosquitto"
  ["koenkk/zigbee2mqtt"]="docker.m.daocloud.io/koenkk/zigbee2mqtt"
  # Databases
  ["postgres"]="docker.m.daocloud.io/library/postgres"
  ["redis"]="docker.m.daocloud.io/library/redis"
  ["mariadb"]="docker.m.daocloud.io/library/mariadb"
)

# 从 cn-mirrors.yml 加载额外映射
load_yaml_mappings() {
  [[ ! -f "$MIRRORS_FILE" ]] && return
  while IFS=':' read -r key value; do
    key=$(echo "$key" | xargs); value=$(echo "$value" | xargs)
    [[ -z "$key" || "$key" == "#"* ]] && continue
    IMAGE_MAP["$key"]="$value"
  done < "$MIRRORS_FILE"
}

# 查找镜像的国内映射
find_mirror() {
  local image=$1
  # 精确匹配
  if [[ -n "${IMAGE_MAP[$image]+x}" ]]; then
    echo "${IMAGE_MAP[$image]}"
    return
  fi
  # 去掉 tag 匹配
  local base="${image%%:*}"
  if [[ -n "${IMAGE_MAP[$base]+x}" ]]; then
    local tag="${image##*:}"
    [[ "$base" == "$image" ]] || echo "${IMAGE_MAP[$base]}:$tag"
    return
  fi
  # 前缀匹配 (ghcr.io/xxx → ghcr.m.daocloud.io/xxx)
  for prefix in gcr.io ghcr.io k8s.gcr.io registry.k8s.io quay.io; do
    if [[ "$image" == "$prefix/"* ]]; then
      local rest="${image#$prefix/}"
      echo "${prefix}.m.daocloud.io/$rest"
      return
    fi
  done
  return 1
}

# 扫描所有 compose 文件
scan_compose_files() {
  find "$PROJECT_DIR/stacks" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | sort
}

# 提取镜像列表
extract_images() {
  local file=$1
  grep -E '^\s+image:\s*' "$file" | sed -E 's/^\s+image:\s*//; s/["\x27]//g' | sort -u
}

# 检测需要替换的镜像
do_check() {
  load_yaml_mappings
  local total=0 needs_replace=0
  echo -e "\n${GREEN}=== CN Image Localization Check ===${NC}\n"
  for f in $(scan_compose_files); do
    local rel="${f#$PROJECT_DIR/}"
    for img in $(extract_images "$f"); do
      ((total++))
      if mirror=$(find_mirror "$img"); then
        echo -e "  ${YELLOW}NEEDS REPLACE${NC} $img → $mirror"
        ((needs_replace++))
      else
        echo -e "  ${GREEN}OK${NC} $img"
      fi
    done
  done
  echo -e "\nTotal: $total | Needs replacement: $needs_replace"
  [[ $needs_replace -eq 0 ]]
}

# 替换镜像（支持 dry-run）
do_localize() {
  local dry_run=$1
  load_yaml_mappings
  local changed=0

  for f in $(scan_compose_files); do
    local rel="${f#$PROJECT_DIR/}"
    local modified=0
    local tmp
    tmp=$(mktemp)

    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]+image:[[:space:]]*(.+)$ ]]; then
        local img="${BASH_REMATCH[1]}"
        img=$(echo "$img" | xargs | tr -d '"\x27')
        if mirror=$(find_mirror "$img"); then
          local indent="${line%%image*}"
          if [[ "$dry_run" == "true" ]]; then
            echo -e "  ${YELLOW}WOULD REPLACE${NC} $img → $mirror (${rel})"
          else
            echo "${indent}image: $mirror" >> "$tmp"
            ((changed++)); ((modified++))
            continue
          fi
        fi
      fi
      echo "$line" >> "$tmp"
    done < "$f"

    if [[ "$dry_run" != "true" && "$modified" -gt 0 ]]; then
      cp "$f" "${f}.orig"
      mv "$tmp" "$f"
      log_info "Updated $rel ($modified images)"
    else
      rm -f "$tmp"
    fi
  done

  if [[ "$dry_run" == "true" ]]; then
    echo -e "\nDry-run complete. No files modified."
  elif [[ "$changed" -gt 0 ]]; then
    log_info "Total: $changed images localized across compose files"
    log_info "Original files backed up as *.orig"
  else
    log_info "No images needed replacement."
  fi
}

# 恢复原始文件
do_restore() {
  local restored=0
  for orig in $(find "$PROJECT_DIR/stacks" -name "docker-compose*.yml.orig" -o -name "docker-compose*.yaml.orig" 2>/dev/null); do
    mv "$orig" "${orig%.orig}"
    log_info "Restored ${orig#$PROJECT_DIR/}"
    ((restored++))
  done
  if [[ $restored -eq 0 ]]; then
    log_warn "No .orig backup files found to restore."
  fi
}

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  --cn        Replace overseas images with CN mirrors
  --restore   Restore original images from .orig backups
  --dry-run   Preview changes without modifying files
  --check     Check which images need replacement
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

case "$1" in
  --cn)      do_localize false ;;
  --dry-run) do_localize true ;;
  --check)   do_check ;;
  --restore) do_restore ;;
  *) usage ;;
esac
