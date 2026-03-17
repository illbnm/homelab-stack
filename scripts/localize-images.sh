#!/bin/bash

MIRRORS_FILE="config/cn-mirrors.yml"

function replace_images() {
    local mode=$1
    local action="s"
    if [ "$mode" == "--restore" ]; then
        action="s|.*://[^/]*/\([^/]*\)/\([^/]*\):\(.*\)|\1/\2:\3|"
    elif [ "$mode" == "--cn" ]; then
        action="yml2cn"
    fi

    if [ "$mode" == "--dry-run" ]; then
        echo "Dry run mode. No changes will be made."
    fi

    if [ "$mode" == "--check" ]; then
        if grep -q "m.daocloud.io" docker-compose*.yml; then
            echo "Images need to be localized."
        else
            echo "Images are already localized."
        fi
        exit 0
    fi

    while IFS=: read -r key value; do
        if [[ "$key" =~ ^\s*[^#] ]]; then
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            if [ "$action" == "yml2cn" ]; then
                sed -i "s|$key|$value|" docker-compose*.yml
            else
                sed -i "$action|$key|$value|" docker-compose*.yml
            fi
        fi
    done < <(grep -v '^#' "$MIRRORS_FILE" | yq e 'to_entries | .[] | .key + ": " + .value' -)

    if [ "$mode" == "--dry-run" ]; then
        git diff docker-compose*.yml
    fi
}

case "$1" in
    --cn|--restore|--dry-run|--check)
        replace_images "$1"
        ;;
    *)
        echo "Usage: $0 --cn|--restore|--dry-run|--check"
        exit 1
        ;;
esac