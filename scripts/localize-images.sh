#!/bin/bash

CONFIG_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local dry_run=false
    local check_only=false

    if [[ "$mode" == "--dry-run" ]]; then
        dry_run=true
    elif [[ "$mode" == "--check" ]]; then
        check_only=true
    fi

    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*mirrors\s*$ ]]; then
            continue
        fi
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        if [[ "$check_only" == true ]]; then
            if grep -q "$key" docker-compose*.yml; then
                echo "Check: $key needs replacement with $value"
            fi
        elif [[ "$dry_run" == true ]]; then
            echo "Dry run: Replacing $key with $value"
        else
            sed -i "s|$key|$value|g" docker-compose*.yml
            echo "Replaced $key with $value"
        fi
    done < <(yq e '.mirrors[]' "$CONFIG_FILE")
}

function restore_images() {
    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*mirrors\s*$ ]]; then
            continue
        fi
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        sed -i "s|$value|$key|g" docker-compose*.yml
        echo "Restored $value to $key"
    done < <(yq e '.mirrors[]' "$CONFIG_FILE")
}

case "$1" in
    --cn)
        replace_images "--cn"
        ;;
    --restore)
        restore_images
        ;;
    --dry-run)
        replace_images "--dry-run"
        ;;
    --check)
        replace_images "--check"
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac

exit 0