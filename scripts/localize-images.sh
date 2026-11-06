#!/bin/bash

CONFIG_FILE="config/cn-mirrors.yml"

function replace_images() {
  local mode=$1
  find stacks -name "docker-compose.yml" | while read -r file; do
    if [ "$mode" == "--cn" ]; then
      echo "Localizing $file..."
      sed -i 's|image: \([^/]*\)/\([^/]*\):|image: m.daocloud.io/\1/\2:|g' "$file"
    else
      echo "Restoring $file..."
      sed -i 's|image: m.daocloud.io/||g' "$file"
    fi
  done
}

case "$1" in
  --cn) replace_images "--cn" ;;
  --restore) replace_images "--restore" ;;
  *) echo "Usage: $0 {--cn|--restore}" ;;
esac