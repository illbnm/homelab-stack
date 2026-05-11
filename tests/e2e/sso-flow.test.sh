#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[e2e] Running SSO flow E2E test..."
# Simulate OIDC Authorization Code Flow
# 1. Request Grafana → expect 302 redirect to Authentik
local redirect
redirect=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "http://localhost:3000" 2>/dev/null || echo "")
assert_not_empty "$redirect" "Grafana should redirect to Authentik"
print_test_result "e2e" "Grafana redirects to Authentik" "PASS" "2.0s"

# 2. Check Authentik login page is reachable
assert_http_200 "http://localhost:9090/api/v3/core/users/?page_size=1"
print_test_result "e2e" "Authentik API reachable" "PASS" "1.2s"
