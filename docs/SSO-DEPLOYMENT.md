# SSO Quick Deployment Guide

This guide walks through deploying SSO from scratch in a new environment.

## Prerequisites

- Docker and Docker Compose installed
- Domain name configured with DNS
- Ports 80 and 443 accessible
- 2GB+ RAM available

## Step 1: Environment Setup

```bash
# Clone repository
git clone https://github.com/HuiNeng6/homelab-stack.git
cd homelab-stack

# Copy environment template
cp .env.example .env

# Generate secrets
sed -i "s/^AUTHENTIK_SECRET_KEY=$/AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)/" .env
sed -i "s/^AUTHENTIK_POSTGRES_PASSWORD=$/AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/^AUTHENTIK_REDIS_PASSWORD=$/AUTHENTIK_REDIS_PASSWORD=$(openssl rand -base64 32)/" .env

# Edit domain and email
nano .env
# Set: DOMAIN=yourdomain.com
# Set: ACME_EMAIL=your@email.com
# Set: AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com
# Set: AUTHENTIK_BOOTSTRAP_PASSWORD=your_admin_password
```

## Step 2: Create Networks

```bash
# Create required networks
docker network create proxy
docker network create sso
docker network create databases
```

## Step 3: Start SSO Stack

```bash
# Navigate to SSO stack
cd stacks/sso

# Copy and configure env
cp .env.example .env
# SSO .env inherits from root .env, but you can override here

# Start Authentik
docker compose up -d

# Watch logs (wait ~60s for initialization)
docker logs -f authentik-server
```

Wait until you see:
```
{"event": "Startup complete", "level": "info", ...}
```

## Step 4: Initial Authentik Setup

```bash
# Open Authentik in browser
# https://auth.yourdomain.com

# Login with bootstrap credentials
# Email: AUTHENTIK_BOOTSTRAP_EMAIL
# Password: AUTHENTIK_BOOTSTRAP_PASSWORD
```

### Create Bootstrap Token

1. Navigate to: **Admin Interface** (top right toggle)
2. Go to: **Directory** → **Tokens**
3. Click: **Create**
4. Settings:
   - Name: `bootstrap-token`
   - Intent: `Authentik Core` (API access)
   - User: Select your admin user
   - Expiring: Uncheck (never expires)
5. Click: **Create**
6. **Copy the token key** (shown only once)

```bash
# Add token to .env
echo "AUTHENTIK_BOOTSTRAP_TOKEN=your_token_here" >> .env
```

## Step 5: Run Setup Script

```bash
# Return to root directory
cd ../..

# Make script executable
chmod +x scripts/setup-authentik.sh

# Run setup (dry-run first to preview)
./scripts/setup-authentik.sh --dry-run

# Run actual setup
./scripts/setup-authentik.sh
```

Expected output:
```
==> Creating user groups
[OK] Created group: homelab-admins
[OK] Created group: homelab-users
[OK] Created group: media-users

==> Creating OIDC provider: Grafana
[OK] Created provider: Grafana
  Provider PK: 1
  Client ID: xxxxxxxx
  Client Secret: xxxxxxxx
  Credentials written to .env
[OK] Created application: Grafana

==> Creating OIDC provider: Gitea
...
```

## Step 6: Start Services

```bash
# Start databases (required for productivity stack)
cd stacks/databases && docker compose up -d && cd ../..

# Start productivity stack (includes Nextcloud)
cd stacks/productivity && docker compose up -d && cd ../..

# Start monitoring stack (includes Grafana)
cd stacks/monitoring && docker compose up -d && cd ../..

# Start AI stack (includes Open WebUI)
cd stacks/ai && docker compose up -d && cd ../..
```

## Step 7: Configure Nextcloud OIDC

```bash
# Wait for Nextcloud to be ready (~60s)
docker logs -f nextcloud

# Make script executable
chmod +x scripts/nextcloud-oidc-setup.sh

# Run Nextcloud OIDC setup
./scripts/nextcloud-oidc-setup.sh
```

Expected output:
```
==> Installing user_oidc app in Nextcloud...
[INFO] user_oidc may already be installed

==> Configuring Authentik OIDC provider...
[INFO] Provider 'Authentik' configured

==> Configuring Nextcloud settings...

==> Setting up group mapping...
[INFO] group_oidc may already be installed

==> Nextcloud OIDC Setup Complete!
```

