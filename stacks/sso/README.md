# 🔐 SSO Stack — Authentik Unified Identity

> Single sign-on for your entire homelab. One login, all services.

Authentik (`auth.${DOMAIN}`) is the OIDC/SAML identity provider for all services in this stack. It provides:

- **OIDC/OAuth2** for Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
- **SAML** for enterprise-compatible integrations  
- **Traefik ForwardAuth** for services without native SSO support
- **User group isolation** (admins / users / media-users)

---

## 📋 Requirements

- Docker Engine 24+ and Docker Compose v2
- The **base stack** running (Traefik + `proxy` network)
- A valid domain and Let's Encrypt HTTPS

---

## 🚀 First-Time Setup

### Step 1 — Configure environment

```bash
# From the repo root
cp .env.example .env
```

Edit `.env` and fill the SSO section:

```bash
# Generate all secrets in one shot
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')

# Paste into .env
echo "AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}"
echo "AUTHENTIK_POSTGRES_PASSWORD=${AUTHENTIK_POSTGRES_PASSWORD}"
echo "AUTHENTIK_REDIS_PASSWORD=${AUTHENTIK_REDIS_PASSWORD}"
```

Also set:
```env
DOMAIN=yourdomain.com
AUTHENTIK_ADMIN_EMAIL=admin@yourdomain.com
AUTHENTIK_ADMIN_PASSWORD=YourStrongPassword123!
```

### Step 2 — Start the stack

```bash
cd stacks/sso
docker compose up -d

# Verify all 4 containers are healthy
docker compose ps
```

Expected output (all `healthy`):
```
NAME                   STATUS
authentik-server       running (healthy)
authentik-worker       running (healthy)
authentik-postgres     running (healthy)
authentik-redis        running (healthy)
```

### Step 3 — Complete initial setup

Visit `https://auth.yourdomain.com/if/flow/initial-setup/`

The bootstrap admin account (set via `AUTHENTIK_ADMIN_EMAIL` / `AUTHENTIK_ADMIN_PASSWORD`) is created automatically on first startup.

### Step 4 — Create user groups

In the Authentik Admin UI (`https://auth.yourdomain.com/if/admin/`):

Navigate to **Directory → Groups** and create:

| Group | Purpose |
|-------|---------|
| `homelab-admins` | Full access to all service admin interfaces |
| `homelab-users` | Access to standard services (Grafana, Gitea, Nextcloud, etc.) |
| `media-users` | Access to Jellyfin and Jellyseerr only |

### Step 5 — Run the setup script

```bash
# From the repo root
./scripts/authentik-setup.sh
```

This script:
1. Creates OIDC/OAuth2 providers for all supported services
2. Creates the corresponding Applications
3. Outputs `Client ID` and `Client Secret` for each service
4. Installs the Traefik ForwardAuth outpost

Paste the output credentials into `.env` for the respective stacks.

### Step 6 — Enable Traefik ForwardAuth middleware

The middleware is pre-defined in `config/traefik/dynamic/middlewares.yml`.
Add it to any service's Traefik labels:

```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=authentik@file"
```

---

## 🏗️ Architecture

```
Browser
  │
  ▼
[Traefik]
  │  ← checks ForwardAuth for protected routes
  ▼
[Authentik Server :9000]    ← OIDC/SAML/ForwardAuth
  │
  ├── [PostgreSQL :5432]    ← persistent identity store
  └── [Redis :6379]         ← session cache + task queue
```

### Networks

| Network | Purpose |
|---------|---------|
| `proxy` | Shared with Traefik (external, created by base stack) |
| `sso` | Internal — Authentik ↔ PostgreSQL ↔ Redis |

---

## ⚙️ OIDC Integration Guide

### How Authentik OIDC works

1. User visits a service (e.g. Grafana)
2. Service redirects to `https://auth.${DOMAIN}/application/o/<slug>/authorize/`
3. User logs in with Authentik credentials
4. Authentik redirects back with an auth code
5. Service exchanges code for tokens
6. User is logged in

