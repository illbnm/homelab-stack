#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

if [[ ! -f "$MIRRORS_FILE" ]]; then
    echo "Mirrors configuration file not found!"
    exit 1
fi

declare -A MIRRORS
while IFS=: read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    MIRRORS["$key"]="$value"
done < <(grep -E '^[^#]*:' "$MIRRORS_FILE" | sed 's/: /=/')

case "$1" in
    --cn)
        for compose_file in stacks/**/*.yml; do
            for key in "${!MIRRORS[@]}"; do
                sed -i "s|$key|${MIRRORS[$key]}|g" "$compose_file"
            done
        done
        ;;
    --restore)
        for compose_file in stacks/**/*.yml; do
            for key in "${!MIRRORS[@]}"; do
                sed -i "s|${MIRRORS[$key]}|$key|g" "$compose_file"
            done
        done
        ;;
    --dry-run)
        for compose_file in stacks/**/*.yml; do
            for key in "${!MIRRORS[@]}"; do
                grep -Hn "$key" "$compose_file"
            done
        done
        ;;
    --check)
        for compose_file in stacks/**/*.yml; do
            for key in "${!MIRRORS[@]}"; do
                if grep -q "$key" "$compose_file"; then
                    echo "Need to replace $key in $compose_file"
                fi
            done
        done
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac