#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Runner
# Main entry point for running integration tests
#
# Usage:
#   ./tests/run-tests.sh --stack <name>    # Test specific stack
#   ./tests/run-tests.sh --all             # Test all stacks
#   ./tests/run-tests.sh --help            # Show help
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# =============================================================================
# Command Line Arguments
# =============================================================================

STACK=""
RUN_ALL=false
OUTPUT_JSON=false
TIMEOUT=120

usage() {
  cat << EOF
HomeLab Stack — Integration Tests

Usage:
  $0 [OPTIONS]

Options:
  --stack <name>     Test specific stack (base, monitoring, sso, etc.)
  --all              Test all available stacks
  --json             Output results in JSON format
  --timeout <sec>    Test timeout (default: 120s)
  --help             Show this help message

Examples:
  $0 --stack base           # Test base stack only
  $0 --all --json          # Test all stacks with JSON output
  $0 --stack monitoring    # Test monitoring stack

Available Stacks:
  - base            # Traefik, Portainer, Watchtower
  - monitoring      # Prometheus, Grafana, Loki
  - sso             # Authentik, PostgreSQL, Redis
  - productivity    # Gitea, Outline, Vaultwarden
  - storage         # Nextcloud, MinIO, FileBrowser
  - media           # Jellyfin, Sonarr, Radarr
  - ai              # Ollama, Open WebUI
  - network         # AdGuard, WireGuard

Environment Variables:
  DOMAIN             # Your domain (default: localhost)
  VERBOSE            # Enable verbose output (default: false)
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# =============================================================================
# Test Discovery
# =============================================================================

get_available_stacks() {
  find "$SCRIPT_DIR/stacks" -name "*.test.sh" -type f | xargs -n1 basename | sed 's/.test.sh$//'
}

run_stack_tests() {
  local stack="$1"
  local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
  
  if [ ! -f "$test_file" ]; then
    echo "❌ Test file not found: $test_file"
    return 1
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing Stack: ${stack}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Run test file
  source "$test_file"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
  # Initialize report
  init_report
  
  # Print header
  print_header
  
  # Start timer
  local start_time=$(date +%s)
  
  # Run tests
  if [ "$RUN_ALL" = true ]; then
    local stacks
    stacks=$(get_available_stacks)
    
    for stack in $stacks; do
      run_stack_tests "$stack"
    done
  elif [ -n "$STACK" ]; then
    run_stack_tests "$STACK"
  else
    echo "❌ Error: Must specify --stack <name> or --all"
    usage
    exit 1
  fi
  
  # Calculate duration
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Finalize report
  finalize_report "$duration"
  
  # Print summary
  if [ "$OUTPUT_JSON" = true ]; then
    cat "$REPORT_FILE"
  else
    print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED" "$duration"
  fi
  
  # Exit with appropriate code
  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
  
  exit 0
}

# Run main
main "$@"
