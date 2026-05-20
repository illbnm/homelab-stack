#!/usr/bin/env bash

run_sso_flow_tests() {
  CURRENT_SUITE="sso-flow"
  assert_file_contains "$PROJECT_ROOT/scripts/setup-authentik.sh" 'GRAFANA_OAUTH_CLIENT_ID' "Grafana OIDC client is generated"
  assert_file_contains "$PROJECT_ROOT/scripts/setup-authentik.sh" 'GITEA_OAUTH_CLIENT_ID' "Gitea OIDC client is generated"
  assert_file_contains "$PROJECT_ROOT/scripts/setup-authentik.sh" 'OUTLINE_OAUTH_CLIENT_ID' "Outline OIDC client is generated"
  assert_file_contains "$PROJECT_ROOT/scripts/setup-authentik.sh" 'PORTAINER_OAUTH_CLIENT_ID' "Portainer OIDC client is generated"

  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    assert_not_empty "${AUTHENTIK_DOMAIN:-}" "AUTHENTIK_DOMAIN is configured"
    assert_not_empty "${GRAFANA_OAUTH_CLIENT_ID:-}" "Grafana OAuth client id is configured"
    assert_not_empty "${GITEA_OAUTH_CLIENT_ID:-}" "Gitea OAuth client id is configured"
    assert_not_empty "${OUTLINE_OAUTH_CLIENT_ID:-}" "Outline OAuth client id is configured"
  else
    skip_result ".env contains SSO values" ".env is not present"
  fi

  assert_container_running authentik-server "Authentik server is running for SSO flow"
  assert_container_healthy authentik-server "Authentik server healthcheck is healthy"
}
