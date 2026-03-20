#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local action=""
    case "$mode" in
        --cn)
            action="s|gcr.io|${MIRRORS_FILE}|g; s|ghcr.io|${MIRRORS_FILE}|g"
            ;;
        --restore)
            action="s|${MIRRORS_FILE}|gcr.io|g; s|${MIRRORS_FILE}|ghcr.io|g"
            ;;
        --dry-run)
            action="p"
            ;;
        --check)
            if grep -qE 'gcr.io|ghcr.io' stacks/**/*.yml; then
                echo "Images need to be replaced."
            else
                echo "Images are already replaced."
            fi
            return
            ;;
        *)
            echo "Invalid option. Use --cn, --restore, --dry-run, or --check."
            exit 1
            ;;
    esac

    if [[ "$mode" == "--dry-run" ]]; then
        grep -E 'gcr.io|ghcr.io' stacks/**/*.yml | sed "$action"
    else
        find stacks -name "*.yml" -exec sed -i "$action" {} +
    fi
}

replace_images "$1"