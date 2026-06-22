#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    echo "Usage: ./localize-images.sh [options]"
    echo "Options:"
    echo "  --cn        Replace with CN mirrors"
    echo "  --restore   Restore to original images"
    echo "  --dry-run   Preview changes without modifying"
    echo "  --check     Check if replacement is needed"
    exit 1
}

if [[ $# -eq 0 ]]; then usage; fi

MODE=""
for arg in "$@"; do
    case "$arg" in
        --cn) MODE="cn" ;;
        --restore) MODE="restore" ;;
        --dry-run) MODE="dry-run" ;;
        --check) MODE="check" ;;
        *) usage ;;
    esac
done

MIRRORS_FILE="config/cn-mirrors.yml"
if [[ ! -f "$MIRRORS_FILE" ]]; then
    echo "Error: $MIRRORS_FILE not found."
    exit 1
fi

COMPOSE_FILES=$(find stacks -name "docker-compose*.yml")

process_files() {
    local direction=$1
    local dry_run=$2
    local needs_change=0

    while IFS=":" read -r key val; do
        orig=$(echo "$key" | xargs)
        mirror=$(echo "$val" | xargs)
        if [[ "$orig" == "mirrors" || -z "$orig" || -z "$mirror" || "$orig" == \#* ]]; then
            continue
        fi

        for file in $COMPOSE_FILES; do
            if [[ "$direction" == "cn" ]]; then
                if grep -q "image: $orig" "$file"; then
                    needs_change=1
                    if [[ "$dry_run" == "1" ]]; then
                        echo "[Dry Run] Would replace $orig -> $mirror in $file"
                    else
                        # Use portable temp file for sed or use perl
                        perl -pi -e "s|image: $orig|image: $mirror|g" "$file"
                        echo "Replaced $orig -> $mirror in $file"
                    fi
                fi
            else
                if grep -q "image: $mirror" "$file"; then
                    needs_change=1
                    if [[ "$dry_run" == "1" ]]; then
                        echo "[Dry Run] Would restore $mirror -> $orig in $file"
                    else
                        perl -pi -e "s|image: $mirror|image: $orig|g" "$file"
                        echo "Restored $mirror -> $orig in $file"
                    fi
                fi
            fi
        done
    done < "$MIRRORS_FILE"
    
    return $needs_change
}

case "$MODE" in
    check)
        if process_files "cn" 1 >/dev/null; then
            echo "All up to date."
            exit 0
        else
            echo "Updates required."
            exit 1
        fi
        ;;
    dry-run)
        process_files "cn" 1
        ;;
    cn)
        process_files "cn" 0
        ;;
    restore)
        process_files "restore" 0
        ;;
esac

exit 0
