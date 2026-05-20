#!/usr/bin/env bash

run_ai_tests() {
  CURRENT_SUITE="ai"
  assert_stack_static_checks ai
  assert_compose_services_declared ai ollama open-webui stable-diffusion
  assert_stack_containers_running ollama open-webui stable-diffusion
  assert_stack_containers_healthy ollama open-webui stable-diffusion
  assert_file_contains "$(stack_compose_file ai)" 'OLLAMA_BASE_URL=http://ollama:11434' "Open WebUI is wired to Ollama"
  assert_container_on_network open-webui proxy "Open WebUI is attached to proxy network"
}
