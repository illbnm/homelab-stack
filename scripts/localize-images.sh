#!/bin/bash

CONFIG_FILE="config/cn-mirrors.yml"

case "$1" in
    --cn)
        yq eval -i '(.mirrors[] | keys_unsorted[]) as $k | (.mirrors[$k]) as $v | setpath([$k]; $v)' "$CONFIG_FILE"
        ;;
    --restore)
        yq eval -i '(.mirrors[] | keys_unsorted[]) as $k | (.mirrors[$k]) as $v | setpath([$k]; $k)' "$CONFIG_FILE"
        ;;
    --dry-run)
        yq eval '(.mirrors[] | keys_unsorted[]) as $k | (.mirrors[$k]) as $v | setpath([$k]; $v)' "$CONFIG_FILE"
        ;;
    --check)
        if grep -q "gcr.io\|ghcr.io" stacks/**/*.yml; then
            echo "Images need to be localized."
        else
            echo "Images are already localized."
        fi
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac

if [[ "$1" == "--cn" || "$1" == "--restore" ]]; then
    for file in stacks/**/*.yml; do
        while IFS=: read -r key value; do
            sed -i "s|$key|$value|g" "$file"
        done < <(yq eval '.mirrors[]' "$CONFIG_FILE")
    done
fi