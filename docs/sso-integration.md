# SSO Integration Guide — Authentik

> Complete guide for integrating Authentik SSO with all HomeLab Stack services.

## Overview

HomeLab Stack uses [Authentik](https://goauthentik.io/) as the centralized identity provider.
Two integration methods are used:

| Method | How It Works | Services |
|--------|-------------|----------|
| **OIDC** (native) | Service directly talks to Authentik OAuth2 endpoints | Grafana, Gitea, Outline, BookStack, Nextcloud, Open WebUI, Portainer |
| **ForwardAuth** | Traefik intercepts requests, checks with Authentik before proxying | All other web services |

---

## Quick Start

```bash
# 1. Start SSO stack first
cd stacks/sso
cp .env.example .env && nano .env
docker compose up -d

# 2. Wait for Authentik to be healthy (~60s on first boot)
docker compose ps

# 3. Run the setup script to create all OIDC providers
../../scripts/setup-authentik.sh

# 4. Run the health check
../../scripts/test-sso.sh

# 5. Start other stacks (they will use ForwardAuth + OIDC)
```

---

## Architecture

```
Browser Request
     │
     ▼
┌─────────────────┐
│   Traefik v3    │  ← TLS termination + routing
│   :80 → :443    │
└────────┬────────┘
         │
    Has ForwardAuth middleware?
         │
    ┌────┴────┐
    │         │
   YES        NO
    │         │
    ▼         ▼
┌──────────┐  ┌──────────┐
│ Authentik │  │  Direct   │
│ ForwardAuth│  │  Proxy    │
│ :9000     │  │           │
└─────┬─────┘  └───────────┘
      │
  Authenticated?
      │
  ┌───┴───┐
  │       │
  YES      NO → Redirect to auth.DOMAIN login
  │
  ▼
┌──────────┐
│ Service   │  ← Gets X-authentik-* headers
└──────────┘
```

---

## Service Integration Matrix

### Services with Native OIDC

These services authenticate directly via OAuth2/OIDC. Credentials are auto-generated
by `scripts/setup-authentik.sh` and written to `.env`.

#### Grafana

OIDC is configured via environment variables in `stacks/monitoring/docker-compose.yml`:

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - GF_AUTH_SIGNOUT_REDIRECT_URL=https://${AUTHENTIK_DOMAIN}/application/o/grafana/end-session/
  # Role mapping: map Authentik groups to Grafana roles
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

**Role Mapping**: Create groups in Authentik (`Grafana Admins`, `Grafana Editors`) to
control access levels.

#### Gitea

OIDC configured via Gitea environment variables in `stacks/productivity/docker-compose.yml`:

```yaml
environment:
  - GITEA__oauth2__ENABLE=true
  - GITEA__oauth2__JWT_SECRET=${GITEA_OAUTH2_JWT_SECRET}
```

After setup script runs, add the OAuth2 source in Gitea admin UI:
- **Provider**: OAuth2
- **Name**: Authentik
- **Client ID**: from `.env`
- **Client Secret**: from `.env`
- **Authorization URL**: `https://auth.DOMAIN/application/o/authorize/`
- **Token URL**: `https://auth.DOMAIN/application/o/token/`
- **User Info URL**: `https://auth.DOMAIN/application/o/userinfo/`

#### Outline

Direct OIDC config in `stacks/productivity/docker-compose.yml`:

```yaml
environment:
  - OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - OIDC_LOGOUT_URI=https://${AUTHENTIK_DOMAIN}/application/o/outline/end-session/
  - OIDC_DISPLAY_NAME=Authentik
  - OIDC_SCOPES=openid profile email
```

#### BookStack

OIDC via environment variables in `stacks/productivity/docker-compose.yml`:

```yaml
environment:
  - AUTH_METHOD=oidc
  - OIDC_CLIENT_ID=${BOOKSTACK_OIDC_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${BOOKSTACK_OIDC_CLIENT_SECRET}
  - OIDC_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/bookstack/
  - OIDC_NAME=Authentik
```

#### Nextcloud

Uses the `sociallogin` app for OIDC:

```bash
# Install the app
docker exec -u www-data nextcloud php occ app:install sociallogin

# Configure via occ (or admin UI)
docker exec -u www-data nextcloud php occ config:app:set sociallogin custom_oidc_providers --value='[{
  "name": "Authentik",
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "authorizeUrl": "https://auth.DOMAIN/application/o/authorize/",
  "tokenUrl": "https://auth.DOMAIN/application/o/token/",
  "userInfoUrl": "https://auth.DOMAIN/application/o/userinfo/",
  "logoutUrl": "https://auth.DOMAIN/application/o/nextcloud/end-session/",
  "scopes": "openid profile email",
  "groupsClaim": "groups",
  "style": "Authentik"
}]'
```

#### Open WebUI

OIDC via environment variables in `stacks/ai/docker-compose.yml`:

```yaml
environment:
  - WEBUI_AUTH_TRUSTED_EMAIL_HEADER=X-authentik-email
  - ENABLE_OAUTH_SIGNUP=true
  - OAUTH_PROVIDER_NAME=Authentik
  - OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
  - OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/.well-known/openid-configuration
  - OAUTH_SCOPES=openid profile email
```

#### Portainer

Native OAuth2 support. Configure in Portainer UI after setup:

1. Go to **Settings** → **Authentication**
2. Select **OAuth** → **Custom**
3. Fill in:
   - **Client ID**: from `.env`
   - **Client Secret**: from `.env`
   - **Authorization URL**: `https://auth.DOMAIN/application/o/authorize/`
   - **Access Token URL**: `https://auth.DOMAIN/application/o/token/`
   - **Resource URL**: `https://auth.DOMAIN/application/o/userinfo/`
   - **Redirect URL**: `https://portainer.DOMAIN/`
   - **Logout URL**: `https://auth.DOMAIN/application/o/portainer/end-session/`
   - **User Identifier**: `preferred_username`
   - **Scopes**: `openid profile email`

---

### Services with ForwardAuth Only

These services don't support OIDC natively. Authentik protects them via the
Traefik `forwardAuth` middleware defined in `config/traefik/dynamic/middlewares.yml`.

**How it works:**
1. User visits `service.DOMAIN`
2. Traefik sends the request to Authentik for verification
3. If not logged in → redirect to `auth.DOMAIN` login page
4. After login → Authentik sets session cookie → user is proxied to the service

**Protected services (ForwardAuth applied via Traefik labels):**

| Service | Subdomain | ForwardAuth Label |
|---------|-----------|-------------------|
| Prometheus | prometheus.DOMAIN | `authentik@file` |
| MinIO Console | minio.DOMAIN | `authentik@file` |
| MinIO API | s3.DOMAIN | `authentik@file` |
| FileBrowser | files.DOMAIN | `authentik@file` |
| Homarr | dashboard.DOMAIN | `authentik@file` |
| Homepage | home.DOMAIN | `authentik@file` |
| ntfy | ntfy.DOMAIN | `authentik@file` |
| Apprise | apprise.DOMAIN | `authentik@file` |
| AdGuard Home | adguard.DOMAIN | `authentik@file` |
| Nginx Proxy Manager | npm.DOMAIN | `authentik@file` |
| Home Assistant | ha.DOMAIN | `authentik@file` |
| Node-RED | nodered.DOMAIN | `authentik@file` |
| Zigbee2MQTT | zigbee.DOMAIN | `authentik@file` |
| Stable Diffusion | sd.DOMAIN | `authentik@file` |
| Vaultwarden | vault.DOMAIN | `authentik@file` |

---

## Authentik Groups & Permissions

Create these groups in Authentik admin UI for role-based access:

| Group | Purpose |
|-------|---------|
| `admins` | Full access to all services |
| `Grafana Admins` | Grafana Admin role |
| `Grafana Editors` | Grafana Editor role |
| `media` | Access to Media stack services |
| `ai` | Access to AI stack services |
| `home-automation` | Access to HA stack services |

### Creating groups via API

```bash
# Create a group
curl -X POST "https://auth.DOMAIN/api/v3/core/groups/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "admins", "is_superuser": true, "users": [1]}'
```

---

## Proxy Outpost Configuration

Authentik uses an **embedded outpost** for ForwardAuth. The outpost URL is
configured in `stacks/sso/docker-compose.yml` via Traefik labels:

```yaml
# Outpost route — handles /outpost.goauthentik.io/* for all subdomains
- "traefik.http.routers.authentik-outpost.rule=HostRegexp(`{subdomain:[a-z0-9-]+}.${DOMAIN}`) && PathPrefix(`/outpost.goauthentik.io`)"
- "traefik.http.routers.authentik-outpost.service=authentik"
```

If ForwardAuth is not working, check:
1. Authentik server is healthy: `curl -sf https://auth.DOMAIN/-/health/ready/`
2. Outpost is active in Authentik admin → **Applications** → **Outposts**
3. Traefik can reach `authentik-server:9000` on the `proxy` network

---

## CN Network Notes

If `ghcr.io` is inaccessible in China, uncomment the CN mirror line in
`stacks/sso/docker-compose.yml`:

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

For other mirrors, run `./scripts/cn-pull.sh` to pre-pull images.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Redirect loop | Outpost using public URL | Ensure address is `http://authentik-server:9000` |
| 401 from ForwardAuth | Outpost not active | Check Authentik admin → Outposts → ensure embedded outpost is running |
| OIDC callback mismatch | Wrong redirect URI | Verify redirect URI matches exactly in Authentik provider config |
| "Invalid client" | Client ID/secret mismatch | Re-run `setup-authentik.sh` or check `.env` values |
| Login page not loading | Authentik not ready | Wait 60s for first boot; check `docker compose logs` |
| Group claims missing | Scopes not requested | Ensure `groups` scope is included in provider config |

---

## File Reference

| File | Purpose |
|------|---------|
| `stacks/sso/docker-compose.yml` | Authentik server + worker + PG + Redis |
| `stacks/sso/.env.example` | SSO environment variables template |
| `config/traefik/dynamic/authentik.yml` | ForwardAuth middleware definition |
| `config/traefik/dynamic/middlewares.yml` | All middlewares including authentik |
| `scripts/setup-authentik.sh` | Creates OIDC providers + applications |
| `scripts/test-sso.sh` | SSO health check script |
| `docs/sso-integration.md` | This file |
