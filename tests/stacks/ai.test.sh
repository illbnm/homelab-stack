#!/usr/bin/env bash
# AI Stack Tests — Ollama, Open WebUI, Stable Diffusion
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "AI Stack"

section "Ollama"
assert_container_running "Ollama running" "ollama"
assert_http_2xx "Ollama API /api/tags" "http://localhost:11434/api/tags" || true

section "Open WebUI"
assert_container_running "Open WebUI running" "open-webui"
assert_http_2xx "Open WebUI health" "http://localhost:8080/health" || true

section "Stable Diffusion"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^stable-diffusion$"; then
  assert_container_running "Stable Diffusion running" "stable-diffusion"
  # SD WebUI typically on port 7860
  assert_http_2xx "SD WebUI HTTP" "http://localhost:7860/" || true
else
  skip "Stable Diffusion not deployed"
fi

assert_summary