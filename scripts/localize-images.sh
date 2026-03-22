#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

if [[ ! -f "$MIRRORS_FILE" ]]; then
    echo "Mirrors configuration file not found: $MIRRORS_FILE"
    exit 1
fi

declare -A MIRRORS
while IFS=: read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    MIRRORS["$key"]="$value"
done < <(yq e 'mirrors | to_entries | .[] | .key + ": " + .value' "$MIRRORS_FILE")

function replace_images() {
    local mode="$1"
    local action=""
    case "$mode" in
        --cn) action="s|gcr.io|${MIRRORS["gcr.io"]}|g; s|ghcr.io|${MIRRORS["ghcr.io"]}|g" ;;
        --restore) action="s|${MIRRORS["gcr.io"]}|gcr.io|g; s|${MIRRORS["ghcr.io"]}|ghcr.io|g" ;;
        --dry-run) action="p" ;;
        --check) action="p" ;;
        *) echo "Invalid mode"; exit 1 ;;
    esac

    for file in stacks/**/*.yml; do
        if [[ "$mode" == "--check" ]]; then
            if grep -qE "gcr.io|ghcr.io" "$file"; then
                echo "File $file contains gcr.io/ghcr.io images."
            fi
        else
            sed -i.bak "$action" "$file"
            if [[ "$mode" == "--dry-run" ]]; then
                git diff "$file"
                git checkout -- "$file"
            fi
        fi
    done
}

replace_images "$1"
exit 0