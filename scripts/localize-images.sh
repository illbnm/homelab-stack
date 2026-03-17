#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode="$1"
    local action=""
    if [[ "$mode" == "--cn" ]]; then
        action="s|gcr.io|${MIRRORS_FILE}|g; s|ghcr.io|${MIRRORS_FILE}|g"
    elif [[ "$mode" == "--restore" ]]; then
        action="s|${MIRRORS_FILE}|gcr.io|g; s|${MIRRORS_FILE}|ghcr.io|g"
    fi

    if [[ "$mode" == "--dry-run" ]]; then
        echo "Dry run mode. No changes will be made."
        grep -rlE 'gcr.io|ghcr.io' stacks/ | xargs sed -n "${action}p"
    elif [[ "$mode" == "--check" ]]; then
        if grep -rlE 'gcr.io|ghcr.io' stacks/; then
            echo "Images need to be replaced."
        else
            echo "All images are already localized."
        fi
    else
        grep -rlE 'gcr.io|ghcr.io' stacks/ | xargs sed -i "${action}"
        echo "Images replaced."
    fi
}

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 --cn|--restore|--dry-run|--check"
    exit 1
fi

replace_images "$1"