#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

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
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        if [[ -n "$key" && -n "$value" ]]; then
            if [[ "$mode" == "--cn" ]]; then
                find . -name "*.yml" -o -name "*.yaml" -exec sed -i.bak "s|$key|$value|g" {} +
            elif [[ "$mode" == "--restore" ]]; then
                find . -name "*.yml" -o -name "*.yaml" -exec sed -i.bak "s|$value|$key|g" {} +
            fi
            if $dry_run; then
                echo "Dry run: Would replace $key with $value"
            elif $check_only; then
                if grep -q "$key" ./**/*.yml ./**/*.yaml; then
                    echo "Check: $key is still present"
                else
                    echo "Check: $key is replaced"
                fi
            fi
        fi
    done < <(yq e '.mirrors[]' "$MIRRORS_FILE")

    if $dry_run || $check_only; then
        echo "Dry run or check completed."
    else
        echo "Image replacement completed."
    fi
}

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 --cn|--restore|--dry-run|--check"
    exit 1
fi

replace_images "$1"

exit 0