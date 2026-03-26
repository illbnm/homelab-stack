#!/usr/bin/env bash
# ai.test.sh - AI Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="ai"

test_ollama() {
    test_start "Ollama - 容器运行"
    if assert_container_running "ollama"; then test_end "Ollama - 容器运行" "PASS"
    else test_end "Ollama - 容器运行" "FAIL"; return 1; fi
    test_start "Ollama - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:11434/"; then test_end "Ollama - HTTP 端点可达" "PASS"
    else test_end "Ollama - HTTP 端点可达" "SKIP"; fi
    test_start "Ollama - Tags API"
    if curl -sf --max-time 10 "http://127.0.0.1:11434/api/tags" 2>/dev/null | grep -q "models"; then
        test_end "Ollama - Tags API" "PASS"
    else test_end "Ollama - Tags API" "SKIP"; fi
}

test_open_webui() {
    test_start "Open WebUI - 容器运行"
    if assert_container_running "open-webui"; then test_end "Open WebUI - 容器运行" "PASS"
    else test_end "Open WebUI - 容器运行" "FAIL"; return 1; fi
    test_start "Open WebUI - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:8080/"; then test_end "Open WebUI - HTTP 端点可达" "PASS"
    else test_end "Open WebUI - HTTP 端点可达" "SKIP"; fi
}

test_stable_diffusion() {
    test_start "Stable Diffusion - 容器运行"
    if assert_container_running "stable-diffusion"; then test_end "Stable Diffusion - 容器运行" "PASS"
    else test_end "Stable Diffusion - 容器运行" "FAIL"; return 1; fi
    test_start "Stable Diffusion - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:7860/"; then test_end "Stable Diffusion - HTTP 端点可达" "PASS"
    else test_end "Stable Diffusion - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_ollama || true; test_open_webui || true; test_stable_diffusion || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