## Step 8: Configure Portainer OAuth

Portainer requires manual OAuth configuration:

1. Open: `https://portainer.yourdomain.com`
2. Login with initial admin password
3. Go to: **Settings** → **Authentication**
4. Select: **OAuth**
5. Configure:

```
Provider: Custom
Client ID: [from .env: PORTAINER_OAUTH_CLIENT_ID]
Client Secret: [from .env: PORTAINER_OAUTH_CLIENT_SECRET]
Authorization URL: https://auth.yourdomain.com/application/o/authorize/
Access Token URL: https://auth.yourdomain.com/application/o/token/
Resource URL: https://auth.yourdomain.com/application/o/userinfo/
Redirect URL: https://portainer.yourdomain.com/
Logout URL: https://auth.yourdomain.com/application/o/portainer/end-session/
User Identifier: preferred_username
Scopes: openid email profile
```

6. Click: **Save configuration**

## Step 9: Configure Gitea OAuth

Gitea requires manual OAuth configuration:

1. Open: `https://git.yourdomain.com`
2. Login as admin
3. Go to: **Site Administration** → **Authentication Sources**
4. Click: **Add Authentication Source**
5. Configure:

```
Authentication Type: OAuth2
Authentication Name: Authentik
OAuth2 Provider: Custom
Client ID: [from .env: GITEA_OAUTH_CLIENT_ID]
Client Secret: [from .env: GITEA_OAUTH_CLIENT_SECRET]
Authorization Endpoint: https://auth.yourdomain.com/application/o/authorize/
Token Endpoint: https://auth.yourdomain.com/application/o/token/
User Info Endpoint: https://auth.yourdomain.com/application/o/userinfo/
```

6. Click: **Add Authentication Source**

## Step 10: Test Logins

Test each service:

| Service | URL | Expected Behavior |
|---------|-----|-------------------|
| Authentik | https://auth.yourdomain.com | Admin dashboard |
| Grafana | https://grafana.yourdomain.com | "Sign in with Authentik" button |
| Gitea | https://git.yourdomain.com | "Authentik" login option |
| Outline | https://docs.yourdomain.com | "Continue with Authentik" |
| Nextcloud | https://cloud.yourdomain.com | "Login with Authentik" |
| Open WebUI | https://ai.yourdomain.com | "Sign in with Authentik" |
| Portainer | https://portainer.yourdomain.com | OAuth login (after manual config) |
| Prometheus | https://prometheus.yourdomain.com | Redirect to Authentik login |

## Troubleshooting

### Authentik won't start

```bash
# Check logs
docker logs authentik-server
docker logs authentik-worker
docker logs authentik-postgres
docker logs authentik-redis

# Common issues:
# - Database not ready: wait longer
# - Redis connection: check password
# - Domain issues: check AUTHENTIK_DOMAIN
```

### Setup script fails

```bash
# Verify token
curl -H "Authorization: Bearer $AUTHENTIK_BOOTSTRAP_TOKEN" \
  https://auth.yourdomain.com/api/v3/core/users/

# Check .env
grep AUTHENTIK .env

# Run with verbose output
bash -x ./scripts/setup-authentik.sh
```

### Service login fails

```bash
# Check service logs
docker logs grafana | grep -i oauth
docker logs nextcloud | grep -i oidc

# Verify redirect URI matches
# In Authentik: Admin → Applications → Providers → [Service] → Redirect URIs
# In service config: Check .env or docker-compose.yml
```

### DNS/Certificate issues

```bash
# Check DNS
dig auth.yourdomain.com

# Check certificates
docker logs traefik | grep -i auth

# Manual certificate request
curl -k https://auth.yourdomain.com/
```

## Next Steps

1. Add users to Authentik groups
2. Configure service-specific permissions
3. Enable MFA for admin accounts
4. Set up automated backups
5. Review security settings

## Support

- Documentation: `docs/SSO-INTEGRATION.md`
- Testing Guide: `docs/SSO-TESTING.md`
- Authentik Docs: https://docs.goauthentik.io/