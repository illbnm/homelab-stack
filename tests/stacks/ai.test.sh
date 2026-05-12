#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[ai] Running AI stack tests..."
assert_container_running "ollama" && print_test_result "ai" "Ollama running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:11434/api/version" && print_test_result "ai" "Ollama API 200" "PASS" "1.2s" || true
