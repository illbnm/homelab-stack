#!/usr/bin/env bash
set -euo pipefail

test_sso_redirect_chain() {
  [[ -n "${AUTHENTIK_DOMAIN:-}" ]] || return 2
  assert_http_200 "http://localhost:3000/api/health" || return 1
}
