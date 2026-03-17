#!/bin/bash

CONFIG_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local action=""
    case "$mode" in
        --cn) action="s" ;;
        --restore) action="y" ;;
        --dry-run) action="p" ;;
        --check) action="q" ;;
        *) echo "Invalid mode"; exit 1 ;;
    esac

    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*mirrors\s*$ ]]; then
            continue
        fi
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        if [[ -n "$key" && -n "$value" ]]; then
            find stacks -type f -name "*.yml" -exec sed -i"$action" "s|$key|$value|g" {} +
        fi
    done < <(yq e '.mirrors[]' "$CONFIG_FILE")

    if [[ "$mode" == "--check" ]]; then
        if grep -rE "gcr\.io|ghcr\.io" stacks; then
            echo "Images need to be replaced."
        else
            echo "All images are already replaced."
        fi
    fi
}

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 --cn|--restore|--dry-run|--check"
    exit 1
fi

replace_images "$1"
exit 0