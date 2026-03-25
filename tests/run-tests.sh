#!/bin/bash
# run-tests.sh - Main test runner for homelab-stack
#
# Usage:
#   ./run-tests.sh                    Run all tests
#   ./run-tests.sh --stack base      Run base stack tests only
#   ./run-tests.sh --stack databases Run databases stack tests only
#   ./run-tests.sh --list            List available test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# Source libraries
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# Default settings
STACK=""
VERBOSE=false
ONLY_FAILED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack)
            STACK="$2"
            shift 2
            ;;
        --list)
            echo "Available test suites:"
            echo "  all             - Run all tests"
            echo "  base            - Base infrastructure (Traefik, Portainer, Watchtower)"
            echo "  databases       - Database stack (PostgreSQL, Redis, MariaDB)"
            echo "  notifications   - Notification stack (ntfy, apprise)"
            echo "  media           - Media stack (Jellyfin, Sonarr, etc.)"
            echo "  monitoring      - Monitoring stack (Prometheus, Grafana)"
            echo "  network         - Network stack (AdGuard, WireGuard)"
            echo "  productivity    - Productivity stack (Gitea, Outline)"
            echo "  sso             - SSO stack (Authentik)"
            echo "  storage         - Storage stack (Nextcloud, MinIO)"
            echo "  backup          - Backup stack (Duplicati, Restic)"
            echo "  e2e             - End-to-end tests"
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --only-failed)
            ONLY_FAILED=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--stack <name>] [--list] [--verbose] [--only-failed]"
            echo ""
            echo "Options:"
            echo "  --stack <name>   Run specific stack tests"
            echo "  --list           List available test suites"
            echo "  --verbose        Verbose output"
            echo "  --only-failed    Run only previously failed tests"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 --stack base       # Run base stack tests"
            echo "  $0 --list             # List test suites"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Initialize report
report_init
report_header

# Run configuration tests
run_config_tests() {
    report_section "Configuration Tests"

    # Test compose syntax
    test_start "docker-compose syntax validation"
    local failed=0
    for f in $(find stacks -name 'docker-compose.yml' 2>/dev/null); do
        if ! docker compose -f "$f" config --quiet 2>/dev/null; then
            test_fail "Invalid syntax in $f"
            failed=1
            break
        fi
    done
    [ $failed -eq 0 ] && test_pass || true

    # Test no latest tags
    test_start "no :latest image tags"
    local count=$(grep -r 'image:.*:latest' stacks/ 2>/dev/null | wc -l || echo 0)
    [ "$count" = "0" ] && test_pass || test_fail "Found $count :latest tags"
}

# Run stack-specific tests
run_stack_tests() {
    local stack="$1"
    local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

    if [ ! -f "$test_file" ]; then
        echo "No tests found for stack: $stack"
        return 1
    fi

    report_section "${stack^} Stack Tests"

    # Load environment
    if [ -f "${ROOT_DIR}/.env" ]; then
        export $(grep -E '^[A-Z]' "${ROOT_DIR}/.env" | xargs 2>/dev/null)
    fi

    # Run test file
    bash "$test_file"
}

# Run all stack tests
run_all_stack_tests() {
    local stacks="base databases notifications media monitoring network productivity sso storage backup"

    for stack in $stacks; do
        if [ -f "${SCRIPT_DIR}/stacks/${stack}.test.sh" ]; then
            run_stack_tests "$stack" || true
        fi
    done
}

# Run E2E tests
run_e2e_tests() {
    report_section "End-to-End Tests"

    for test_file in "${SCRIPT_DIR}"/e2e/*.test.sh; do
        if [ -f "$test_file" ]; then
            local test_name=$(basename "$test_file" .test.sh)
            report_section "E2E: $test_name"
            bash "$test_file" || true
        fi
    done
}

# Main execution
START_TIME=$(date +%s)

if [ -n "$STACK" ]; then
    if [ "$STACK" = "all" ]; then
        run_config_tests
        run_all_stack_tests
    elif [ "$STACK" = "e2e" ]; then
        run_e2e_tests
    else
        run_config_tests
        run_stack_tests "$STACK"
    fi
else
    run_config_tests
    run_all_stack_tests
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print summary
report_summary "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED" "0" "$DURATION"

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
