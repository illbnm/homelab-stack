#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_DIR="$ROOT_DIR/.localize-images-backup"
MODE=${1:---help}
COMPOSE_GLOB=()

usage() {
  cat <<'USAGE'
Usage: scripts/localize-images.sh --cn|--restore|--dry-run|--check

  --cn       Replace blocked registries in compose files with configured mirrors.
  --restore  Restore compose files from the last --cn backup.
  --dry-run  Print replacements that would be made without editing files.
  --check    Fail if compose files still contain gcr.io or ghcr.io images.
USAGE
}

collect_compose_files() {
  find "$ROOT_DIR" \( -path '*/.git' -o -path "$BACKUP_DIR" \) -prune -o -type f \( -name 'docker-compose.yml' -o -name 'docker-compose.local.yml' \) -print | sort
}

mirror_image() {
  local image=$1
  case "$image" in
    gcr.io/*) printf 'gcr.m.daocloud.io/%s' "${image#gcr.io/}" ;;
    ghcr.io/*) printf 'ghcr.m.daocloud.io/%s' "${image#ghcr.io/}" ;;
    k8s.gcr.io/*) printf 'k8s-gcr.m.daocloud.io/%s' "${image#k8s.gcr.io/}" ;;
    registry.k8s.io/*) printf 'k8s.m.daocloud.io/%s' "${image#registry.k8s.io/}" ;;
    quay.io/*) printf 'quay.m.daocloud.io/%s' "${image#quay.io/}" ;;
    *) printf '%s' "$image" ;;
  esac
}

restore_image() {
  local image=$1
  case "$image" in
    gcr.m.daocloud.io/*) printf 'gcr.io/%s' "${image#gcr.m.daocloud.io/}" ;;
    ghcr.m.daocloud.io/*) printf 'ghcr.io/%s' "${image#ghcr.m.daocloud.io/}" ;;
    k8s-gcr.m.daocloud.io/*) printf 'k8s.gcr.io/%s' "${image#k8s-gcr.m.daocloud.io/}" ;;
    k8s.m.daocloud.io/*) printf 'registry.k8s.io/%s' "${image#k8s.m.daocloud.io/}" ;;
    quay.m.daocloud.io/*) printf 'quay.io/%s' "${image#quay.m.daocloud.io/}" ;;
    *) printf '%s' "$image" ;;
  esac
}

replace_file() {
  local file=$1 dry_run=${2:-false} tmp old_image new_image changed=false
  tmp=$(mktemp)
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*[\"\']?)([^\"\'#[:space:]]+)([\"\']?.*)$ ]]; then
      old_image=${BASH_REMATCH[2]}
      new_image=$(mirror_image "$old_image")
      if [[ "$new_image" != "$old_image" ]]; then
        changed=true
        printf '%s: %s -> %s\n' "${file#$ROOT_DIR/}" "$old_image" "$new_image" >&2
        line="${BASH_REMATCH[1]}${new_image}${BASH_REMATCH[3]}"
      fi
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  if [[ "$changed" == true && "$dry_run" != true ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "${file#$ROOT_DIR/}")"
    cp "$file" "$BACKUP_DIR/${file#$ROOT_DIR/}"
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
  fi
}

restore_from_backup() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    printf 'No backup directory found at %s\n' "$BACKUP_DIR" >&2
    exit 1
  fi
  while IFS= read -r backup; do
    local relative=${backup#$BACKUP_DIR/}
    mkdir -p "$ROOT_DIR/$(dirname "$relative")"
    cp "$backup" "$ROOT_DIR/$relative"
    printf 'restored %s\n' "$relative"
  done < <(find "$BACKUP_DIR" -type f | sort)
}

check_no_blocked_registries() {
  local failed=0
  while IFS= read -r file; do
    if grep -Eq 'image:[[:space:]]*["'"'"']?(gcr\.io|ghcr\.io)/' "$file"; then
      printf 'blocked registry remains in %s\n' "${file#$ROOT_DIR/}" >&2
      failed=1
    fi
  done < <(collect_compose_files)
  exit "$failed"
}

run_cn() {
  local dry_run=${1:-false}
  while IFS= read -r file; do
    replace_file "$file" "$dry_run"
  done < <(collect_compose_files)
}

case "$MODE" in
  --cn) run_cn false ;;
  --dry-run) run_cn true ;;
  --restore) restore_from_backup ;;
  --check) check_no_blocked_registries ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
