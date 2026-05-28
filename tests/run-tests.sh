#!/bin/bash

set -e

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\03[34m'
NC='\033[0m' # No Color

# Source helper libraries
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/docker.sh"
source "$REPO_ROOT/tests/lib/report.sh"

# Default test target
STACK_NAME="all"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK_NAME="$2"
      shift 2
      ;;
    --all)
      STACK_NAME="all"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Run tests based on stack selection
case $STACK_NAME in
  base)
    echo -e "\n${BLUE}Running base stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/base.test.sh"
    source "$REPO_ROOT/tests/stacks/network.test.sh"
    source "$REPO_ROOT/tests/stacks/sso.test.sh"
    source "$REPO_ROOT/tests/stacks/databases.test.sh"
    source "$REPO_ROOT/tests/stacks/notifications.test.sh"
    ;;
  media)
    echo -e "\n${BLUE}Running media stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/media.test.sh"
    ;;
  storage)
    echo -e "\n${BLUE}Running storage stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/storage.test.sh"
    ;;
  monitoring)
    echo -e "\n${BLUE}Running monitoring stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/monitoring.test.sh"
    ;;
  productivity)
    echo -e "\n${BLUE}Running productivity stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/productivity.test.sh"
    ;;
  ai)
    echo -e "\n${BLUE}Running AI stack tests...${NC"
    source "$REPO_ROOT/tests/stacks/ai.test.sh"
    ;;
  *)
    # Run all tests
    echo -e "\n${BLUE}Running all stack tests...${NC}"
    source "$REPO_ROOT/tests/stacks/base.test.sh"
    source "$REPO_ROOT/tests/stacks/network.test.sh"
    source "$REPO_ROOT/tests/stacks/sso.test.sh"
    source "$REPO_ROOT/tests/stacks/databases.test.sh"
    source "$REPO_ROOT/tests/stacks/notifications.test.sh"
    source "$REPO_ROOT/tests/stacks/media.test.sh"
    source "$REPO_ROOT/tests/stacks/storage.test.sh"
    source "$REPO_ROOT/tests/stacks/monitoring.test.sh"
    source "$REPO_ROOT/tests/stacks/productivity.test.sh"
    source "$REPO_ROOT/tests/stacks/ai.test.sh"
    ;;
esac

echo -e "${BLUE}"
echo "╔══════════════════════════════════════╗"
echo "║   HomeLab Stack — Integration Tests  ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}\n"

# Run the tests
for test in $(compgen -A function | grep "^test_"); do
  echo -n "[$(basename ${BASH_SOURCE[0]} .test.sh)] ▶ "
  $test
  echo "✅ PASS"
done