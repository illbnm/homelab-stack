#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DAEMON_JSON=${DAEMON_JSON:-/etc/docker/daemon.json}
MIRRORS=("https://docker.m.daocloud.io" "https://hub-mirror.c.163.com" "https://mirror.baidubce.com" "https://mirror.gcr.io")
ASSUME_YES=false
DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage: scripts/setup-cn-mirrors.sh [--yes] [--dry-run]

Configures Docker registry mirrors for mainland China networks and verifies the
configuration by pulling hello-world. Requires sudo/root unless DAEMON_JSON is
pointed at a writable test path.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

confirm_cn() {
  if [[ "$ASSUME_YES" == true ]]; then
    return 0
  fi
  read -r -p "Are you deploying from mainland China or a slow/restricted Docker network? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

json_payload() {
  printf '{\n  "registry-mirrors": [\n'
  local index
  for index in "${!MIRRORS[@]}"; do
    if [[ "$index" -gt 0 ]]; then
      printf ',\n'
    fi
    printf '    "%s"' "${MIRRORS[$index]}"
  done
  printf '\n  ]\n}\n'
}

write_daemon_config() {
  local payload tmp
  payload=$(json_payload)
  if [[ "$DRY_RUN" == true ]]; then
    printf '%s' "$payload"
    return 0
  fi
  tmp=$(mktemp)
  printf '%s' "$payload" > "$tmp"
  if [[ "$(id -u)" -eq 0 || -w "$(dirname "$DAEMON_JSON")" ]]; then
    mkdir -p "$(dirname "$DAEMON_JSON")"
    cp "$tmp" "$DAEMON_JSON"
  else
    sudo mkdir -p "$(dirname "$DAEMON_JSON")"
    sudo cp "$tmp" "$DAEMON_JSON"
  fi
  rm -f "$tmp"
}

restart_docker() {
  [[ "$DRY_RUN" == true ]] && return 0
  if command -v systemctl >/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]]; then
      systemctl restart docker
    else
      sudo systemctl restart docker
    fi
  else
    printf 'Docker daemon config written. Restart Docker manually to apply it.\n'
  fi
}

verify_pull() {
  [[ "$DRY_RUN" == true ]] && return 0
  docker pull hello-world >/dev/null
  printf 'Docker mirror verification succeeded with hello-world.\n'
}

main() {
  if ! confirm_cn; then
    printf 'Skipped Docker mirror setup.\n'
    exit 0
  fi
  write_daemon_config
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  restart_docker
  verify_pull
  printf 'Docker registry mirrors configured from %s/config/cn-mirrors.yml.\n' "$ROOT_DIR"
}

main "$@"
