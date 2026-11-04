#!/usr/bin/env bash
# tests/run-tests.sh
# Main test suite runner

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

STACK=""
RUN_ALL=false
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack) STACK="$2"; shift 2 ;;
        --all) RUN_ALL=true; shift ;;
        --json) OUTPUT_JSON=true; shift ;;
        --help)
            echo "Usage: $0 [--stack <name> | --all] [--json] [--help]"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          HomeLab Stack — Automated Integration Suite         ║"
echo "╚══════════════════════════════════════════════════════════════╝"

PASSED=0
FAILED=0

run_test() {
    local stack="$1"
    local test_name="$2"
    local func="$3"
    local start
    start=$(date +%s)
    if $func; then
        local end
        end=$(date +%s)
        log_pass "$stack" "$test_name" "$((end - start))"
        PASSED=$((PASSED + 1))
    else
        log_fail "$stack" "$test_name" "assertion error"
        FAILED=$((FAILED + 1))
    fi
}

# 1. Compose Syntax Validation
test_compose_syntax() {
    for f in $(find stacks -name 'docker-compose.yml'); do
        docker compose -f "$f" config -q >/dev/null 2>&1
    done
}

run_test "syntax" "All docker-compose files valid syntax" test_compose_syntax

# 2. Image Pinning Test
test_images_pinned() {
    assert_no_latest_images "stacks/"
}

run_test "config" "Image tags verified and pinned" test_images_pinned

echo "────────────────────────────────────────────────────────────────"
echo "Results: $PASSED passed, $FAILED failed"
echo "────────────────────────────────────────────────────────────────"

if [ "$OUTPUT_JSON" = true ]; then
    mkdir -p tests/results
    cat <<EOF > tests/results/report.json
{
  "passed": $PASSED,
  "failed": $FAILED,
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}
EOF
fi

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
