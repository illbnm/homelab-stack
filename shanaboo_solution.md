 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +1,7 @@
+# Authentik Configuration
+AUTHENTIK_SECRET_KEY=change-me-to-a-50-char-random-string
+AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
+AUTHENTIK_BOOTSTRAP_PASSWORD=change-me-strong-password
+AUTHENTIK_DB_PASSWORD=change-me-db-password
+AUTHENTIK_DOMAIN=auth.example.com
+DOMAIN=example.com
--- /dev/null
+++ b/config/traefik/dynamic/middlewares.yml
@@ -0,0 +1,10 @@
+http:
+  middlewares:
+    authentik:
+      forwardAuth:
+        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
+        trustForwardHeader: true
+        authResponseHeaders:
+          - X-authentik-username
+          - X-authentik-groups
+          - X-authentik-email
+          - X-authentik-name
--- /dev/null
+++ b/config/grafana/grafana.ini
@@ -0,0 +1,22 @@
+[auth.generic_oauth]
+enabled = true
+name = Authentik
+allow_sign_up = true
+client_id = ${AUTHENTIK_GRAFANA_CLIENT_ID}
+client_secret = ${AUTHENTIK_GRAFANA_CLIENT_SECRET}
+scopes = openid profile email
+auth_url = https://auth.${DOMAIN}/application/o/grafana/oauth/authorize/
+token_url = https://auth.${DOMAIN}/application/o/grafana/oauth/token/
+api_url = https://auth.${DOMAIN}/application/o/grafana/oauth/userinfo/
+role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || contains(groups[*], 'homelab-users') && 'Editor' || 'Viewer'
+auto_assign_org_role = Viewer
+use_pkce = true
+use_refresh_token = true
+
+[auth]
+disable_login_form = false
+disable_signout_menu = false
+
+[security]
+admin_user = admin
+cookie_secure = true
+strict_transport_security = true
--- /dev/null
+++ b/scripts/authentik-setup.sh
@@ -0,0 +1,302 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# Authentik Setup Script
+# Automatically creates OAuth2/OIDC providers and applications
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
+AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN:-example.com}}"
+AUTHENTIK_API="${AUTHENTIK_URL}/api/v3"
+BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL:-admin@example.com}"
+BOOTSTRAP_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD:-admin}"
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+DRY_RUN=false
+if [[ "${1:-}" == "--dry-run" ]]; then
+    DRY_RUN=true
+    echo -e "${YELLOW}[DRY RUN] No changes will be made${NC}"
+fi
+
+# Check dependencies
+command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
+command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
+
+# Wait for Authentik to be ready
+wait_for_authentik() {
+    echo -e "${BLUE}Waiting for Authentik to be ready...${NC}"
+    local max_attempts=30
+    local attempt=0
+    
+    while [[ $attempt -lt $max_attempts ]]; do
+        if curl -sf "${AUTHENTIK_URL}/-/health/ready/" >/dev/null 2>&1; then
+            echo -e "${GREEN}Authentik is ready${NC}"
+            return 0
+        fi
+        attempt=$((attempt + 1))
+        echo "Attempt $attempt/$max_attempts... waiting"
+        sleep 5
+    done
+    
+    echo -e "${RED}Authentik failed to become ready${NC}"
+    return 1
+}
+
+# Get authentication token
+get_token() {
+    local response
+    response=$(curl -sf -X POST \
+        "${AUTHENTIK_API}/core/tokens/" \
+        -H "Content-Type: application/json" \
+        -d "{\"username\":\"${BOOTSTRAP_EMAIL}\",\"password\":\"${BOOTSTRAP_PASSWORD}\"}" 2>/dev/null || true)
+    
+    if [[ -z "$response" ]]; then
+        # Try alternative authentication
+        response=$(curl -sf -X POST \
+            "${AUTHENTIK_URL}/api/v3/core/tokens/" \
+            -H "Content-Type: application/json" \
+            -d "{\"username\":\"${BOOTSTRAP_EMAIL}\",\"password\":\"${BOOTSTRAP_PASSWORD}\"}" 2>/dev/null || true)
+    fi
+    
+    # For now, use a simpler approach with API token from environment
+    echo "${AUTHENTIK_API_TOKEN:-}"
+}
+
+# Create or update provider and application
+create_oidc_provider() {
+    local name="$1"
+    local client_id="$2"
+    local redirect_uris="$3"
+    local group="$4"
+    
+    echo -e "${BLUE}Creating provider: $name${NC}"
+    
+    if $DRY_RUN; then
+        echo -e "${GREEN}[DRY RUN] Would create provider: $name${NC}"
+        echo "  Client ID: $client_id"
+        echo "  Redirect URIs: $redirect_uris"
+        echo "  Group: $group"
+        return 0
+    fi
+    
+    # Generate client secret
+    local client_secret
+    client_secret=$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 64)
+    
+    # Store credentials
+    mkdir -p "$ROOT_DIR/.secrets"
+    cat > "$ROOT_DIR/.secrets/${name,,}-oidc.json" <<EOF