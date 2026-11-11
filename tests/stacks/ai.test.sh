#!/usr/bin/env bash
# Stack test suite for 'ai'
if [[ -f "stacks/ai/docker-compose.yml" ]]; then
  validate_stack_static "ai"
fi
assert_container_running "ollama" "Primary service 'ollama' is running"
assert_container_healthy "ollama" "Primary service 'ollama' is healthy"
assert_no_errors "ollama" "No fatal errors in 'ollama' logs"
