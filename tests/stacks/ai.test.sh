#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests
# Tests for Ollama, Open WebUI
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "AI Stack"

# Test containers
container_check ollama
container_check open-webui

# Test HTTP endpoints
http_check Ollama "http://localhost:11434"