#!/bin/bash
# =============================================================================
# Configure Gitea OIDC via Authentik
# Run after both Gitea and Authentik are up
# =============================================================================
set -euo pipefail

DOMAIN="${DOMAIN:?missing_domain}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:?missing_authentik_domain}"
GITEA_URL="https://git.${DOMAIN}"

echo "==> Setting up Gitea OIDC with Authentik"
echo "    Authentik: https://${AUTHENTIK_DOMAIN}"
echo "    Gitea:     ${GITEA_URL}"
echo ""

# Step 1: Create OIDC Application in Authentik
echo "[1/5] Create Authentik OIDC Application"
echo "    Open Authentik admin → Applications → Create"
echo "    Name: Gitea"
echo "    Launch URL: ${GITEA_URL}"
echo "    Redirect URI: ${GITEA_URL}/user/oauth2/Authentik/callback"
echo ""

# Step 2: Get client ID and secret from Authentik
read -rp "    Enter Client ID: " GITEA_OIDC_CLIENT_ID
read -rp "    Enter Client Secret: " GITEA_OIDC_CLIENT_SECRET
echo ""

# Step 3: Configure Gitea via API
echo "[2/5] Configuring Gitea authentication source..."
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-root}"
GITEA_ADMIN_PASS="${GITEA_ADMIN_PASS:-}"

# Create authentication source in Gitea
curl -sf -X POST "${GITEA_URL}/api/v1/admin/auth/sources/oauth2" \
  -H "Content-Type: application/json" \
  -u "${GITEA_ADMIN_USER}" -p "${GITEA_ADMIN_PASS}" \
  -d "{
    \"name\": \"Authentik\",
    \"type\": \"openidConnect\",
    \"is_active\": true,
    \"openidConnect\": {
      \"client_id\": \"${GITEA_OIDC_CLIENT_ID}\",
      \"client_secret\": \"${GITEA_OIDC_CLIENT_SECRET}\",
      \"auto_discovery_url\": \"https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration\",
      \"scopes\": \"openid profile email groups\"
    }
  }" 2>/dev/null && echo "    Authentication source created ✓" || echo "    Failed (may need manual setup)"

# Step 4: Disable registration
echo "[3/5] Registration disabled (admin-only account creation)"
echo "    Already configured via GITEA__service__DISABLE_REGISTRATION=true"
echo ""

# Step 5: Generate runner token
echo "[4/5] Generate Gitea Actions runner token"
echo "    Run: docker exec gitea gitea actions generate-runner-token"
echo "    Then set GITEA_RUNNER_TOKEN in your .env"
echo ""

echo "[5/5] Setup complete!"
echo "    Visit ${GITEA_URL} and verify OIDC login works"
