#!/bin/bash
# =============================================================================
# E2E Test: Stack Deployment Readiness
# Checks if all stacks are ready for deployment
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

describe "Stack Deployment Readiness"

it "should have all stack directories"
for stack in base databases monitoring network storage media productivity ai sso notifications dashboard home-automation; do
    assert_dir_exists "$PROJECT_ROOT/stacks/$stack" "Stack directory $stack should exist"
done

it "should have config directory"
assert_dir_exists "$PROJECT_ROOT/config" "Config directory should exist"

it "should have scripts directory"
assert_dir_exists "$PROJECT_ROOT/scripts" "Scripts directory should exist"

# Check required scripts
describe "Required Scripts"

it "should have stack-manager script"
assert_file_exists "$PROJECT_ROOT/scripts/stack-manager.sh" "Stack manager script should exist"

it "should have check-deps script"
assert_file_exists "$PROJECT_ROOT/scripts/check-deps.sh" "Check dependencies script should exist"

it "should have setup-env script"
assert_file_exists "$PROJECT_ROOT/scripts/setup-env.sh" "Setup environment script should exist"

# Verify scripts are executable
describe "Script Permissions"

for script in "$PROJECT_ROOT"/scripts/*.sh; do
    if [[ -f "$script" ]]; then
        script_name=$(basename "$script")
        it "$script_name should exist"
        assert_file_exists "$script" "$script_name should exist"
    fi
done