### Adding a new service via OIDC

**In Authentik Admin UI:**

1. Go to **Applications → Providers → Create**
2. Choose **OAuth2/OpenID Provider**
3. Set name, client type (`Confidential`), redirect URIs
4. Copy the generated `Client ID` and `Client Secret`
5. Go to **Applications → Applications → Create**
6. Link the new provider

**Standard OIDC endpoints** (replace `<slug>` with your app name):
```
Authorization: https://auth.yourdomain.com/application/o/<slug>/authorize/
Token:         https://auth.yourdomain.com/application/o/<slug>/token/
Userinfo:      https://auth.yourdomain.com/application/o/<slug>/userinfo/
JWKS:          https://auth.yourdomain.com/application/o/<slug>/jwks/
```

---

## 🖥️ Service Integration Examples

### Grafana (OIDC)

Add to `config/grafana/grafana.ini`:

```ini
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
```

### Portainer (OAuth2)

In Portainer Settings → Authentication:
1. Select **OAuth**
2. Fill:
   - Client ID: `${PORTAINER_OAUTH_CLIENT_ID}`
   - Client Secret: `${PORTAINER_OAUTH_CLIENT_SECRET}`
   - Authorization URL: `https://auth.${DOMAIN}/application/o/portainer/authorize/`
   - Access Token URL: `https://auth.${DOMAIN}/application/o/portainer/token/`
   - Resource URL: `https://auth.${DOMAIN}/application/o/userinfo/`
   - Redirect URL: `https://portainer.${DOMAIN}`
   - User identifier: `preferred_username`
   - Scopes: `openid email profile`

See [docs/integration-examples.md](docs/integration-examples.md) for full examples for all services.

---

## 🛡️ Traefik ForwardAuth

For services without native OIDC support, use Authentik's ForwardAuth outpost:

```yaml
# config/traefik/dynamic/middlewares.yml
middlewares:
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
```

Apply to any service:
```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=authentik@file"
```

---

## 👥 User Group Permissions

| Group | Grafana | Gitea | Nextcloud | Jellyfin | Admin UIs |
|-------|---------|-------|-----------|----------|-----------|
| `homelab-admins` | Admin | Owner | Admin | Admin | ✅ |
| `homelab-users` | Viewer | User | User | User | ❌ |
| `media-users` | ❌ | ❌ | ❌ | User | ❌ |

Configure group-based access in **Authentik Admin → Applications → [App] → Policy Bindings**.

---

## 🔄 Maintenance

```bash
# Update Authentik (change version tag first)
docker compose pull && docker compose up -d

# View logs
docker compose logs -f authentik-server

# Backup database
docker exec authentik-postgres pg_dump -U authentik authentik > backup-$(date +%Y%m%d).sql

# Run a management command
docker exec authentik-worker ak repair_migrations
```

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| `authentik-server` won't start | Check `AUTHENTIK_SECRET_KEY` is set (min 50 chars) |
| "Invalid redirect URI" | Add the exact callback URL in Authentik provider settings |
| ForwardAuth 401 on all requests | Ensure outpost is deployed and `proxy` network is shared |
| Worker not processing tasks | Check Redis password matches in both Authentik and Redis config |
| Can't log in after password reset | Clear browser cookies for `auth.${DOMAIN}` |

```bash
# Full diagnostic
docker compose logs authentik-server authentik-worker 2>&1 | grep -E 'ERROR|WARN|exception'
```

---

## 📚 References

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik Docker Compose Guide](https://docs.goauthentik.io/docs/installation/docker-compose)
- [OIDC Provider Setup](https://docs.goauthentik.io/docs/providers/oauth2/)
- [Traefik ForwardAuth Integration](https://docs.goauthentik.io/docs/providers/proxy/traefik)
- [Blueprint Reference](https://docs.goauthentik.io/docs/blueprints/)
