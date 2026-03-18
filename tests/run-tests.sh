#!/usr/bin/env bash
# run-tests.sh - Test runner entry point for homelab-stack integration tests
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT
#
# Usage:
#   ./run-tests.sh --stack <name>    Run tests for a specific stack
#   ./run-tests.sh --all             Run all stack tests
#   ./run-tests.sh --list            List all available tests
#   ./run-tests.sh --parallel        Run all tests in parallel
#   ./run-tests.sh --e2e             Run end-to-end tests
#
# Exit codes: 0 = all passed, 1 = failures, 2 = usage error

set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Source libraries
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# All available stacks
readonly ALL_STACKS=(base media storage monitoring network productivity ai sso databases notifications dashboard)

# Parallel mode flag
PARALLEL_MODE=false
E2E_MODE=false
TARGET_STACK=""

# Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_RESET='\033[0m'

# --- Help ---
usage() {
    cat <<EOF
${C_BOLD}homelab-stack Integration Test Runner${C_RESET}

Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Run tests for a specific stack
  --all             Run all stack tests
  --e2e             Run end-to-end tests
  --parallel        Run stack tests in parallel
  --list            List all available stacks and tests
  --help            Show this help message

Available stacks: ${ALL_STACKS[*]}
EOF
    exit 0
}

# --- List tests ---
list_tests() {
    echo -e "${C_BOLD}Available stacks:${C_RESET}"
    for stack in "${ALL_STACKS[@]}"; do
        local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"
        if [ -f "$test_file" ]; then
            local tests
            tests=$(grep -oP '^\s*test_\K[a-z_]+' "$test_file" 2>/dev/null | sort)
            echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}${stack}${C_RESET}"
            for t in $tests; do
                echo "    - ${t}"
            done
        else
            echo -e "  ${C_RED}✗${C_RESET} ${stack} (test file not found)"
        fi
    done

    echo -e "\n${C_BOLD}End-to-end tests:${C_RESET}"
    for e2e_file in "${SCRIPT_DIR}"/e2e/*.test.sh; do
        if [ -f "$e2e_file" ]; then
            local name
            name=$(basename "$e2e_file" .test.sh)
            local tests
            tests=$(grep -oP '^\s*test_\K[a-z_]+' "$e2e_file" 2>/dev/null | sort)
            echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}${name}${C_RESET}"
            for t in $tests; do
                echo "    - ${t}"
            done
        fi
    done
}

# --- Run a single stack test ---
run_stack_test() {
    local stack="$1"
    local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

    if [ ! -f "$test_file" ]; then
        echo -e "${C_RED}ERROR: test file not found for stack '${stack}'${C_RESET}" >&2
        return 1
    fi

    if [ "$PARALLEL_MODE" = true ]; then
        (
            bash "$test_file" 2>&1
        )
    else
        bash "$test_file" 2>&1
    fi
}

# --- Run e2e tests ---
run_e2e_tests() {
    echo -e "\n${C_BOLD}${C_CYAN}══════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}         Running End-to-End Tests           ${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}══════════════════════════════════════════${CRESET}"

    local failed=0
    for e2e_file in "${SCRIPT_DIR}"/e2e/*.test.sh; do
        if [ -f "$e2e_file" ]; then
            echo -e "\n${C_CYAN}Running: $(basename "$e2e_file")${C_RESET}"
            if ! bash "$e2e_file" 2>&1; then
                failed=$((failed + 1))
            fi
        fi
    done
    return "$failed"
}

# --- Main ---
main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --stack)
                if [ -z "${2:-}" ]; then
                    echo -e "${C_RED}ERROR: --stack requires a stack name${C_RESET}" >&2
                    exit 2
                fi
                TARGET_STACK="$2"
                shift 2
                ;;
            --all)
                TARGET_STACK="__ALL__"
                shift
                ;;
            --parallel)
                PARALLEL_MODE=true
                shift
                ;;
            --e2e)
                E2E_MODE=true
                shift
                ;;
            --list)
                list_tests
                exit 0
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo -e "${C_RED}ERROR: unknown option '$1'${C_RESET}" >&2
                echo "Use --help for usage information"
                exit 2
                ;;
        esac
    done

    # Banner
    echo -e "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}║   homelab-stack Integration Tests              ║${C_RESET}"
    echo -e "${C_BOLD}╚══════════════════════════════════════════╝${CRESET}"
    echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo -e "  Mode:      $([ "$PARALLEL_MODE" = true ] && echo "parallel" || echo "sequential")"

    # Check docker availability (warning only, tests can skip)
    if ! docker_check 2>/dev/null; then
        echo -e "  ${C_YELLOW}⚠ Docker not available - tests will be skipped${C_RESET}"
    else
        echo -e "  Docker:    $(docker --version 2>/dev/null | head -1)"
    fi

    local overall_exit=0

    # Run stack tests
    if [ -n "$TARGET_STACK" ]; then
        local stacks_to_run=()
        if [ "$TARGET_STACK" = "__ALL__" ]; then
            stacks_to_run=("${ALL_STACKS[@]}")
        else
            stacks_to_run=("$TARGET_STACK")
        fi

        if [ "$PARALLEL_MODE" = true ] && [ ${#stacks_to_run[@]} -gt 1 ]; then
            echo -e "\n${C_BOLD}Running ${#stacks_to_run[@]} stacks in parallel...${C_RESET}"
            local pids=()
            for stack in "${stacks_to_run[@]}"; do
                run_stack_test "$stack" &
                pids+=($!)
            done
            # Wait for all and check exit codes
            for pid in "${pids[@]}"; do
                if ! wait "$pid"; then
                    overall_exit=1
                fi
            done
        else
            for stack in "${stacks_to_run[@]}"; do
                echo -e "\n${C_BOLD}${C_CYAN}══════════════════════════════════════════${C_RESET}"
                echo -e "${C_BOLD}  Stack: ${stack}${C_RESET}"
                echo -e "${C_BOLD}${C_CYAN}══════════════════════════════════════════${CRESET}"
                if ! run_stack_test "$stack"; then
                    overall_exit=1
                fi
            done
        fi
    fi

    # Run e2e tests
    if [ "$E2E_MODE" = true ]; then
        if ! run_e2e_tests; then
            overall_exit=1
        fi
    fi

    # Final summary
    echo -e "\n${C_BOLD}${C_CYAN}══════════════════════════════════════════${C_RESET}"
    if [ "$overall_exit" -eq 0 ]; then
        echo -e "${C_BOLD}${C_GREEN}✅ All test suites passed!${C_RESET}"
    else
        echo -e "${C_BOLD}${C_RED}❌ Some test suites failed!${C_RESET}"
    fi

    exit "$overall_exit"
}

main "$@"
