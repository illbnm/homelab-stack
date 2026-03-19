#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local action=""
    case "$mode" in
        --cn) action="replace" ;;
        --restore) action="restore" ;;
        --dry-run) action="dry-run" ;;
        --check) action="check" ;;
        *) echo "Invalid option"; exit 1 ;;
    esac

    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*([^\s]+)\s*$ ]]; then
            key="${BASH_REMATCH[1]}"
        fi
        if [[ "$value" =~ ^\s*([^\s]+)\s*$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        if [[ "$action" == "replace" ]]; then
            find . -name "*.yml" -exec sed -i "s|$key|$value|g" {} +
        elif [[ "$action" == "restore" ]]; then
            find . -name "*.yml" -exec sed -i "s|$value|$key|g" {} +
        elif [[ "$action" == "dry-run" ]]; then
            find . -name "*.yml" -exec grep -Hn "$key" {} +
        elif [[ "$action" == "check" ]]; then
            if grep -q "$key" ./**/*.yml; then
                echo "Images need replacement."
            else
                echo "Images are already replaced."
            fi
        fi
    done < <(yq e '.mirrors[]' "$MIRRORS_FILE")
}

replace_images "$1"
