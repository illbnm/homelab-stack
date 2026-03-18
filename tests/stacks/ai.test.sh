#!/usr/bin/env bash
# ai.test.sh — AI Stack Tests (Ollama, Open WebUI)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/ai/docker-compose.yml}"

test_ollama_running() { test_start "Ollama running"; assert_container_running "ollama"; test_end; }
test_ollama_healthy() { test_start "Ollama healthy"; assert_container_healthy "ollama" 60; test_end; }
test_ollama_api() { test_start "Ollama /api/version"; assert_http_200 "http://localhost:11434/api/version" 15; test_end; }

test_openwebui_running() { test_start "Open WebUI running"; assert_container_running "open-webui"; test_end; }
test_openwebui_healthy() { test_start "Open WebUI healthy"; assert_container_healthy "open-webui" 60; test_end; }
test_openwebui_http() { test_start "Open WebUI HTTP"; assert_http_200 "http://localhost:3000" 15; test_end; }

test_compose_syntax() { test_start "AI compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
