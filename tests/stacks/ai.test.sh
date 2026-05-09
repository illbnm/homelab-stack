#!/usr/bin/env bash
assert_suite "ai"

test_ollama_running() {
    assert_container_running ollama
}

test_ollama_api() {
    assert_http_response "http://localhost:11434/api/version" '"version"'
}

test_open_webui_running() {
    assert_container_running open-webui
}

test_ollama_running
test_ollama_api
test_open_webui_running