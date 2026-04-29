#!/usr/bin/env bash
assert_suite "productivity"

test_gitea_running() {
    assert_container_running gitea
}

test_gitea_api() {
    assert_http_response "http://localhost:3000/api/v1/version" '"version"'
}

test_vaultwarden_running() {
    assert_container_running vaultwarden
}

test_outline_running() {
    assert_container_running outline
}

test_bookstack_running() {
    assert_container_running bookstack
}

test_stirling_pdf_running() {
    assert_container_running stirling-pdf
}

test_gitea_running
test_gitea_api
test_vaultwarden_running
test_outline_running
test_bookstack_running
test_stirling_pdf_running