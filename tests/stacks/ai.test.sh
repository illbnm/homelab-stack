#!/usr/bin/env bash
# tests/stacks/ai.test.sh

describe "AI Stack (Ollama)"

it "Ollama container is running"
if container_exists "ollama"; then
    assert_container_running "ollama"
    it "Ollama API responds"
    assert_http_200 "http://localhost:11434/api/tags" 15
    it "Ollama is not crash-looping"
    assert_container_restarted "ollama" 3
else
    skip "Ollama not found"
fi
