# SSO Integration Guide

This guide explains how to integrate new services with Authentik SSO.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Integration Methods](#integration-methods)
3. [Method 1: Native OIDC](#method-1-native-oidc)
4. [Method 2: Traefik ForwardAuth](#method-2-traefik-forwardauth)
5. [Testing Integration](#testing-integration)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before integrating a new service:

- ✅ SSO stack is running (`stacks/sso/`)
- ✅ Authentik is accessible at `https://auth.DOMAIN`
- ✅ Setup script has been run (`scripts/authentik-setup.sh`)
- ✅ Service has working Traefik routing

## Integration Methods

Choose based on service capabilities:

| Method | Use When | Pros | Cons |
|--------|----------|------|------|
| **Native OIDC** | Service has OAuth2/OIDC support | Full SSO features, group mapping, proper logout | More configuration |
| **ForwardAuth** | No OAuth2 support | Simple setup, works with anything | No group mapping, basic auth only |

## Method 1: Native OIDC

### Step 1: Add Environment Variables

Add to your service's `docker-compose.yml`:

```yaml
services:
  your-service:
    environment:
      # Generic OAuth2/OIDC variables
      - OAUTH_ENABLED=true
      - OAUTH_CLIENT_ID=${YOUR_SERVICE_OAUTH_CLIENT_ID}
      - OAUTH_CLIENT_SECRET=${YOUR_SERVICE_OAUTH_CLIENT_SECRET}
      - OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
      - OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
      - OAUTH_USERINFO_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
      - OAUTH_SCOPES=openid profile email
      # Optional: Logout URL
      - OAUTH_LOGOUT_URL=https://${AUTHENTIK_DOMAIN}/application/o/your-service/end-session/
```

### Step 2: Update .env File

Add to root `.env`:

```bash
# Your Service OAuth
YOUR_SERVICE_OAUTH_CLIENT_ID=
YOUR_SERVICE_OAUTH_CLIENT_SECRET=
```

### Step 3: Update Setup Script

Edit `scripts/authentik-setup.sh` and add to the `PROVIDERS` array:

```bash
PROVIDERS=(
  # ... existing providers ...
  "Your Service;https://your-service.${DOMAIN}/oauth/callback;YOUR_SERVICE_OAUTH_CLIENT_ID;YOUR_SERVICE_OAUTH_CLIENT_SECRET"
)
```

### Step 4: Run Setup Script

```bash
./scripts/authentik-setup.sh
```

This will:
1. Create OIDC provider in Authentik
2. Generate client ID and secret
3. Update `.env` file with credentials
4. Create application in Authentik

### Step 5: Restart Service

```bash
docker compose -f stacks/your-stack/docker-compose.yml restart your-service
```

### Common OIDC Patterns

#### Grafana Pattern

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${SERVICE_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${SERVICE_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - GF_AUTH_SIGNOUT_REDIRECT_URL=https://${AUTHENTIK_DOMAIN}/application/o/service/end-session/
  # Role mapping (optional)
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Admins') && 'Admin' || 'Viewer'
```

#### Gitea Pattern

```yaml
environment:
  - GITEA__openid__ENABLE_OPENID_SIGNIN=true
  - GITEA__openid__ENABLE_OPENID_SIGNUP=true
  - GITEA__openid__WHITELISTED_URIS=${AUTHENTIK_DOMAIN}
  - GITEA__service__DISABLE_REGISTRATION=false
  - GITEA__service__ALLOW_ONLY_EXTERNAL_REGISTRATION=true
  - GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION=true
  - GITEA__oauth2_client__ACCOUNT_LINKING=login
```

#### Outline Pattern

```yaml
environment:
  - OIDC_CLIENT_ID=${SERVICE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${SERVICE_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - OIDC_LOGOUT_URI=https://${AUTHENTIK_DOMAIN}/application/o/service/end-session/
  - OIDC_DISPLAY_NAME=Authentik
  - OIDC_SCOPES=openid profile email
```

## Method 2: Traefik ForwardAuth

### Step 1: Add Middleware to Service

Add to your service's Traefik labels:

```yaml
services:
  your-service:
    # ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.your-service.rule=Host(`your-service.${DOMAIN}`)"
      - "traefik.http.routers.your-service.entrypoints=websecure"
      - "traefik.http.routers.your-service.tls=true"
      # Add this line:
      - "traefik.http.routers.your-service.middlewares=authentik@file"
      - "traefik.http.services.your-service.loadbalancer.server.port=8080"
```

### Step 2: Restart Service

```bash
docker compose restart your-service
```

### Step 3: Test Access

1. Visit `https://your-service.DOMAIN`
2. You should be redirected to Authentik login
3. After login, redirected back to service

### How It Works

```
Browser Request
    │
    ▼
Traefik receives request
    │
    ▼
ForwardAuth middleware calls:
http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
    │
    ├─► If authenticated: Request continues to service
    │
    └─► If not authenticated: Redirect to https://auth.DOMAIN
```

### Available Headers

ForwardAuth adds these headers to requests:

```
X-authentik-username
X-authentik-groups
X-authentik-email
X-authentik-name
X-authentik-uid
X-authentik-jwt
```

Your service can read these headers to identify the user.

### Example: Nginx Config

If your service uses Nginx, you can read the headers:

```nginx
server {
    # ...
    
    location / {
        # Authentik provides user info via headers
        auth_request_set $user $upstream_http_x_authentik_username;
        auth_request_set $email $upstream_http_x_authentik_email;
        auth_request_set $groups $upstream_http_x_authentik_groups;
        
        # Pass to application
        proxy_set_header X-User $user;
        proxy_set_header X-Email $email;
        proxy_set_header X-Groups $groups;
    }
}
```

## Testing Integration

### Test OIDC Flow

```bash
# 1. Check OIDC discovery
curl https://auth.DOMAIN/application/o/.well-known/openid-configuration | jq .

# 2. Test authorization endpoint
curl -I "https://auth.DOMAIN/application/o/authorize/?client_id=YOUR_CLIENT_ID&redirect_uri=https://service.DOMAIN/callback&response_type=code&scope=openid%20profile%20email"

# 3. Check service logs
docker compose logs -f your-service
```

### Test ForwardAuth

```bash
# 1. Without auth (should redirect)
curl -I https://service.DOMAIN
# Expected: 302 redirect to auth.DOMAIN

# 2. With auth (after login)
curl -I -H "Cookie: authentik_session=..." https://service.DOMAIN
# Expected: 200 OK
```

### Test User Attributes

After authentication, check headers:

```bash
# In service container
docker exec -it your-service bash
curl -v http://localhost:8080 2>&1 | grep X-authentik
```

## Troubleshooting

### Common Issues

#### 1. "redirect_uri_mismatch" Error

**Cause**: Callback URL doesn't match Authentik configuration

**Fix**:
1. Check exact callback URL in service documentation
2. Update `scripts/authentik-setup.sh` with correct URL
3. Re-run setup script

#### 2. Infinite Redirect Loop

**Cause**: ForwardAuth using wrong hostname

**Fix**:
- Use internal hostname in Traefik config: `http://authentik-server:9000`
- NOT: `https://auth.DOMAIN`

#### 3. "Invalid client" Error

**Cause**: Client ID/secret mismatch

**Fix**:
```bash
# Check .env values match Authentik
cat .env | grep SERVICE_OAUTH
# Compare with Authentik UI: Applications → Providers → Your Service
```

#### 4. Session Not Persisting

**Cause**: Cookie domain mismatch

**Fix**:
- Ensure `AUTHENTIK_DOMAIN=auth.DOMAIN` (not IP address)
- Check browser cookie settings

#### 5. Can't Logout

**Cause**: Service doesn't call OIDC logout endpoint

**Fix**:
- Configure service to redirect to:
  `https://auth.DOMAIN/application/o/service-name/end-session/`

### Debug Mode

Enable debug logging in Authentik:

```bash
# Add to stacks/sso/.env
AUTHENTIK_LOG_LEVEL=debug

# Restart
docker compose -f stacks/sso/docker-compose.yml restart
```

Check logs:

```bash
# Authentik server
docker compose -f stacks/sso/docker-compose.yml logs -f authentik-server

# Your service
docker compose logs -f your-service

# Traefik (for ForwardAuth)
docker compose -f stacks/base/docker-compose.yml logs -f traefik
```

### Reset OAuth Credentials

If you need to regenerate client credentials:

```bash
# 1. Delete provider in Authentik UI
#    Applications → Providers → Your Service → Delete

# 2. Clear .env values
sed -i "s|^SERVICE_OAUTH_CLIENT_ID=.*|SERVICE_OAUTH_CLIENT_ID=|" .env
sed -i "s|^SERVICE_OAUTH_CLIENT_SECRET=.*|SERVICE_OAUTH_CLIENT_SECRET=|" .env

# 3. Re-run setup script
./scripts/authentik-setup.sh
```

## Advanced Topics

### Custom Scopes

Add custom scopes in Authentik:

1. Navigate to **Customization → Property Mappings**
2. Create new **Scope Mapping**
3. Add to provider's scopes

Example: Add `groups` scope

```python
# Property mapping expression
return {
    "groups": [group.name for group in user.ak_groups.all()]
}
```

### Group-Based Access Control

Create Authentik policies:

1. Navigate to **Customization → Policies**
2. Create **Expression Policy**:

```python
# Only allow homelab-admins group
return request.user.ak_groups.filter(name="homelab-admins").exists()
```

3. Bind policy to application

### Multi-Tenant Setup

To isolate different environments:

1. Create separate Authentik tenants
2. Use different domains: `auth.tenant1.DOMAIN`, `auth.tenant2.DOMAIN`
3. Configure services per tenant

### Rate Limiting

Add rate limiting in Authentik:

1. Create **Rate Limit Policy**
2. Bind to authentication flow
3. Configure limits (e.g., 5 attempts per minute)

## Checklist

Before going to production:

- [ ] OAuth credentials are generated and stored securely
- [ ] Callback URLs match exactly
- [ ] Test login/logout flow works
- [ ] User groups are assigned correctly
- [ ] Service-specific auth configuration is correct
- [ ] ForwardAuth middleware is applied (if using)
- [ ] Debug logging is disabled
- [ ] Strong passwords are used
- [ ] Backups are configured

## Next Steps

- [Configure MFA for admin accounts](https://docs.goauthentik.io/docs/flow/stages/authenticator_totp/)
- [Set up backup and restore](../../stacks/sso/README.md#backup-and-restore)
- [Monitor authentication events](https://docs.goauthentik.io/docs/events/)
