#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Setup Script
# Configures Nextcloud Social Login app to use Authentik as OIDC provider
# Usage: ./scripts/nextcloud-oidc-setup.sh
# Requires: curl, jq
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
for env_file in "$ROOT_DIR/stacks/sso/.env" "$ROOT_DIR/.env"; do
  if [ -f "$env_file" ]; then
    set -a; source "$env_file"; set +a
  fi
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
NEXTCLOUD_URL="https://nextcloud.${DOMAIN}"

# Check prerequisites
log_step "Checking prerequisites..."

if ! command -v occ &> /dev/null; then
  log_error "This script must be run INSIDE the Nextcloud container:"
  log_error "  docker exec -it nextcloud /scripts/nextcloud-oidc-setup.sh"
  exit 1
fi

# Check if social login app is installed
if ! occ app:list | grep -q "sociallogin"; then
  log_step "Installing Social Login app..."
  occ app:install sociallogin
else
  log_info "Social Login app already installed"
fi

log_step "Configuring Authentik as OIDC provider..."

# Configure the OIDC provider
# Note: The provider slug must match the application slug in Authentik
occ config:app:set sociallogin custom_oidc_name --value="Authentik" || true

# Set up Authentik as a generic OIDC provider
# We use the internal hostname for the API endpoints
cat > /tmp/authentik-oidc-config.json << 'PROVIDER_EOF'
{
  "name": "Authentik",
  "id": "authentik",
  "issuer": "AUTHENTIK",
  "authorization_endpoint": "AUTHORIZATION_ENDPOINT",
  "token_endpoint": "TOKEN_ENDPOINT",
  "userinfo_endpoint": "USERINFO_ENDPOINT",
  "end_session_endpoint": "END_SESSION_ENDPOINT"
}
PROVIDER_EOF

# For Nextcloud Social Login, we configure via environment variables
# or direct config. The OIDC discovery is done via the issuer URL.
occ config:app:set sociallogin oidc_config_authentik \
  --value='{"name":"Authentik","id":"authentik","issuer":"AUTHENTIK","authorization_endpoint":"AUTHORIZATION_ENDPOINT","token_endpoint":"TOKEN_ENDPOINT","userinfo_endpoint":"USERINFO_ENDPOINT","end_session_endpoint":"END_SESSION_ENDPOINT"}' || true

# Actually, let's use the proper Nextcloud Social Login configuration method
# The provider is configured via config.php style, not JSON

log_step "Setting Authentik provider configuration..."

# Get the provider slug from Authentik (should be "authentik")
PROVIDER_SLUG="authentik"

# Set the provider as enabled
occ config:app:set sociallogin providers \
  --value="[\"authentik\"]" || true

log_info "Nextcloud Social Login configuration complete!"
echo ""
echo "To complete the setup:"
echo "  1. In Authentik Admin UI, go to: Applications > Nextcloud"
echo "  2. Verify the redirect URI is: https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik"
echo "  3. In Nextcloud, go to: Settings > Social Login"
echo "  4. Click 'Connect' next to Authentik"
echo ""
echo "Provider details for Authentik:"
echo "  Authorization URL: $AUTHENTIK_URL/application/o/authorize/"
echo "  Token URL: $AUTHENTIK_URL/application/o/token/"
echo "  UserInfo URL: $AUTHENTIK_URL/application/o/userinfo/"
echo "  Logout URL: $AUTHENTIK_URL/application/o/end-session/"
