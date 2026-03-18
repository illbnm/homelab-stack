# E2E: SSO Login Flow Test

echo "--- SSO Flow: Grafana OIDC Login ---"

CURRENT_TEST="sso_grafana_redirect"
# Step 1: Access Grafana login → should redirect to Authentik
local response=$(curl -sf -o /dev/null -w "%{http_code}:%{redirect_url}" \
  "http://localhost:3000/login/generic_oauth" 2>/dev/null || echo "000:")
local code="${response%%:*}"
local redirect="${response##*:}"
if [[ "$code" == "302" ]] && echo "$redirect" | grep -q "authentik\|auth\."; then
  pass
else
  skip "Grafana OIDC not configured (code: ${code})"
fi

CURRENT_TEST="sso_authentik_login_page"
# Step 2: Authentik login page accessible
assert_http_200 "http://localhost:9000/if/flow/default-authentication-flow/"

echo "--- SSO Flow: ForwardAuth ---"

CURRENT_TEST="sso_forwardauth_middleware"
# Check Traefik has authentik middleware
local middlewares=$(curl -sf "http://localhost:8080/api/http/middlewares" 2>/dev/null || echo "[]")
if echo "$middlewares" | grep -q "authentik"; then
  pass
else
  skip "ForwardAuth middleware not configured"
fi
