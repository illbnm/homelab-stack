# SSO Integration Guide

> How to integrate new services with Authentik SSO

This guide explains how to add SSO (Single Sign-On) support to any service in the HomeLab Stack using Authentik as the identity provider.

---

## Overview

The HomeLab Stack uses **Authentik** as the central identity provider supporting:
- **OIDC** (OpenID Connect) - modern standard, supported by most services
- **OAuth2** - used by some services (Portainer)
- **SAML** - alternative enterprise protocol
- **ForwardAuth** - middleware for services without native OIDC support

---

## Quick Start

### 1. Deploy SSO Stack

```bash
# Copy and configure environment
cp stacks/sso/.env.example stacks/sso/.env
nano stacks/sso/.env

# Start SSO stack
docker compose -f stacks/sso/docker-compose.yml up -d

# Wait ~60s for first boot, then run setup script
./scripts/setup-authentik.sh
```

### 2. Get API Token

After Authentik starts:
1. Visit `https://auth.yourdomain.com`
2. Login with bootstrap credentials
3. Go to **Directory → Tokens**
4. Create a new token with **"Write"** permissions
5. Copy token to `.env` as `AUTHENTIK_BOOTSTRAP_TOKEN`

---

## Service Integration Checklist

For each new service, you need to:

- [ ] **Create OIDC Provider** in Authentik (via `setup-authentik.sh`)
- [ ] **Add environment variables** to service's `.env`
- [ ] **Configure docker-compose.yml** with OIDC settings
- [ ] **Test login flow**

---

## OIDC Provider Setup

The `setup-authentik.sh` script automatically creates:
1. OAuth2 Provider in Authentik
2. Application entry with correct redirect URIs
3. Client credentials written to `.env`

### Supported Services

| Service | Config Location | Redirect URI |
|---------|----------------|--------------|
| Grafana | stacks/monitoring/ | `https://grafana.domain/login/generic_oauth` |
| Gitea | stacks/productivity/ | `https://git.domain/user/oauth2/Authentik/callback` |
| Outline | stacks/productivity/ | `https://docs.domain/auth/oidc.callback` |
| Portainer | stacks/base/ | `https://portainer.domain/oauth/redirect` |
| Open WebUI | stacks/ai/ | `https://ai.domain/oauth/oidc/callback` |
| Nextcloud | stacks/storage/ | `https://cloud.domain/apps/oidc_login/oidc` |
| Bookstack | stacks/productivity/ | `https://wiki.domain/login/oidc/Authentik/callback` |

---

## Adding a New Service

### Step 1: Add Provider Creation

Edit `scripts/setup-authentik.sh` and add:

```bash
create_oidc_provider \
  "ServiceName" \
  "https://service.${DOMAIN}/oauth/callback" \
  "SERVICE_OAUTH_CLIENT_ID" \
  "SERVICE_OAUTH_CLIENT_SECRET"
```

### Step 2: Update .env.example

Add the service's OAuth variables:
```
SERVICE_OAUTH_CLIENT_ID=
SERVICE_OAUTH_CLIENT_SECRET=
```

### Step 3: Configure docker-compose.yml

Add OIDC environment variables to the service:

```yaml
services:
  myservice:
    environment:
      - OIDC_ENABLED=true
      - OIDC_CLIENT_ID=${SERVICE_OAUTH_CLIENT_ID}
      - OIDC_CLIENT_SECRET=${SERVICE_OAUTH_CLIENT_SECRET}
      - OIDC_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/servicename/
      - OIDC_REDIRECT_URI=https://service.${DOMAIN}/oauth/callback
      - OIDC_SCOPES=openid profile email
```

### Step 4: Test

1. Run setup script: `./scripts/setup-authentik.sh`
2. Restart service: `docker compose -f stacks/xxx/docker-compose.yml restart`
3. Visit service and try "Login with Authentik"

---

## ForwardAuth for Non-OIDC Services

For services without native OIDC support, use Traefik's ForwardAuth middleware:

### Usage

Add middleware label to any service in `docker-compose.yml`:

```yaml
labels:
  - "traefik.http.routers.myservice.middlewares=authentik@file,security-headers@file"
```

The `authentik@file` middleware is defined in `config/traefik/dynamic/middlewares.yml`.

### How It Works

1. User visits `https://service.domain`
2. Traefik intercepts and forwards to Authentik
3. If not authenticated, Authentik shows login page
4. After login, Authentik sends headers back to Traefik
5. Traefik forwards request with auth headers to backend

### Available Headers

ForwardAuth passes these headers to the backend:

| Header | Description |
|--------|-------------|
| `X-authentik-username` | Authenticated username |
| `X-authentik-email` | User email |
| `X-authentik-groups` | Comma-separated groups |
| `X-authentik-name` | Full name |
| `X-authentik-uid` | User ID |

---

## User Groups

Authentik provides three default groups:

| Group | Purpose |
|-------|---------|
| `homelab-admins` | Full admin access to all services |
| `homelab-users` | Regular user access |
| `media-users` | Limited access (media services only) |

### Using Groups in OIDC

Many services support group-based role mapping. Example for Grafana:

```yaml
- GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || contains(groups, 'homelab-users') && 'Viewer' || 'Viewer'
```

---

## Troubleshooting

### Provider Not Found

```bash
# Verify providers exist
curl -H "Authorization: Bearer $TOKEN" \
  "https://auth.domain/api/v3/providers/oauth2/" | jq
```

### Redirect URI Mismatch

Ensure the redirect URI in Authentik matches exactly:
- Check for trailing slashes
- Verify protocol (http vs https)
- Match subdomains exactly

### Token Expired

If you see 401 errors:
1. Go to Authentik → Directory → Tokens
2. Create new token
3. Update `.env` with new token

### Service Not Starting

Check logs:
```bash
docker compose -f stacks/sso/docker-compose.yml logs authentik-server
docker compose -f stacks/sso/docker-compose.yml logs authentik-worker
```

### ForwardAuth Not Working

1. Verify Authentik outpost is running
2. Check Traefik logs: `docker logs traefik`
3. Test directly: `curl -v http://authentik-server:9000/outpost.goauthentik.io/auth/traefik`

---

## Resources

- [Authentik Documentation](https://goauthentik.io/docs/)
- [Authentik API Reference](https://goauthentik.io/docs/api/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)