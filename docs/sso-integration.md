# 🚪 SSO Integration Guide

This document provides comprehensive instructions for integrating services with Authentik SSO and adding new services to the HomeLab Stack.

## 🏗️ Architecture

```
Internet
   │
   ▼
[Traefik v3]  ← Reverse proxy, auto HTTPS, Forward Auth
   │
   ├── [Authentik]     ← SSO / OIDC provider (all services)
   │   ├── Server      ← Web UI + API + endpoints
   │   ├── Worker      ← Background tasks
   │   ├── PostgreSQL  ← Database
   │   └── Redis       ← Cache/queue
   │
   ├── [Grafana]      ← Authentik OIDC + user groups
   ├── [Gitea]        ← Authentik OAuth2
   ├── [Outline]      ← Authentik OIDC
   ├── [Portainer]    ← Authentik OAuth2
   └── [...]
```

## 🎯 User Groups

Authentik uses three main user groups for access control:

| Group | Description | Access Level |
|-------|-------------|--------------|
| `homelab-admins` | Full access to all services | Admin on all services |
| `homelab-users` | Access to regular services | User on most services |
| `media-users` | Media services only (Jellyfin, Jellyseerr) | Limited access |

## 📋 Prerequisites

1. **Authentik deployed**: Run `./scripts/stack-manager.sh start sso`
2. **Environment configured**: Copy `.env.example` to `.env` and fill in values
3. **Bootstrap token**: Set `AUTHENTIK_BOOTSTRAP_TOKEN` in `.env`
4. **Domain configured**: Set `DOMAIN` and `AUTHENTIK_DOMAIN` in `.env`

## 🔧 Initial Setup

### 1. Deploy Authentik Stack

```bash
# Start SSO stack
./scripts/stack-manager.sh start sso

# Wait for containers to be ready (60+ seconds)
./scripts/wait-healthy.sh --stack sso --timeout 300
```

### 2. Configure Authentik

First-time setup requires manual steps:

1. **Access Authentik**: Visit `https://auth.yourdomain.com`
2. **Login**: Use the admin credentials from `.env`
3. **Initial Configuration**:
   - Set up an external email server (optional)
   - Configure notification channels
   - Set up default flows

### 3. Run Auto-Setup Script

```bash
# Auto-create OIDC providers and user groups
./scripts/authentik-setup.sh

# Dry-run first (preview changes)
./scripts/authentik-setup.sh --dry-run
```

This script automatically:
- Creates OIDC providers for all configured services
- Creates user groups (homelab-admins, homelab-users, media-users)
- Generates OAuth2 client IDs/secrets and updates `.env`
- Creates access policies for each group

## 🔐 Service Integration Types

### Type 1: Native OIDC Support (Recommended)

Services with built-in OIDC support:

#### Grafana
```yaml
# In docker-compose.yml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || 'Viewer'
```

#### Outline
```yaml
environment:
  - OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

### Type 2: OAuth2 Support

Services with OAuth2 support:

#### Gitea
```yaml
environment:
  - GITEA__oauth2__ENABLE=true
  - GITEA__oauth2__OPENID__ENABLE=true
  - GITEA__oauth2__OPENID__CLIENT_ID=${GITEA_OAUTH_CLIENT_ID}
  - GITEA__oauth2__OPENID__CLIENT_SECRET=${GITEA_OAUTH_CLIENT_SECRET}
  - GITEA__oauth2__OPENID__AUTO_DISCOVERY_URL=https://${AUTHENTIK_DOMAIN}/application/o/.well-known/oauth-issuer
```

#### Portainer
```yaml
environment:
  - PORTAINER__AUTHENTICATION__METHODS=oauth,local
  - PORTAINER__AUTHENTICATION__OAUTH2__ENABLED=true
  - PORTAINER__AUTHENTICATION__OAUTH2__CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
  - PORTAINER__AUTHENTICATION__OAUTH2__CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
  - PORTAINER__AUTHENTICATION__OAUTH2__AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - PORTAINER__AUTHENTICATION__OAUTH2__TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
```

### Type 3: Traefik ForwardAuth

For services without native OIDC support:

```yaml
# In service's docker-compose.yml labels
labels:
  - "traefik.http.routers.<service>.middlewares=authentik@file"
```

This requires the `config/traefik/dynamic/authentik.yml` middleware to be configured.

## 🆕 Adding New Services to Authentik

### Step 1: Create OIDC Provider in Authentik UI

1. **Access Authentik**: `https://auth.yourdomain.com`
2. **Navigate**: Applications → Providers → OAuth2
3. **Create New Provider**:
   - Name: `<Service> Provider`
   - Authorization Flow: "Default authorization flow"
   - Client Type: "Confidential"
   - Redirect URI: `https://<service>.yourdomain.com/oauth2/callback`
