#!/bin/bash
# =============================================================================
# E2E Test: Configuration Validation
# Validates all configuration files are properly formatted
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

describe "Configuration File Validation"

it "should have .env.example file"
assert_file_exists "$PROJECT_ROOT/.env.example" ".env.example should exist"

# Check all compose files are valid
describe "All Docker Compose Files Validation"

for compose_file in "$PROJECT_ROOT/stacks"/*/docker-compose.yml; do
    if [[ -f "$compose_file" ]]; then
        stack_name=$(basename "$(dirname "$compose_file")")
        it "should validate $stack_name stack"
        assert_docker_compose_valid "$compose_file" "$stack_name compose file should be valid"
    fi
done

# Check all YAML config files
describe "YAML Configuration Files"

for yaml_file in "$PROJECT_ROOT/config"/*/*/*.yml "$PROJECT_ROOT/config"/*/*.yml; do
    if [[ -f "$yaml_file" ]]; then
        relative_path="${yaml_file#$PROJECT_ROOT/}"
        it "should validate $relative_path"
        assert_yaml_valid "$yaml_file" "$relative_path should be valid YAML"
    fi
done