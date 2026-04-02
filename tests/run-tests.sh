#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

run_stack_tests() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    if [ -f "$test_file" ]; then
        echo "Testing stack: $stack"
        bash "$test_file"
        report_test $?
    fi
}

if [ "$1" = "--stack" ]; then
    run_stack_tests "$2"
elif [ "$1" = "--all" ]; then
    for test_file in "$SCRIPT_DIR"/stacks/*.test.sh; do
        stack=$(basename "$test_file" .test.sh)
        run_stack_tests "$stack"
    done
else
    echo "Usage: $0 --stack <name> | --all"
    exit 1
fi

print_summary