4. **Note**: Save the Client ID and Client Secret

### Step 2: Update Environment Variables

Add to `.env`:
```bash
<SERVICE>_OAUTH_CLIENT_ID=your_client_id_here
<SERVICE>_OAUTH_CLIENT_SECRET=your_client_secret_here
```

### Step 3: Create Authentik Application

1. **Applications**: Create Application
   - Name: `<Service>`
   - Slug: `<service>` (lowercase)
   - Provider: Select the OAuth2 provider created above
   - Group Mappings:
     - `homelab-admins` → Admin role
     - `homelab-users` → User role

### Step 4: Configure Service

Update the service's docker-compose.yml with appropriate OIDC/OAuth2 environment variables based on the service type above.

### Step 5: Add ForwardAuth (if needed)

For web services, add Traefik middleware:
```yaml
labels:
  - "traefik.http.routers.<service>.middlewares=authentik@file"
```

### Step 6: Update Service User Mapping

Configure the service to map Authentik groups to local roles:

```yaml
# Example for Grafana
environment:
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || contains(groups, 'homelab-users') && 'Editor' || 'Viewer'
```

## 🧪 Testing SSO Integration

### 1. Test Setup

```bash
# Validate SSO configuration
./scripts/test-sso.sh setup

# Test OIDC providers
./scripts/test-sso.sh oidc

# Test service integration
./scripts/test-sso.sh integration
```

### 2. Manual Testing

1. **Access a service**: Visit `https://<service>.yourdomain.com`
2. **Click login**: Should redirect to Authentik
3. **Login**: Use Authentik credentials
4. **Verify**: Should redirect back to the service

### 3. Group Testing

1. **Admin user**: Should have admin access to all services
2. **Regular user**: Should have user access to regular services
3. **Media user**: Should have limited access (media services only)

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentik API Access
```bash
# Check API connectivity
curl -s "https://${AUTHENTIK_DOMAIN}/-/health/ready/"

# Check token
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  "https://${AUTHENTIK_DOMAIN}/api/v3/providers/oauth2/"
```

#### 2. OAuth2 Client Issues
```bash
# Validate client ID/secret
grep -E "<SERVICE>_OAUTH_" .env

# Check Authentik provider
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  "https://${AUTHENTIK_DOMAIN}/api/v3/providers/oauth2/?client_id=<CLIENT_ID>"
```

#### 3. Service Integration Issues
```bash
# Check service logs
docker logs <service_name>

# Test redirect flow
curl -I "https://<service>.yourdomain.com"

# Check Traefik logs
docker logs traefik
```

### Debug Mode

Enable debug logging for troubleshooting:

```bash
# Add to services needing debug
environment:
  - LOG_LEVEL=debug
  - AUTHENTIK_DEBUG=true
```

## 📊 Monitoring SSO Health

### Authentik Health
```bash
# Check Authentik endpoint health
curl -sf "https://${AUTHENTIK_DOMAIN}/-/health/ready/"

# Check API health
curl -sf -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  "https://${AUTHENTIK_DOMAIN}/api/v3/system/health/"
```

### Service Authentication
```bash
# Monitor failed logins
docker logs <service_name> | grep -i "error\|failed"

# Check Traefik ForwardAuth
docker logs traefik | grep "authentik"
```

## 🚀 Migration Guide

### From Native Auth to SSO

1. **Backup existing configurations**
2. **Deploy Authentik**: `./scripts/stack-manager.sh start sso`
3. **Run setup script**: `./scripts/authentik-setup.sh`
4. **Update services**: Add OIDC/OAuth2 environment variables
5. **Test**: Verify existing users can login via SSO
6. **Remove old auth**: Once SSO is stable, remove native auth configs

### Multi-Domain Support

For services on different domains:

```yaml
# In docker-compose.yml
environment:
  - AUTHENTIK_DOMAIN=auth.yourdomain.com
  - SERVICE_DOMAIN=service.yourdomain.com
  - REDIRECT_URI=https://service.yourdomain.com/callback
```

## 🔐 Security Best Practices

### 1. Token Security
- Use strong, randomly generated secrets
- Rotate secrets every 90 days
- Never commit secrets to git

### 2. Group Management
- Regular review of group memberships
- Remove inactive users promptly
- Use service-specific role mapping

### 3. Network Security
- Use HTTPS for all services
- Configure proper CORS settings
- Implement rate limiting on Authentik

### 4. Monitoring
- Monitor failed login attempts
- Set up alerts for suspicious activity
- Regular security audits

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Run the test suite: `./scripts/test-sso.sh all`
3. Check GitHub issues: https://github.com/illbnm/homelab-stack/issues
4. Create a new issue with SSO debug information