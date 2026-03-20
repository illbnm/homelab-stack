#!/bin/bash

# HTTP endpoint tests
# Source the assertion library
source "${BASH_SOURCE%/*/*}/lib/assert.sh"

# Test Traefik API
test_traefik_api() {
    assert_http_200 "http://localhost:8080/api/version" "Traefik API should return 200"
}

# Test Portainer API
test_portainer_api() {
    assert_http_200 "http://localhost:9000/api/status" "Portainer API should return 200"
}

# Test Grafana API (if present)
test_grafana_api() {
    if docker ps --format "table {{.Names}}" | grep -q "grafana"; then
        assert_http_200 "http://localhost:3000/api/health" "Grafana API should return 200"
    fi
}

# Test Authentik API (if present)
test_authentik_api() {
    if docker ps --format "table {{.Names}}" | grep -q "authentik"; then
        assert_http_200 "http://localhost:9000/api/v3/core/users/?page_size=1" "Authentik API should return 200"
    fi
}

# Test AdGuard API (if present)
test_adguard_api() {
    if docker ps --format "table {{.Names}}" | grep -q "adguard"; then
        assert_http_200 "http://localhost:3000/control/status" "AdGuard API should return 200"
    fi
}

# Test Gitea API (if present)
test_gitea_api() {
    if docker ps --format "table {{.Names}}" | grep -q "gitea"; then
        assert_http_200 "http://localhost:3000/api/v1/version" "Gitea API should return 200"
    fi
}

# Test Ollama API (if present)
test_ollama_api() {
    if docker ps --format "table {{.Names}}" | grep -q "ollama"; then
        assert_http_200 "http://localhost:3000/api/version" "Ollama API should return 200"
    fi
}

# Test Nextcloud Status (if present)
test_nextcloud_status() {
    if docker ps --format "table {{.Names}}" | grep -q "nextcloud"; then
        assert_http_200 "http://localhost:3000/status.php" "Nextcloud status should return 200"
    fi
}

# Test Prometheus Health (if present)
test_prometheus_health() {
    if docker ps --format "table {{.Names}}" | grep -q "prometheus"; then
        assert_http_200 "http://localhost:3000/-/healthy" "Prometheus health should return 200"
    fi
}

# Run all tests
main() {
    test_traefik_api
    test_portainer_api
    test_grafana_api
    test_authentik_api
    test_adguard_api
    test_gitea_api
    test_ollama_api
    test_nextcloud_status
    test_prometheus_health
}

main "$@"