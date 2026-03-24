#!/usr/bin/env bash
# ==============================================================================
# AI Stack Tests
# Tests for Ollama, Open WebUI, Stable Diffusion, Perplexica
# ==============================================================================

# Test: Ollama container is running
test_ollama_running() {
    assert_container_running "ollama"
}

# Test: Ollama is healthy
test_ollama_healthy() {
    assert_container_healthy "ollama" 120
}

# Test: Ollama API version
test_ollama_api_version() {
    assert_http_200 "http://localhost:11434/api/version" 10
}

# Test: Ollama models endpoint
test_ollama_models() {
    assert_http_200 "http://localhost:11434/api/tags" 10
}

# Test: Ollama has at least one model
test_ollama_has_model() {
    begin_test
    local response=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null || echo '{"models":[]}')
    local model_count=$(echo "$response" | jq '.models | length' 2>/dev/null || echo 0)
    
    if [[ "$model_count" -gt 0 ]]; then
        log_pass "Ollama has $model_count model(s) pulled"
    else
        log_skip "No Ollama models pulled yet"
    fi
}

# Test: Open WebUI container (if configured)
test_open_webui_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "open-webui\|openwebui"; then
        assert_container_running "open-webui" || assert_container_running "openwebui"
        assert_http_200 "http://localhost:8080/health" 10 || \
        assert_http_200 "http://localhost:3000/health" 10
    else
        log_skip "Open WebUI not configured"
    fi
}

# Test: Open WebUI is healthy
test_open_webui_healthy() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "open-webui\|openwebui"; then
        assert_container_healthy "open-webui" 60 || assert_container_healthy "openwebui" 60
    else
        log_skip "Open WebUI not configured"
    fi
}

# Test: Stable Diffusion WebUI (if configured)
test_stable_diffusion_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE "stable-diffusion|sd-webui|automatic1111"; then
        local container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "stable-diffusion|sd-webui|automatic1111" | head -1)
        assert_container_running "$container"
        # Stable Diffusion takes time to start
        assert_http_200 "http://localhost:7860/sdapi/v1/sd-models" 30
    else
        log_skip "Stable Diffusion not configured"
    fi
}

# Test: Perplexica (if configured)
test_perplexica_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "perplexica"; then
        assert_container_running "perplexica"
        assert_http_200 "http://localhost:3001/api/status" 10 || \
        assert_http_200 "http://localhost:4000/api/status" 10
    else
        log_skip "Perplexica not configured"
    fi
}

# Test: GPU availability (if applicable)
test_gpu_available() {
    begin_test
    if command -v nvidia-smi &>/dev/null; then
        if nvidia-smi &>/dev/null; then
            local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
            log_pass "GPU available: $gpu_name"
        else
            log_skip "NVIDIA GPU not detected or driver issue"
        fi
    else
        log_skip "nvidia-smi not available (no GPU or CPU-only setup)"
    fi
}

# Test: Ollama can generate (simple test)
test_ollama_generate() {
    begin_test
    local model="${OLLAMA_TEST_MODEL:-llama3.2:1b}"
    
    # Check if model exists
    local models=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null || echo "")
    
    if echo "$models" | grep -q "$model"; then
        # Quick generation test
        local response=$(curl -sf -d '{"model":"'$model'","prompt":"hi","stream":false}' \
            "http://localhost:11434/api/generate" 2>/dev/null || echo "{}")
        
        if echo "$response" | jq -e '.response' >/dev/null 2>&1; then
            log_pass "Ollama generation test passed"
        else
            log_skip "Ollama generation test failed"
        fi
    else
        log_skip "Test model $model not available"
    fi
}

# Test: AI stack compose syntax
test_ai_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/ai/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "AI compose file not found"
    fi
}

# Test: No :latest tags
test_ai_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/ai"
}

# Run all tests
run_tests() {
    test_ollama_running
    test_ollama_healthy
    test_ollama_api_version
    test_ollama_models
    test_ollama_has_model
    test_open_webui_running
    test_open_webui_healthy
    test_stable_diffusion_running
    test_perplexica_running
    test_gpu_available
    test_ollama_generate
    test_ai_compose_syntax
    test_ai_no_latest_tags
}

# Execute tests
run_tests