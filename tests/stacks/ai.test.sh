#!/bin/bash
# ai.test.sh - AI Stack 测试
# 测试 Ollama, Open WebUI, LocalAI, n8n

set -u

# Ollama 测试
test_ollama_running() {
    assert_container_running "ollama"
}

test_ollama_api() {
    assert_http_response "http://localhost:11434/api/version" "version" "Ollama API"
}

# Open WebUI 测试
test_openwebui_running() {
    assert_container_running "openwebui"
}

test_openwebui_http() {
    assert_http_200 "http://localhost:3000"
}

# LocalAI 测试
test_localai_running() {
    assert_container_running "localai"
}

test_localai_http() {
    assert_http_200 "http://localhost:8080/readyz"
}

# n8n 测试
test_n8n_running() {
    assert_container_running "n8n"
}

test_n8n_http() {
    assert_http_200 "http://localhost:5678"
}
