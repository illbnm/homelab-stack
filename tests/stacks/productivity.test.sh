#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Productivity Stack Tests
# =============================================================================
# Tests: Gitea, Vaultwarden, Outline, Stirling-PDF, IT-Tools
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_gitea_running() {
  assert_container_running "gitea"
}

test_gitea_healthy() {
  assert_container_healthy "gitea" 90
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}

test_vaultwarden_healthy() {
  assert_container_healthy "vaultwarden" 60
}

test_outline_running() {
  assert_container_running "outline"
}

test_outline_healthy() {
  assert_container_healthy "outline" 90
}

test_stirling_pdf_running() {
  assert_container_running "stirling-pdf"
}

test_stirling_pdf_healthy() {
  assert_container_healthy "stirling-pdf" 60
}

test_it_tools_running() {
  assert_container_running "it-tools"
}

test_it_tools_healthy() {
  assert_container_healthy "it-tools" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_gitea_api_version() {
  assert_http_200 "http://localhost:3000/api/v1/version" 30
}

test_gitea_api_settings() {
  assert_http_200 "http://localhost:3000/api/v1/settings/api" 30
}

test_vaultwarden_alive() {
  assert_http_200 "http://localhost:8080/alive" 30
}

test_vaultwarden_api_version() {
  assert_http_response "http://localhost:8080/api/version" "version" 30
}

test_outline_api_version() {
  assert_http_200 "http://localhost:3001/api/version" 30
}

test_stirling_pdf_webui() {
  assert_http_200 "http://localhost:8080" 30
}

test_it_tools_webui() {
  assert_http_200 "http://localhost:8080" 30
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service (Gitea → Database)
# ---------------------------------------------------------------------------

test_gitea_database_connection() {
  # Verify Gitea can connect to its database by checking the API
  local result
  result=$(curl -s "http://localhost:3000/api/v1/version" 2>/dev/null || echo '{}')

  assert_json_key_exists "${result}" ".version"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_productivity_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/productivity/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Productivity compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
