#!/bin/bash
# productivity.test.sh - Productivity Stack 测试
# 测试 Gitea, Vaultwarden, Outline, Stirling-PDF, IT-Tools

set -u

# Gitea 测试
test_gitea_running() {
    assert_container_running "gitea"
}

test_gitea_api() {
    assert_http_response "http://localhost:3000/api/v1/version" "version" "Gitea API"
}

test_gitea_http() {
    assert_http_200 "http://localhost:3000"
}

# Vaultwarden 测试
test_vaultwarden_running() {
    assert_container_running "vaultwarden"
}

test_vaultwarden_http() {
    assert_http_200 "http://localhost:8000"
}

# Outline 测试
test_outline_running() {
    assert_container_running "outline"
}

test_outline_http() {
    assert_http_200 "http://localhost:3000"
}

# Stirling-PDF 测试
test_stirling_pdf_running() {
    assert_container_running "stirling-pdf"
}

test_stirling_pdf_http() {
    assert_http_200 "http://localhost:8080"
}

# IT-Tools 测试
test_it_tools_running() {
    assert_container_running "it-tools"
}

test_it_tools_http() {
    assert_http_200 "http://localhost:8082"
}
