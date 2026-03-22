#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local dry_run=""
    if [[ "$mode" == "--dry-run" ]]; then
        dry_run="--dry-run"
    fi

    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*([^\s]+)\s*$ ]]; then
            key="${BASH_REMATCH[1]}"
        fi
        if [[ "$value" =~ ^\s*([^\s]+)\s*$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$key" && -n "$value" ]]; then
            if [[ "$mode" == "--cn" ]]; then
                find . -name "*.yml" -o -name "*.yaml" -exec sed -i "$dry_run" "s|$key|$value|g" {} +
            elif [[ "$mode" == "--restore" ]]; then
                find . -name "*.yml" -o -name "*.yaml" -exec sed -i "$dry_run" "s|$value|$key|g" {} +
            fi
        fi
    done < <(grep -E '^\s*[^\s]+:\s*[^\s]+' "$MIRRORS_FILE")
}

function check_images() {
    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*([^\s]+)\s*$ ]]; then
            key="${BASH_REMATCH[1]}"
        fi
        if [[ "$value" =~ ^\s*([^\s]+)\s*$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$key" && -n "$value" ]]; then
            if grep -qE "$key" $(find . -name "*.yml" -o -name "*.yaml"); then
                echo "Images need replacement."
                return 0
            fi
        fi
    done < <(grep -E '^\s*[^\s]+:\s*[^\s]+' "$MIRRORS_FILE")
    echo "Images are already localized."
    return 1
}

case "$1" in
    --cn)
        replace_images "--cn"
        ;;
    --restore)
        replace_images "--restore"
        ;;
    --dry-run)
        replace_images "--dry-run"
        ;;
    --check)
        check_images
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac

exit 0