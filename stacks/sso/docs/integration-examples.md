# 🔗 Authentik SSO Integration Examples

Complete integration guides for every service in the homelab stack.

> **Prerequisites:** Authentik is running at `https://auth.${DOMAIN}` and you have run `./scripts/authentik-setup.sh` to obtain client credentials.

---

## Table of Contents

1. [Grafana — OIDC](#1-grafana--oidc)
2. [Gitea — OIDC](#2-gitea--oidc)
3. [Nextcloud — OIDC (Social Login)](#3-nextcloud--oidc-social-login)
4. [Outline — OIDC](#4-outline--oidc)
5. [Open WebUI — OIDC](#5-open-webui--oidc)
6. [Portainer — OAuth2](#6-portainer--oauth2)
7. [Traefik ForwardAuth — Any Service](#7-traefik-forwardauth--any-service)
8. [Adding a New Service](#8-adding-a-new-service)

---

## 1. Grafana — OIDC

**Create provider in Authentik:**
1. Admin UI → Providers → Create → OAuth2/OpenID Provider
2. Name: `Grafana`, Client type: `Confidential`
3. Redirect URIs: `https://grafana.${DOMAIN}/login/generic_oauth`
4. Scopes: `openid`, `email`, `profile`
5. Note the Client ID and Client Secret

**Configure `config/grafana/grafana.ini`:**

```ini
[server]
root_url = https://grafana.${DOMAIN}

[auth]
disable_login_form = false       # Keep enabled as fallback
oauth_auto_login = false

[auth.generic_oauth]
enabled = true
name = Authentik
icon = signin
client_id = ${GRAFANA_OAUTH_CLIENT_ID}
client_secret = ${GRAFANA_OAUTH_CLIENT_SECRET}
scopes = openid email profile
empty_scopes = false
auth_url = https://auth.${DOMAIN}/application/o/grafana/authorize/
token_url = https://auth.${DOMAIN}/application/o/grafana/token/
api_url = https://auth.${DOMAIN}/application/o/userinfo/
login_attribute_path = preferred_username
groups_attribute_path = groups
name_attribute_path = name
use_auto_assign_org = true
auto_assign_org_id = 1
auto_assign_org_role = Viewer
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || 'Viewer'
allow_sign_up = true
tls_skip_verify_insecure = false
```

**Environment variables (added to `stacks/monitoring/.env` or root `.env`):**

```env
GRAFANA_OAUTH_CLIENT_ID=<from authentik-setup.sh>
GRAFANA_OAUTH_CLIENT_SECRET=<from authentik-setup.sh>
```

**Test:** Visit `https://grafana.${DOMAIN}` → click "Sign in with Authentik" → redirects to Authentik login → returns to Grafana dashboard.

---

## 2. Gitea — OIDC

**Create provider in Authentik:**
1. Provider name: `Gitea`, Client type: `Confidential`
2. Redirect URIs: `https://gitea.${DOMAIN}/user/oauth2/authentik/callback`
3. Scopes: `openid`, `email`, `profile`

**Option A — Via Gitea Web UI (Admin):**

Navigate to Site Administration → Authentication Sources → Add Authentication Source:
- Type: `OAuth2`
- Authentication Name: `authentik`
- OAuth2 Provider: `OpenID Connect`
- Client ID: `${GITEA_OAUTH_CLIENT_ID}`
- Client Secret: `${GITEA_OAUTH_CLIENT_SECRET}`
- OpenID Connect Auto Discovery URL: `https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration`

**Option B — Via `stacks/productivity/.env`:**

```env
GITEA_OAUTH_CLIENT_ID=<from authentik-setup.sh>
GITEA_OAUTH_CLIENT_SECRET=<from authentik-setup.sh>
GITEA_OAUTH_DISCOVERY_URL=https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration
```

Then bootstrap via CLI (add to Gitea startup):
```bash
gitea admin auth add-oauth \
  --name authentik \
  --provider openidConnect \
  --key "${GITEA_OAUTH_CLIENT_ID}" \
  --secret "${GITEA_OAUTH_CLIENT_SECRET}" \
  --auto-discover-url "https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration" \
  --scopes "openid email profile"
```

**Test:** Visit `https://gitea.${DOMAIN}` → Sign In → "Sign in with authentik".

---

## 3. Nextcloud — OIDC (Social Login)

**Create provider in Authentik:**
1. Provider name: `Nextcloud`, Client type: `Confidential`
2. Redirect URIs: `https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik`
3. Scopes: `openid`, `email`, `profile`

**`scripts/nextcloud-oidc-setup.sh`:**

```bash
#!/usr/bin/env bash
# Configure Nextcloud OIDC via Social Login app
# Run: ./scripts/nextcloud-oidc-setup.sh

set -euo pipefail
source .env

NEXTCLOUD_URL="https://nextcloud.${DOMAIN}"
CONTAINER="nextcloud"

echo "Installing Social Login app..."
docker exec -u www-data "${CONTAINER}" php occ app:install sociallogin 2>/dev/null || true
docker exec -u www-data "${CONTAINER}" php occ app:enable sociallogin

echo "Configuring Authentik OIDC..."
docker exec -u www-data "${CONTAINER}" php occ config:app:set sociallogin custom_providers \
  --value='[{
    "name": "authentik",
    "title": "Authentik SSO",
    "clientId": "'"${NEXTCLOUD_OAUTH_CLIENT_ID}"'",
    "clientSecret": "'"${NEXTCLOUD_OAUTH_CLIENT_SECRET}"'",
    "discoveryUrl": "https://auth.'"${DOMAIN}"'/application/o/nextcloud/.well-known/openid-configuration",
    "scope": "openid email profile",
    "groupsClaim": "groups",
    "style": "openid"
  }]'

echo "[OK] Nextcloud OIDC configured. Visit ${NEXTCLOUD_URL}/login to test."
```

Make executable and run:
```bash
chmod +x scripts/nextcloud-oidc-setup.sh
./scripts/nextcloud-oidc-setup.sh
```

---

## 4. Outline — OIDC

**Create provider in Authentik:**
1. Provider name: `Outline`, Client type: `Confidential`
2. Redirect URIs: `https://outline.${DOMAIN}/auth/oidc.callback`
3. Scopes: `openid`, `email`, `profile`

**`stacks/productivity/.env` additions:**

```env
# Outline OIDC
OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://auth.${DOMAIN}/application/o/outline/authorize/
OIDC_TOKEN_URI=https://auth.${DOMAIN}/application/o/outline/token/
OIDC_USERINFO_URI=https://auth.${DOMAIN}/application/o/userinfo/
OIDC_USERNAME_CLAIM=preferred_username
OIDC_DISPLAY_NAME=Authentik SSO
OIDC_SCOPES=openid email profile
```

**Test:** Visit `https://outline.${DOMAIN}` → "Continue with Authentik SSO".

---

## 5. Open WebUI — OIDC

**Create provider in Authentik:**
1. Provider name: `OpenWebUI`, Client type: `Confidential`
2. Redirect URIs: `https://chat.${DOMAIN}/oauth/oidc/callback`
3. Scopes: `openid`, `email`, `profile`

**`stacks/ai/.env` additions:**

```env
# Open WebUI OIDC
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
OAUTH_PROVIDER_NAME=Authentik
OPENID_PROVIDER_URL=https://auth.${DOMAIN}/application/o/openwebui/.well-known/openid-configuration
OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
OAUTH_SCOPES=openid email profile
OAUTH_USERNAME_CLAIM=preferred_username
```

**Test:** Visit `https://chat.${DOMAIN}` → "Sign in with Authentik".

---

## 6. Portainer — OAuth2

**Create provider in Authentik:**
1. Provider name: `Portainer`, Client type: `Confidential`
2. Redirect URIs: `https://portainer.${DOMAIN}`
3. Scopes: `openid`, `email`, `profile`

**Configure in Portainer UI:**

Navigate to Settings → Authentication → OAuth:

| Field | Value |
|-------|-------|
| Use SSO | ✅ |
| Client ID | `${PORTAINER_OAUTH_CLIENT_ID}` |
| Client Secret | `${PORTAINER_OAUTH_CLIENT_SECRET}` |
| Authorization URL | `https://auth.${DOMAIN}/application/o/portainer/authorize/` |
| Access Token URL | `https://auth.${DOMAIN}/application/o/portainer/token/` |
| Resource URL | `https://auth.${DOMAIN}/application/o/userinfo/` |
| Redirect URL | `https://portainer.${DOMAIN}` |
| User identifier | `preferred_username` |
| Scopes | `openid email profile` |
| Auth style | `In params` |

**Auto-create users on OAuth login:** Enable in the same settings page.

**`stacks/base/.env` additions:**

```env
PORTAINER_OAUTH_CLIENT_ID=<from authentik-setup.sh>
PORTAINER_OAUTH_CLIENT_SECRET=<from authentik-setup.sh>
```

**Test:** Visit `https://portainer.${DOMAIN}` → click OAuth login button.

---

## 7. Traefik ForwardAuth — Any Service

Use this for services that **don't support OIDC natively** (e.g. Home Assistant, Prometheus, Alertmanager).

### Configuration file

**`config/traefik/dynamic/middlewares.yml`:**

```yaml
http:
  middlewares:
    # Authentik ForwardAuth — requires login for all requests
    authentik:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version

    # Chain: HTTPS redirect + Authentik auth
    secured:
      chain:
        middlewares:
          - https-redirect
          - authentik

    # HTTPS redirect only (no auth)
    https-redirect:
      redirectScheme:
        scheme: https
        permanent: true
```

### Authentik Outpost Setup

ForwardAuth requires a **Proxy Outpost** in Authentik:

1. Admin UI → Applications → Outposts → Create
2. Name: `homelab-proxy`, Type: `Proxy`
3. Add the applications you want protected
4. The outpost integrates with the deployed `authentik-worker` container

### Apply to a service

Add to the service's Traefik labels:

```yaml
services:
  prometheus:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.${DOMAIN}`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure"
      - "traefik.http.routers.prometheus.tls.certresolver=letsencrypt"
      - "traefik.http.routers.prometheus.middlewares=authentik@file"   # ← add this
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
```

### Protecting the Authentik domain itself (outpost catch-all)

The `authentik-server` service already exposes a catch-all route for `*.${DOMAIN}/outpost.goauthentik.io/*` so the ForwardAuth callback works across all subdomains.

---

## 8. Adding a New Service

### Checklist

```
[ ] 1. Create provider in Authentik (OAuth2/OpenID or SAML)
[ ] 2. Set redirect URI to the service's callback URL
[ ] 3. Create Application, link provider, set icon/slug
[ ] 4. Add Policy Binding to restrict to appropriate group
[ ] 5. Copy Client ID + Secret to .env
[ ] 6. Configure the service (env vars or UI)
[ ] 7. Test login flow end-to-end
[ ] 8. Optionally apply ForwardAuth if service lacks native OIDC
```

### Common redirect URI patterns

| Service | Redirect URI pattern |
|---------|---------------------|
| Generic web app | `https://app.${DOMAIN}/oauth/callback` |
| Grafana | `https://grafana.${DOMAIN}/login/generic_oauth` |
| Gitea | `https://gitea.${DOMAIN}/user/oauth2/<name>/callback` |
| Nextcloud | `https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/<name>` |
| Outline | `https://outline.${DOMAIN}/auth/oidc.callback` |
| Portainer | `https://portainer.${DOMAIN}` |
| Open WebUI | `https://chat.${DOMAIN}/oauth/oidc/callback` |
| Jellyfin (SSO plugin) | `https://jellyfin.${DOMAIN}/sso/OID/redirect/authentik` |

### Discovery URL (auto-configuration)

Many services support OIDC discovery — just provide:
```
https://auth.${DOMAIN}/application/o/<slug>/.well-known/openid-configuration
```

### Policy bindings (group-based access control)

Restrict which groups can access each application:

1. Admin UI → Applications → [App] → Policy / Group / User Bindings
2. Click Bind existing policy
3. Choose policy type: **Group Membership Policy**
4. Select group: `homelab-admins` or `homelab-users` or `media-users`
5. Order: 0, Timeout: 30

Users not in the bound group will see "Permission denied" from Authentik.

---

## 🔑 OIDC Endpoints Reference

| Endpoint | URL |
|----------|-----|
| Discovery | `https://auth.${DOMAIN}/application/o/<slug>/.well-known/openid-configuration` |
| Authorization | `https://auth.${DOMAIN}/application/o/<slug>/authorize/` |
| Token | `https://auth.${DOMAIN}/application/o/<slug>/token/` |
| Userinfo | `https://auth.${DOMAIN}/application/o/userinfo/` |
| JWKS | `https://auth.${DOMAIN}/application/o/<slug>/jwks/` |
| End session | `https://auth.${DOMAIN}/application/o/<slug>/end-session/` |
| ForwardAuth | `http://authentik-server:9000/outpost.goauthentik.io/auth/traefik` |
