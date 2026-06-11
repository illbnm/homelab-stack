 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +1,13 @@
+# Authentik Configuration
+AUTHENTIK_SECRET_KEY=change-me-to-a-50-char-random-string
+AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
+AUTHENTIK_BOOTSTRAP_PASSWORD=change-me-strong-password
+AUTHENTIK_DB_PASSWORD=change-me-db-password
+AUTHENTIK_DOMAIN=auth.example.com
+
+# Service Domain (used for redirect URIs)
+DOMAIN=example.com
+
+# Stack-specific Authentik OIDC settings (populated by authentik-setup.sh)
+# GRAFANA_CLIENT_ID=
+# GRAFANA_CLIENT_SECRET=
+# ... etc
--- /dev/null
+++ b/scripts/authentik-setup.sh
@@ -0,0 +1,320 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# Authentik Setup Script
+# Automatically creates OAuth2/OIDC providers and applications for all services
+# Usage: ./scripts/authentik-setup.sh [--dry-run]
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(dirname "$SCRIPT_DIR")"
+
+# Load environment variables
+if [[ -f "$ROOT_DIR/.env" ]]; then
+    source "$ROOT_DIR/.env"
+elif [[ -f "$ROOT_DIR/.env.example" ]]; then
+    source "$ROOT_DIR/.env.example"
+fi
+
+# Configuration
+AUTHENTIK_URL="${AUTHENTIK_URL:-http://auth.${DOMAIN}}"
+AUTHENTIK_API="${AUTHENTIK_URL}/api/v3"
+AUTHENTIK_BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL:-admin@example.com}"
+AUTHENTIK_BOOTSTRAP_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD:-admin}"
+
+DRY_RUN=false
+if [[ "${1:-}" == "--dry-run" ]]; then
+    DRY_RUN=true
+    echo "[DRY-RUN] Preview mode - no changes will be made"
+fi
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# Services configuration
+declare -A SERVICES
+SERVICES=(
+    ["grafana"]="Grafana|https://grafana.${DOMAIN}/login/generic_oauth|openid profile email groups"
+    ["gitea"]="Gitea|https://gitea.${DOMAIN}/user/oauth/Authentik/callback|openid profile email groups"
+    ["nextcloud"]="Nextcloud|https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik|openid profile email groups"
+    ["outline"]="Outline|https://outline.${DOMAIN}/auth/oidc.callback|openid profile email"
+    ["openwebui"]="Open WebUI|https://openwebui.${DOMAIN}/oauth/oidc/callback|openid profile email"
+    ["portainer"]="Portainer|https://portainer.${DOMAIN}/|openid profile email"
+)
+
+# Check dependencies
+check_deps() {
+    local deps=("curl" "jq")
+    for dep in "${deps[@]}"; do
+        if ! command -v "$dep" &> /dev/null; then
+            echo -e "${RED}[ERROR]${NC} Missing dependency: $dep"
+            exit 1
+        fi
+    done
+}
+
+# Wait for Authentik to be ready
+wait_for_authentik() {
+    echo -e "${BLUE}[INFO]${NC} Waiting for Authentik at ${AUTHENTIK_URL}..."
+    local retries=30
+    local count=0
+    while [[ $count -lt $retries ]]; do
+        if curl -sf "${AUTHENTIK_URL}/-/health/ready/" > /dev/null 2>&1; then
+            echo -e "${GREEN}[OK]${NC} Authentik is ready"
+            return 0
+        fi
+        count=$((count + 1))
+        echo -e "${YELLOW}[WAIT]${NC} Attempt $count/$retries - Authentik not ready yet..."
+        sleep 5
+    done
+    echo -e "${RED}[ERROR]${NC} Authentik did not become ready in time"
+    return 1
+}
+
+# Get authentication token
+get_token() {
+    local response
+    response=$(curl -sf -X POST "${AUTHENTIK_API}/core/tokens/" \
+        -H "Content-Type: application/json" \
+        -d "{\"username\":\"${AUTHENTIK_BOOTSTRAP_EMAIL}\",\"password\":\"${AUTHENTIK_BOOTSTRAP_PASSWORD}\"}" 2>/dev/null || true)
+    
+    # Fallback to basic auth for API
+    local token_response
+    token_response=$(curl -sf -X POST "${AUTHENTIK_URL}/api/v3/core/tokens/" \
+        -u "${AUTHENTIK_BOOTSTRAP_EMAIL}:${AUTHENTIK_BOOTSTRAP_PASSWORD}" \
+        -H "Content-Type: application/json" \
+        -d "{\"identifier\":\"setup-script-$(date +%s)\",\"intent\":\"api\",\"expiring\":true}" 2>/dev/null || true)
+    
+    # Use basic auth directly for most endpoints
+    echo "basic"
+}
+
+# Create or update OAuth2/OIDC Provider
+create_provider() {
+    local service_name="$1"
+    local redirect_uri="$2"
+    local scopes="$3"
+    
+    local provider_name="${service_name}-provider"
+    local app_name="${service_name}"
+    
+    if [[ "$DRY_RUN" == true ]]; then
+        echo -e "${YELLOW}[DRY-RUN]${NC} Would create provider: ${provider_name}"
+        echo -e "  Redirect URI: ${redirect_uri}"
+        echo -e "  Scopes: ${scopes}"
+        return 0
+    fi
+    
+    # Generate client credentials
+    local client_id
+    local client_secret
+    client_id="authentik-${service_name}-$(openssl rand -hex 8 2>/dev/null || date +%s | sha256sum | head -c 16)"
+    client_secret="$(openssl rand -hex 32 2>/dev/null || date +%s | sha256sum | head -c 64)"
+    
+    # Create OAuth2 Provider via API
+    local provider_payload
+    provider_payload=$(cat <<EOF
+{
+    "name": "${provider_name}",
+    "authorization_flow": "$(get_flow 'default-provider-authorization-implicit-consent')",
+    "property_mappings": $(get_property