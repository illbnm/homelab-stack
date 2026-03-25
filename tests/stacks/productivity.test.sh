#!/bin/bash
# =============================================================================
# productivity.test.sh - Productivity stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    docker compose -f stacks/productivity/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_gitea_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "gitea" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Gitea running" "$result" $((end - start))
}

test_vaultwarden_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "vaultwarden" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Vaultwarden running" "$result" $((end - start))
}

test_outline_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "outline" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Outline running" "$result" $((end - start))
}

test_stirling_pdf_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "stirling-pdf" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Stirling PDF running" "$result" $((end - start))
}

test_excalidraw_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "excalidraw" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Excalidraw running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_gitea_running
test_vaultwarden_running
test_outline_running
test_stirling_pdf_running
test_excalidraw_running
