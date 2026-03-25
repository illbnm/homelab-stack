#!/bin/bash
# =============================================================================
# ai.test.sh - AI stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    
    docker compose -f stacks/ai/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_ollama_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "ollama" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Ollama running" "$result" $((end - start))
}

test_ollama_healthy() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_healthy "ollama" 60 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Ollama healthy" "$result" $((end - start))
}

test_open_webui_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "open-webui" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Open WebUI running" "$result" $((end - start))
}

test_stable_diffusion_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "stable-diffusion" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Stable Diffusion running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_ollama_running
test_ollama_healthy
test_open_webui_running
test_stable_diffusion_running
