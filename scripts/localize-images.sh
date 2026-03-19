#!/bin/bash

CONFIG_FILE="config/cn-mirrors.yml"

function replace_images() {
  local mode="$1"
  local action=""
  case "$mode" in
    --cn) action="s" ;;
    --restore) action="s" ;;
    --dry-run) action="p" ;;
    --check) action="p" ;;
    *) echo "Invalid mode"; exit 1 ;;
  esac

  while IFS=: read -r key value; do
    if [[ "$key" =~ ^\s*gcr\.io/ || "$key" =~ ^\s*ghcr\.io/ ]]; then
      if [[ "$mode" == "--check" ]]; then
        if grep -q "$key" stacks/**/*.yml; then
          echo "Check failed: $key found in compose files."
          exit 1
        fi
      else
        if [[ "$mode" == "--restore" ]]; then
          sed -i "$action" "s|$value|$key|g" stacks/**/*.yml
        else
          sed -i "$action" "s|$key|$value|g" stacks/**/*.yml
        fi
      fi
    fi
  done < <(yq e '.mirrors[]' "$CONFIG_FILE")

  if [[ "$mode" == "--dry-run" ]]; then
    echo "Dry run complete. No changes made."
  fi
}

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 --cn|--restore|--dry-run|--check"
  exit 1
fi

replace_images "$1"