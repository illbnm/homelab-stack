#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/report.sh"

TARGET_STACK="all"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --stack) TARGET_STACK="$2"; shift ;;
        --all) TARGET_STACK="all" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Starting HomeLab Stack Automated Test Suite (Target: $TARGET_STACK)..."

if [ "$TARGET_STACK" = "all" ] || [ "$TARGET_STACK" = "base" ]; then
    bash "$SCRIPT_DIR/stacks/base.test.sh"
fi

if [ "$TARGET_STACK" = "all" ] || [ "$TARGET_STACK" = "databases" ]; then
    bash "$SCRIPT_DIR/stacks/databases.test.sh"
fi

if [ "$TARGET_STACK" = "all" ] || [ "$TARGET_STACK" = "monitoring" ]; then
    bash "$SCRIPT_DIR/stacks/monitoring.test.sh"
fi

report_summary
