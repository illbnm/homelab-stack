#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests
# =============================================================================

assert_container_running ollama
assert_container_running open-webui

# HTTP endpoints
assert_http_200 "http://localhost:11434/api/version" 10
