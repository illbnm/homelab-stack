#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

if [[ ! -f "$MIRRORS_FILE" ]]; then
    echo "Mirrors configuration file not found: $MIRRORS_FILE"
    exit 1
fi

declare -A mirrors
while IFS=: read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    mirrors["$key"]="$value"
done < <(grep -E '^[^#]' "$MIRRORS_FILE" | yq e 'to_entries | .[] | .key + ": " + .value')

function replace_images() {
    local action="$1"
    local dry_run=false
    local check_only=false

    if [[ "$action" == "--dry-run" ]]; then
        dry_run=true
    elif [[ "$action" == "--check" ]]; then
        check_only=true
    fi

    for compose_file in $(find . -name "docker-compose*.yml"); do
        for key in "${!mirrors[@]}"; do
            if grep -q "$key" "$compose_file"; then
                if $check_only; then
                    echo "Check: $compose_file contains $key"
                elif $dry_run; then
                    echo "Dry run: Replace $key with ${mirrors[$key]} in $compose_file"
                else
                    sed -i "s|$key|${mirrors[$key]}|g" "$compose_file"
                    echo "Replaced $key with ${mirrors[$key]} in $compose_file"
                fi
            fi
        done
    done
}

function restore_images() {
    for compose_file in $(find . -name "docker-compose*.yml"); do
        for key in "${!mirrors[@]}"; do
            if grep -q "${mirrors[$key]}" "$compose_file"; then
                sed -i "s|${mirrors[$key]}|$key|g" "$compose_file"
                echo "Restored $key in $compose_file"
            fi
        done
    done
}

case "$1" in
    --cn)
        replace_images "$1"
        ;;
    --restore)
        restore_images
        ;;
    --dry-run)
        replace_images "$1"
        ;;
    --check)
        replace_images "$1"
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac