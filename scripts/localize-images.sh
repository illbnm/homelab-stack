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
        if [[ "$mode" == "--cn" ]]; then
            if grep -q "$key" docker-compose*.yml; then
                if $dry_run; then
                    echo "Would replace $key with $value"
                elif $check_only; then
                    echo "Check: $key should be replaced with $value"
                else
                    sed -i "s|$key|$value|g" docker-compose*.yml
                fi
            fi
        elif [[ "$mode" == "--restore" ]]; then
            if grep -q "$value" docker-compose*.yml; then
                if $dry_run; then
                    echo "Would replace $value with $key"
                elif $check_only; then
                    echo "Check: $value should be replaced with $key"
                else
                    sed -i "s|$value|$key|g" docker-compose*.yml
                fi
            fi
        fi
    done < <(grep -E '^[^#]*:' "$MIRRORS_FILE" | grep -v '^$')
}

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 --cn|--restore|--dry-run|--check"
    exit 1
fi

replace_images "$1"
