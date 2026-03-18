#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack Test Runner
# Entry point for running integration tests
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."

# Source library functions
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Default options
RUN_ALL=false
STACK=""

usage() {
  echo "Usage: $0 [--stack <name>] [--all] [--help]"
  echo ""
  echo "Options:"
  echo "  --stack <name>  Run tests for specific stack (base, media, storage, etc.)"
  echo "  --all           Run all stack tests"
  echo "  --help          Show this help message"
  echo ""
  echo "Available stacks:"
  echo "  base, media, storage, monitoring, network, productivity, ai, sso, databases, notifications"
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
    --help)
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

# Run tests
if [[ "$RUN_ALL" == true ]]; then
  echo "Running all stack tests..."
  for test_file in "$SCRIPT_DIR/stacks"/*.test.sh; do
    [[ -f "$test_file" ]] && source "$test_file"
  done
elif [[ -n "$STACK" ]]; then
  test_file="$SCRIPT_DIR/stacks/${STACK}.test.sh"
  if [[ -f "$test_file" ]]; then
    source "$test_file"
  else
    echo "Error: Test file not found for stack '$STACK'"
    exit 1
  fi
else
  usage
  exit 1
fi

# Print summary
print_summary

# Exit with appropriate code
[[ $FAILED -eq 0 ]] && exit 0 || exit 1