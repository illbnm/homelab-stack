# SSO Integration Guide — Adding New Services to Authentik

This guide explains how to add new services to your HomeLab SSO system using Authentik.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Integration Methods](#integration-methods)
4. [Adding a New Service](#adding-a-new-service)
5. [Service-Specific Examples](#service-specific-examples)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before integrating services, ensure:

- ✅ Authentik stack is running (`docker compose -f stacks/sso/docker-compose.yml ps`)
- ✅ Authentik Web UI is accessible at `https://auth.${DOMAIN}`
- ✅ You have admin access to Authentik
- ✅ Base infrastructure (Traefik) is running

---

## Quick Start

### 1. Run the Setup Script

```bash
# Auto-create all OIDC providers and write credentials to .env
./scripts/authentik-setup.sh

# Preview changes without applying
./scripts/authentik-setup.sh --dry-run
```

This script:
- Creates user groups (homelab-admins, homelab-users, media-users)
- Creates OIDC/OAuth providers for all services
- Writes client credentials to `.env`
- Creates corresponding Authentik applications

### 2. Restart Services

```bash
# Restart services to pick up new environment variables
cd stacks/productivity && docker compose restart gitea outline bookstack
cd ../storage && docker compose restart nextcloud
cd ../ai && docker compose restart open-webui
cd ../base && docker compose restart portainer
cd ../monitoring && docker compose restart grafana
```

### 3. Run Service-Specific Setup

Some services require additional configuration:

```bash
# Nextcloud OIDC setup (installs Social Login app)
./scripts/nextcloud-oidc-setup.sh

# Gitea OIDC setup (creates OAuth2 source)
./scripts/gitea-oidc-setup.sh
```

---

## Integration Methods

There are two ways to integrate services with Authentik:

### Method A: Native OIDC/OAuth (Recommended)

**Best for:** Services with built-in OAuth2/OIDC support (Grafana, Gitea, Outline, Nextcloud, etc.)

**Pros:**
- Seamless login experience
- User attributes and groups synced
- Full logout support

**Cons:**
- Requires service-specific configuration

**How it works:**
1. Service redirects to Authentik login page
2. User authenticates
3. Authentik returns user info to service
4. Service creates/updates local user account

### Method B: Traefik ForwardAuth (Quick Setup)

**Best for:** Services without OAuth2 support, APIs, admin panels

**Pros:**
- Works with any HTTP service
- No service configuration needed
- Centralized access control

**Cons:**
- No user attribute sync
- All authenticated users get same access

**How it works:**
1. Traefik intercepts all requests
2. ForwardAuth middleware checks with Authentik
3. Unauthenticated users redirected to Authentik
4. Authenticated requests pass through

**Configuration:**

Add this label to any service in docker-compose.yml:

```yaml
labels:
  - "traefik.http.routers.<name>.middlewares=authentik@file"
```

The middleware is already defined in `config/traefik/dynamic/authentik.yml`.

---

## Adding a New Service

### Step 1: Create OIDC Provider in Authentik

**Option A: Automatic (Recommended)**

Add your service to `scripts/authentik-setup.sh`:

```bash
create_oidc_provider \
  "Your Service Name" \
  "https://service.${DOMAIN}/callback" \
  "YOUR_SERVICE_CLIENT_ID" \
  "YOUR_SERVICE_CLIENT_SECRET"
```

Then run:
```bash
./scripts/authentik-setup.sh
```

**Option B: Manual via Web UI**

1. Navigate to **Admin Interface** → **Applications** → **Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**
4. Fill in:
   - **Name:** Your Service Name
   - **Authorization Flow:** default-authentication-flow
   - **Client Type:** Confidential
   - **Redirect URIs:** `https://service.${DOMAIN}/callback`
   - **Signing Key:** Select any certificate
5. Click **Create**
6. Note the **Client ID** and **Client Secret**

### Step 2: Create Application

1. Navigate to **Applications** → **Applications**
2. Click **Create**
3. Fill in:
   - **Name:** Your Service Name
   - **Slug:** your-service-name (lowercase, no spaces)
   - **Provider:** Select the provider you created
4. Click **Create**

### Step 3: Configure Your Service

Add OAuth environment variables to your service's docker-compose.yml:

```yaml
environment:
  - OAUTH_CLIENT_ID=${YOUR_SERVICE_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${YOUR_SERVICE_CLIENT_SECRET}
  - OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OAUTH_USERINFO_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - OAUTH_LOGOUT_URL=https://${AUTHENTIK_DOMAIN}/application/o/your-service-name/end-session/
```

### Step 4: Add Variables to .env

```bash
# Add to .env
YOUR_SERVICE_CLIENT_ID=<from Authentik>
YOUR_SERVICE_CLIENT_SECRET=<from Authentik>
```

### Step 5: Restart and Test

```bash
# Restart service
docker compose restart your-service

# Test login
# Visit https://service.${DOMAIN}
# Click "Login with Authentik"
```

---

## Service-Specific Examples

### Example 1: Grafana (Native OIDC)

**Environment Variables:**

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
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || 'Viewer'
```

**Key Features:**
- Role mapping based on Authentik groups
- Auto-assign organization
- Seamless logout

### Example 2: Gitea (Native OIDC)

**Configuration File:** `config/gitea/app.ini`

```ini
[oauth2_client]
REGISTER_EMAIL_CONFIRM = false
OPENID_CONNECT_SCOPES = openid profile email groups
ENABLE_AUTO_REGISTRATION = true
USERNAME = nickname
UPDATE_AVATAR = true
ACCOUNT_LINKING = login
```

**Setup Script:** `scripts/gitea-oidc-setup.sh`

Creates OAuth2 source using Gitea CLI with:
- Auto-discovery URL
- Group claim mapping
- Admin group assignment

### Example 3: Nextcloud (Social Login App)

**Setup Script:** `scripts/nextcloud-oidc-setup.sh`

Installs and configures Nextcloud Social Login app:

```bash
# Install app
occ app:install sociallogin

# Configure provider
occ config:app:set sociallogin custom_providers --value='{
  "custom_oidc": [{
    "name": "Authentik",
    "clientId": "...",
    "clientSecret": "...",
    "authorizeUrl": "https://auth.${DOMAIN}/application/o/authorize/",
    "tokenUrl": "https://auth.${DOMAIN}/application/o/token/",
    "userInfoUrl": "https://auth.${DOMAIN}/application/o/userinfo/",
    "scope": "openid profile email",
    "groupsClaim": "groups"
  }]
}'
```

**Key Features:**
- Auto-create users on first login
- Group mapping to Nextcloud groups
- Custom login button styling

### Example 4: Open WebUI (Native OIDC)

**Environment Variables:**

```yaml
environment:
  - ENABLE_OAUTH_SIGNUP=true
  - OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
  - OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
  - OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/.well-known/openid-configuration
  - OAUTH_SCOPES=openid profile email
```

**Key Features:**
- OpenID auto-discovery
- Email-based account merging
- Auto-registration

### Example 5: Prometheus (ForwardAuth)

**Docker Compose Labels:**

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.prometheus.rule=Host(`prometheus.${DOMAIN}`)
  - traefik.http.routers.prometheus.entrypoints=websecure
  - traefik.http.routers.prometheus.tls=true
  - traefik.http.routers.prometheus.middlewares=authentik@file
  - traefik.http.services.prometheus.loadbalancer.server.port=9090
```

**How it works:**
- No service configuration needed
- Traefik forwards auth check to Authentik
- All authenticated users get access

---

## User Groups and Permissions

Authentik groups control access to services:

### Group Hierarchy

```
homelab-admins
  ├─ Full access to all services
  ├─ Admin panels (Portainer, Traefik, Grafana)
  └─ Can manage other users

homelab-users
  ├─ Access to standard services
  ├─ Productivity tools (Gitea, Outline, Nextcloud)
  └─ No admin access

media-users
  ├─ Media services only
  ├─ Jellyfin, Jellyseerr
  └─ No access to admin/productivity tools
```

### Assigning Users to Groups

1. Navigate to **Admin Interface** → **Directory** → **Users**
2. Click on a user
3. Scroll to **Groups**
4. Click **Add to existing group**
5. Select group(s)
6. Click **Save**

### Group-Based Access Control

Some services support group-based permissions:

**Grafana:**
```yaml
- GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || 'Viewer'
```

**Gitea:**
```bash
gitea admin auth add-oauth \
  --admin-group "homelab-admins"
```

**Nextcloud:**
```json
{
  "group_mapping": {
    "homelab-admins": "admin",
    "homelab-users": "users"
  }
}
```

---

## Troubleshooting

### Common Issues

#### 1. "Invalid redirect URI"

**Problem:** Authentik rejects the redirect URL

**Solution:**
- Check redirect URI in Authentik provider matches exactly
- Include protocol (https://)
- No trailing slash
- Example: `https://grafana.${DOMAIN}/login/generic_oauth`

#### 2. "Client authentication failed"

**Problem:** Client ID/Secret mismatch

**Solution:**
- Verify .env variables match Authentik
- Restart service after updating .env
- Check for extra spaces or quotes

```bash
# Verify
docker compose config | grep OAUTH_CLIENT_ID
```

#### 3. "Failed to fetch user info"

**Problem:** Service can't reach Authentik userinfo endpoint

**Solution:**
- Check service is on same network as Authentik
- Verify AUTHENTIK_DOMAIN is correct
- Test manually:

```bash
curl -H "Authorization: Bearer <token>" \
  https://auth.${DOMAIN}/application/o/userinfo/
```

#### 4. "User not created in service"

**Problem:** OIDC login succeeds but user not created

**Solution:**
- Enable auto-registration in service config
- Check required fields (email, name) are provided
- Verify scopes include `profile email`

#### 5. ForwardAuth loop / Redirect loop

**Problem:** Browser keeps redirecting

**Solution:**
- Ensure Authentik outpost URL uses internal hostname: `http://authentik-server:9000`
- NOT public domain
- Check Traefik middleware config: `config/traefik/dynamic/authentik.yml`

### Debug Mode

Enable verbose logging in Authentik:

```yaml
# stacks/sso/docker-compose.yml
environment:
  - AUTHENTIK_LOG_LEVEL=debug
```

View logs:
```bash
docker compose -f stacks/sso/docker-compose.yml logs -f authentik-server
```

### Testing OIDC Flow

Use `curl` to test token exchange:

```bash
# 1. Get authorization code from browser redirect
# 2. Exchange code for token
curl -X POST https://auth.${DOMAIN}/application/o/token/ \
  -d "grant_type=authorization_code" \
  -d "code=<code>" \
  -d "redirect_uri=https://service.${DOMAIN}/callback" \
  -u "<client_id>:<client_secret>"

# 3. Get user info
curl -H "Authorization: Bearer <access_token>" \
  https://auth.${DOMAIN}/application/o/userinfo/
```

---

## Advanced Topics

### Custom Attributes

Pass custom attributes to services:

1. Navigate to **Admin Interface** → **Customisation** → **Property Mappings**
2. Create new mapping
3. Add to OIDC provider scope

Example: Pass department attribute

```python
# Property mapping
return {
  "department": user.attributes.get("department", "unknown")
}
```

### Multiple Domains

Configure Authentik for multiple domains:

```yaml
# stacks/sso/.env
AUTHENTIK_DOMAIN=auth.domain1.com
# Additional domains configured in Authentik UI
```

### Outposts

Deploy Authentik outposts for:
- Multi-cluster support
- LDAP integration
- Radius authentication

See: https://docs.goauthentik.io/docs/outposts/

---

## References

- **Authentik Docs:** https://docs.goauthentik.io/
- **OIDC Specification:** https://openid.net/connect/
- **Traefik ForwardAuth:** https://doc.traefik.io/traefik/middlewares/http/forwardauth/
- **Grafana OAuth:** https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/
- **Gitea OAuth2:** https://docs.gitea.io/en-us/oauth2-provider/
- **Nextcloud Social Login:** https://github.com/zorn-v/nextcloud-social-login

---

## Support

If you encounter issues:

1. Check Authentik logs: `docker compose -f stacks/sso logs -f`
2. Check service logs: `docker compose -f stacks/<name> logs -f <service>`
3. Verify network connectivity: `docker network inspect proxy`
4. Open an issue: https://github.com/YOUR_USERNAME/homelab-stack/issues
