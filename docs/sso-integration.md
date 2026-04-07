# SSO Integration Guide

Complete guide to integrating Authentik SSO with HomeLab services.

## Overview

Authentik provides unified authentication through:
- **OIDC (OpenID Connect)** - Modern OAuth2-based authentication
- **SAML** - Enterprise federation
- **ForwardAuth** - Traefik middleware for services without native OIDC

## Quick Start

### 1. Deploy SSO Stack

```bash
cd stacks/sso
cp .env.example .env
# Edit .env and set all required values
docker compose up -d
```

### 2. Generate Bootstrap Token

1. Login to Authentik: `https://auth.yourdomain.com`
2. Go to **Admin Interface** → **Directory** → **Tokens**
3. Create token with intent `Api`
4. Add to `.env` as `AUTHENTIK_BOOTSTRAP_TOKEN`

### 3. Run Auto-Setup Script

```bash
cd ../..  # Back to project root
./scripts/setup-authentik.sh
```

This creates:
- User groups (homelab-admins, homelab-users, media-users)
- OIDC providers for all services
- Client credentials in `.env`

### 4. Configure Services

Restart services to apply OIDC configuration:

```bash
./scripts/stack-manager.sh restart monitoring
./scripts/stack-manager.sh restart productivity
./scripts/stack-manager.sh restart storage
./scripts/stack-manager.sh restart ai
```

## Supported Services

### Native OIDC Support

These services have built-in OIDC support:

| Service | Integration Type | Auto-Configured |
|---------|-----------------|-----------------|
| Grafana | Generic OAuth | ✅ |
| Gitea | OAuth2 | ✅ |
| Nextcloud | OAuth2 (sociallogin) | ✅ (extra script) |
| Outline | OIDC | ✅ |
| Portainer | OAuth2 | ✅ |
| Open WebUI | OIDC | ✅ |
| Perplexica | OIDC | ✅ |

### ForwardAuth Protection

These services use Traefik ForwardAuth middleware:

| Service | Middleware | Notes |
|---------|-----------|-------|
| Prometheus | authentik@file | Admin only |
| Open WebUI | authentik@file | Fallback protection |
| Perplexica | authentik@file | Primary auth method |

### Nextcloud Special Configuration

Nextcloud requires additional setup:

```bash
./scripts/nextcloud-oidc-setup.sh
```

This script:
1. Installs the sociallogin app
2. Configures Authentik OIDC provider
3. Sets up user group mapping
4. Creates Nextcloud user groups

## User Groups

### Group Hierarchy

```
homelab-admins (full access)
    ├── homelab-users (standard services)
    └── media-users (media services only)
```

### Group Permissions

| Group | Services |
|-------|----------|
| `homelab-admins` | All services + admin interfaces |
| `homelab-users` | Grafana, Gitea, Outline, Nextcloud, AI |
| `media-users` | Jellyfin, Jellyseerr only |

### Role Mapping

**Grafana**:
- `homelab-admins` → Admin role
- `homelab-users` → Viewer role

**Nextcloud**:
- `homelab-admins` → admin group
- `media-users` → media-users group

## Adding New Services

### Method 1: Native OIDC (Recommended)

1. Add provider to `scripts/setup-authentik.sh`:

```bash
create_oidc_provider \
  "NewService" \
  "https://newservice.${DOMAIN}/oauth/callback" \
  "NEWSERVICE_OAUTH_CLIENT_ID" \
  "NEWSERVICE_OAUTH_CLIENT_SECRET"
```

2. Add environment variables to `.env.example`:

```bash
NEWSERVICE_OAUTH_CLIENT_ID=
NEWSERVICE_OAUTH_CLIENT_SECRET=
```

3. Configure service in `docker-compose.yml`:

```yaml
environment:
  - OIDC_CLIENT_ID=${NEWSERVICE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${NEWSERVICE_OAUTH_CLIENT_SECRET}
  - OIDC_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/newservice/
```

### Method 2: ForwardAuth (Quick Setup)

For services without OIDC support:

```yaml
labels:
  - "traefik.http.routers.newservice.middlewares=authentik@file"
```

All authenticated users will be able to access the service.

## Testing SSO

### 1. Verify Provider Creation

```bash
# Check providers exist
curl -H "Authorization: Bearer $AUTHENTIK_BOOTSTRAP_TOKEN" \
  https://auth.${DOMAIN}/api/v3/providers/oauth2/ | jq
```

### 2. Test Service Login

For each service:

1. Navigate to service URL (e.g., `https://grafana.yourdomain.com`)
2. Click "Login with Authentik" or similar
3. Enter Authentik credentials
4. Verify successful redirect back to service

### 3. Check User Groups

```bash
# In Authentik Admin UI
# Directory → Users → [user] → Groups
```

## Troubleshooting

### Provider Not Created

**Symptom**: `setup-authentik.sh` fails

**Solution**:
1. Check Authentik is running: `docker compose -f stacks/sso/docker-compose.yml ps`
2. Verify token is valid: Test API call with token
3. Check logs: `docker compose -f stacks/sso logs authentik-server`

### Login Loop

**Symptom**: Redirect loops between service and Authentik

**Solution**:
1. Check redirect URI matches exactly (including trailing slash)
2. Verify cookie settings (same-site, secure)
3. Check service logs for OAuth errors

### Permission Denied

**Symptom**: Can login but cannot access service

**Solution**:
1. Check user is in correct group
2. Verify group mapping in service configuration
3. Check service logs for authorization errors

### Token Expired

**Symptom**: API calls fail with 401

**Solution**:
1. Generate new token in Authentik UI
2. Update `.env` with new token
3. Re-run `setup-authentik.sh`

## Security Best Practices

1. **Use Strong Secrets**
   - All passwords > 24 characters
   - Use `openssl rand -base64 32` for secrets

2. **Limit Token Scope**
   - Create tokens with minimal permissions
   - Set reasonable expiration (30 days)

3. **Regular Rotation**
   - Rotate `AUTHENTIK_SECRET_KEY` yearly
   - Update bootstrap tokens quarterly

4. **Monitor Access**
   - Review Authentik events log
   - Set up failed login alerts

5. **Backup Configuration**
   - Backup Authentik database regularly
   - Export provider configurations

## Advanced Configuration

### Custom Claims

Add custom claims to user tokens:

```bash
# In Authentik UI
# Customization → Property Mappings → Create
```

Example: Add department claim

```python
return {
    "department": user.attributes.get("department", "unknown")
}
```

### Flow Customization

Create custom authentication flows:

1. Flows → Create new flow
2. Add stages (email verification, MFA, etc.)
3. Bind to application

### Outpost Deployment

Deploy Authentik outpost for:
- Separate authentication domain
- High availability
- Geographic distribution

See: https://goauthentik.io/docs/outposts/

## Resources

- [Authentik Documentation](https://goauthentik.io/docs/)
- [OIDC Specification](https://openid.net/connect/)
- [OAuth2 RFC](https://datatracker.ietf.org/doc/html/rfc6749)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
