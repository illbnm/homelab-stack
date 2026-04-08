# SSO Integration Guide - Authentik Unified Identity

Complete guide for integrating Authentik SSO with all HomeLab services.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Service Integration](#service-integration)
5. [User Group Management](#user-group-management)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │    Traefik     │
                    │   (Port 443)   │
                    └────────┬───────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  Authentik     │  │  Services with │  │ Services with  │
│  (SSO Portal)  │  │  Native OIDC   │  │  ForwardAuth   │
│                │  │                │  │                │
│ auth.DOMAIN    │  │ - Grafana      │  │ - Prometheus   │
│                │  │ - Gitea        │  │ - Portainer    │
│                │  │ - Outline      │  │ - Loki         │
│                │  │ - Open WebUI   │  │                │
│                │  │ - Nextcloud    │  │                │
└────────────────┘  └────────────────┘  └────────────────┘
         │
         ▼
┌────────────────────────────────┐
│   Authentik Components         │
│                                │
│  - Server (Web UI + API)       │
│  - Worker (Background tasks)   │
│  - PostgreSQL (Database)       │
│  - Redis (Cache + Sessions)    │
└────────────────────────────────┘
```

### Authentication Flow

1. **User accesses protected service** → Traefik intercepts
2. **ForwardAuth middleware** → Checks if authenticated via Authentik
3. **If not authenticated** → Redirect to Authentik login page
4. **User logs in** → Authentik validates credentials
5. **OIDC/OAuth2 flow** → Service receives user identity
6. **User gains access** → Service creates/links local account

---

## Prerequisites

### System Requirements

- Docker 24.0+ and Docker Compose v2.20+
- Minimum 4GB RAM (Authentik requires ~2GB)
- 20GB free disk space for database and media
- Domain with DNS configured
- Ports 80 and 443 open

### Required Services

- Base stack running (Traefik)
- PostgreSQL database (shared or dedicated)
- Redis cache (shared or dedicated)

### Client Tools

```bash
# Required
curl
jq

# Install on Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl jq

# Install on macOS
brew install curl jq
```

---

## Quick Start

### Step 1: Configure Environment

```bash
cd /path/to/homelab-stack
cp .env.example .env
nano .env
```

**Required Variables:**

```bash
# General
DOMAIN=yourdomain.com
ACME_EMAIL=admin@yourdomain.com

# Authentik Core
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)
AUTHENTIK_DOMAIN=auth.${DOMAIN}

# Admin Credentials (CHANGE THESE!)
AUTHENTIK_ADMIN_EMAIL=admin@yourdomain.com
AUTHENTIK_ADMIN_PASSWORD=$(openssl rand -base64 16)
```

### Step 2: Generate Secrets

```bash
# Generate all required secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env with generated values
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env
```

### Step 3: Start Authentik Stack

```bash
cd stacks/sso
docker compose up -d

# Wait for services to be healthy (~60-90 seconds)
docker compose ps

# Watch logs
docker compose logs -f authentik-server
```

### Step 4: Run Setup Script

```bash
# Return to root directory
cd ../..

# Run automated setup (creates OIDC providers and user groups)
./scripts/authentik-setup.sh

# For dry-run (preview changes without applying)
./scripts/authentik-setup.sh --dry-run
```

### Step 5: Verify Installation

```bash
# Check Authentik health
curl -sf https://auth.${DOMAIN}/-/health/ready/ && echo "Authentik is healthy"

# Access Authentik Admin UI
open https://auth.${DOMAIN}/if/admin/

# Login with admin credentials from .env
```

---

## Service Integration

### Overview by Integration Type

| Service | Integration Type | Auto-Configured | Notes |
|---------|------------------|-----------------|-------|
| Grafana | Native OIDC | ✅ Yes | Role mapping based on groups |
| Gitea | Native OIDC | ✅ Yes | Auto-account linking enabled |
| Outline | Native OIDC | ✅ Yes | Requires initial setup |
| Open WebUI | Native OIDC | ✅ Yes | Email-based account merging |
| Nextcloud | Native OIDC | ⚠️ Partial | Requires Social Login app |
| Portainer | ForwardAuth | ✅ Yes | CE uses middleware; BE has native OIDC |
| Prometheus | ForwardAuth | ✅ Yes | Protected by middleware |

### Grafana

**Status:** ✅ Auto-configured

Grafana has native OAuth2 support and is automatically configured by the setup script.

**Features:**
- Automatic user provisioning
- Role mapping based on Authentik groups
- Seamless SSO experience

**Configuration (already in docker-compose.yml):**

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
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

**Role Mapping:**
- `Grafana Admins` group → Admin role
- `Grafana Editors` group → Editor role
- All other users → Viewer role

**Testing:**

```bash
# Access Grafana
open https://grafana.${DOMAIN}

# Click "Sign in with Authentik"
# You should be redirected to Authentik login
# After login, redirected back to Grafana with your account created
```

### Gitea

**Status:** ✅ Auto-configured

Gitea has native OpenID Connect support with auto-account linking.

**Features:**
- Auto-registration of new users
- Account linking by email
- Avatar synchronization
- Team membership sync (advanced)

**Configuration (already in docker-compose.yml):**

```yaml
environment:
  - GITEA__openid__ENABLE_OPENID_SIGNIN=true
  - GITEA__openid__ENABLE_OPENID_SIGNUP=true
  - GITEA__service__DISABLE_REGISTRATION=false
  - GITEA__service__ALLOW_ONLY_EXTERNAL_REGISTRATION=true
  - GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION=true
  - GITEA__oauth2_client__ACCOUNT_LINKING=login
  - GITEA__oauth2_client__UPDATE_AVATAR=true
```

**Manual Setup (if needed):**

1. Login to Gitea as admin
2. Go to **Site Administration → Authentication Sources**
3. Click **Add OAuth2 Authentication Source**
4. Fill in:
   - Authentication Name: `Authentik`
   - OAuth2 Provider: `OpenID Connect`
   - Client ID: From `.env` (`GITEA_OAUTH_CLIENT_ID`)
   - Client Secret: From `.env` (`GITEA_OAUTH_CLIENT_SECRET`)
   - OpenID Connect Auto Discovery URL: `https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration`
5. Click **Add Authentication Source**

**Testing:**

```bash
# Access Gitea
open https://git.${DOMAIN}

# Click "Sign in with OpenID" or look for Authentik button
# Complete login flow
```

### Outline

**Status:** ✅ Auto-configured

Outline has native OIDC support with seamless integration.

**Features:**
- Single sign-on via Authentik
- Automatic user creation
- Team-based access control

**Configuration (already in docker-compose.yml):**

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

**Testing:**

```bash
# Access Outline
open https://docs.${DOMAIN}

# Click "Continue with Authentik"
# Complete login flow
```

### Open WebUI

**Status:** ✅ Auto-configured

Open WebUI supports OIDC for user authentication.

**Features:**
- Email-based account merging
- Auto-registration
- Seamless SSO

**Configuration (already in docker-compose.yml):**

```yaml
environment:
  - ENABLE_OAUTH_SIGNUP=true
  - OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
  - OAUTH_PROVIDER_NAME=Authentik
  - OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
  - OAUTH_SCOPES=openid profile email
  - OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/
```

**Testing:**

```bash
# Access Open WebUI
open https://ai.${DOMAIN}

# Click "Sign in with Authentik"
# Complete login flow
```

### Nextcloud

**Status:** ⚠️ Requires manual app installation

Nextcloud requires the **Social Login** app to enable OIDC authentication.

**Step 1: Install Social Login App**

```bash
# Access Nextcloud container
docker exec -it nextcloud bash

# Install Social Login app
occ app:install sociallogin

# Exit container
exit
```

**Step 2: Configure Social Login**

1. Login to Nextcloud as admin
2. Go to **Settings → Additional Settings → Social Login**
3. Under **OpenID Connect**, click **Add custom OpenID Connect**
4. Fill in:
   - Internal name: `authentik`
   - Title: `Authentik`
   - Client ID: From `.env` (`NEXTCLOUD_OAUTH_CLIENT_ID`)
   - Client Secret: From `.env` (`NEXTCLOUD_OAUTH_CLIENT_SECRET`)
   - Discovery endpoint: `https://auth.${DOMAIN}/application/o/nextcloud/.well-known/openid-configuration`
5. Enable:
   - ✅ Allow users to connect
   - ✅ Create new users
   - ✅ Prevent creating an account if the email address exists in another account
6. Click **Save**

**Testing:**

```bash
# Access Nextcloud
open https://nextcloud.${DOMAIN}

# Click "Login with Authentik"
# Complete login flow
```

### Portainer

**Status:** ✅ Auto-configured (via ForwardAuth)

Portainer CE doesn't have native OIDC support, so it uses Traefik ForwardAuth middleware.

**Features:**
- Transparent SSO protection
- No user management in Portainer
- All authenticated users get access

**Configuration:**

Portainer is protected by the `authentik` middleware defined in `config/traefik/dynamic/authentik.yml`.

**Testing:**

```bash
# Access Portainer
open https://portainer.${DOMAIN}

# You should be redirected to Authentik login
# After authentication, redirected back to Portainer
```

**Note:** For granular access control and native OIDC in Portainer, upgrade to **Portainer Business Edition**.

### Prometheus

**Status:** ✅ Auto-configured (via ForwardAuth)

Prometheus uses ForwardAuth middleware for protection.

**Configuration (already in docker-compose.yml):**

```yaml
labels:
  - traefik.http.routers.prometheus.middlewares=authentik@file
```

**Testing:**

```bash
# Access Prometheus
open https://prometheus.${DOMAIN}

# You should be redirected to Authentik login
# After authentication, redirected back to Prometheus
```

---

## User Group Management

### Default Groups

The setup script creates three default user groups:

| Group | Description | Access Level |
|-------|-------------|--------------|
| `homelab-admins` | Full administrative access | All services + admin panels |
| `homelab-users` | Regular user access | Standard services only |
| `media-users` | Media-only access | Media services (Plex, Jellyfin, etc.) |

### Creating Groups via Authentik UI

1. Access Authentik Admin UI: `https://auth.${DOMAIN}/if/admin/`
2. Navigate to **Directory → Groups**
3. Click **Create**
4. Fill in:
   - Name: Group name
   - Description: Purpose of group
5. Click **Create**

### Assigning Users to Groups

1. In Authentik Admin UI, go to **Directory → Users**
2. Click on a user
3. Go to **Groups** tab
4. Click **Add to existing group**
5. Select group(s) and click **Add**

### Service-Specific Groups

For granular access control, create service-specific groups:

**Grafana:**
- `Grafana Admins` → Admin role
- `Grafana Editors` → Editor role
- `Grafana Viewers` → Viewer role (default)

**Nextcloud:**
- Create groups in Nextcloud to match Authentik groups
- Configure group mapping in Social Login app

**Custom Groups:**

```bash
# Add custom group via API
curl -X POST "https://auth.${DOMAIN}/api/v3/core/groups/" \
  -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "developers",
    "description": "Development team members"
  }'
```

---

## Troubleshooting

### Common Issues

#### 1. Authentik not starting

**Symptom:** Containers exit immediately or keep restarting

**Check:**

```bash
# Check logs
docker compose -f stacks/sso/docker-compose.yml logs authentik-server

# Common causes:
# - Missing AUTHENTIK_SECRET_KEY
# - Database connection refused
# - Redis connection refused
```

**Fix:**

```bash
# Verify .env has all required variables
grep AUTHENTIK stacks/sso/.env

# Ensure database is healthy
docker compose -f stacks/sso/docker-compose.yml ps postgresql

# Restart stack
docker compose -f stacks/sso/docker-compose.yml restart
```

#### 2. OIDC redirect mismatch

**Symptom:** Error: "redirect_uri_mismatch" or "Invalid redirect URI"

**Cause:** Redirect URI in Authentik provider doesn't match service configuration

**Fix:**

1. Check service's callback URL in its documentation
2. Update provider in Authentik Admin UI
3. Or re-run setup script:

```bash
./scripts/authentik-setup.sh
```

#### 3. ForwardAuth infinite loop

**Symptom:** Browser keeps redirecting between service and Authentik

**Cause:** Middleware configuration issue or outpost not running

**Fix:**

```bash
# Check Authentik outpost is running
docker compose -f stacks/sso/docker-compose.yml logs authentik-server | grep outpost

# Verify middleware configuration
cat config/traefik/dynamic/authentik.yml

# Ensure internal URL is correct
grep "authentik-server:9000" config/traefik/dynamic/authentik.yml
```

#### 4. Can't login after setup

**Symptom:** "Invalid credentials" or login page refreshes

**Fix:**

```bash
# Check admin credentials in .env
grep AUTHENTIK_ADMIN stacks/sso/.env

# Reset admin password via container
docker exec -it authentik-server ak reset_admin_password

# Or create new admin user
docker exec -it authentik-server ak create_admin_user
```

#### 5. Nextcloud Social Login not working

**Symptom:** "Login failed" or no Authentik option appears

**Fix:**

```bash
# Verify app is installed
docker exec -it nextcloud occ app:list | grep sociallogin

# Reinstall if needed
docker exec -it nextcloud occ app:install sociallogin

# Check configuration
docker exec -it nextcloud occ config:app:get sociallogin custom_oidc
```

#### 6. Grafana role mapping not working

**Symptom:** All users get Viewer role regardless of group

**Fix:**

1. Check group names match exactly (case-sensitive)
2. Verify user is in correct Authentik group
3. Check Grafana environment variable:

```bash
grep ROLE_ATTRIBUTE_PATH stacks/monitoring/docker-compose.yml
```

Should be:
```yaml
- GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

### Debug Mode

**Enable verbose logging:**

```yaml
# In stacks/sso/.env
AUTHENTIK_LOG_LEVEL=debug
```

```bash
# Restart to apply
docker compose -f stacks/sso/docker-compose.yml restart

# Watch logs
docker compose -f stacks/sso/docker-compose.yml logs -f
```

### Health Checks

```bash
# Check all services are healthy
docker compose -f stacks/sso/docker-compose.yml ps

# Authentik API health
curl -f https://auth.${DOMAIN}/-/health/ready/

# Database connectivity
docker exec -it authentik-postgres pg_isready -U authentik

# Redis connectivity
docker exec -it authentik-redis redis-cli -a ${AUTHENTIK_REDIS_PASSWORD} ping
```

---

## Advanced Configuration

### Custom OIDC Scopes

By default, the setup uses `openid profile email` scopes. To add custom scopes:

1. Access Authentik Admin UI
2. Go to **Customization → Property Mappings**
3. Click **Create** → **Scope Mapping**
4. Define custom claims
5. Add scope to provider configuration

### Multi-Domain Setup

To use Authentik across multiple domains:

```yaml
# In stacks/sso/docker-compose.yml
environment:
  - AUTHENTIK_COOKIE_DOMAIN=${DOMAIN}
```

### High Availability

For production HA setup:

1. Use external PostgreSQL cluster
2. Use external Redis cluster
3. Deploy multiple Authentik workers
4. Configure load balancer for Authentik servers

**Example docker-compose.ha.yml:**

```yaml
services:
  authentik-server-1:
    <<: *authentik-base
    command: server
    
  authentik-server-2:
    <<: *authentik-base
    command: server
    
  authentik-worker-1:
    <<: *authentik-base
    command: worker
    
  authentik-worker-2:
    <<: *authentik-base
    command: worker
```

### Backup and Restore

**Backup:**

```bash
# Backup database
docker exec authentik-postgres pg_dump -U authentik authentik > authentik_backup_$(date +%Y%m%d).sql

# Backup media and templates
docker run --rm -v authentik_media:/data -v $(pwd):/backup alpine tar czf /backup/authentik_media_$(date +%Y%m%d).tar.gz /data

# Backup .env
cp stacks/sso/.env stacks/sso/.env.backup
```

**Restore:**

```bash
# Restore database
cat authentik_backup_20250101.sql | docker exec -i authentik-postgres psql -U authentik authentik

# Restore media
docker run --rm -v authentik_media:/data -v $(pwd):/backup alpine sh -c "cd / && tar xzf /backup/authentik_media_20250101.tar.gz"

# Restore .env
cp stacks/sso/.env.backup stacks/sso/.env
docker compose -f stacks/sso/docker-compose.yml restart
```

### Performance Tuning

**PostgreSQL:**

```yaml
environment:
  POSTGRES_SHARED_BUFFERS: 256MB
  POSTGRES_MAX_CONNECTIONS: 200
```

**Redis:**

```yaml
command: redis-server --requirepass ${AUTHENTIK_REDIS_PASSWORD} --maxmemory 512mb --maxmemory-policy allkeys-lru
```

**Authentik Workers:**

```yaml
environment:
  - AUTHENTIK_WORKER__CONCURRENCY=4
```

---

## Security Best Practices

1. **Use Strong Passwords**
   - Minimum 16 characters for admin password
   - Use password manager
   - Rotate secrets regularly

2. **Enable MFA**
   - Configure TOTP in Authentik
   - Enforce MFA for admin group
   - Consider WebAuthn for hardware keys

3. **Restrict Admin Access**
   - Only add trusted users to `homelab-admins` group
   - Use IP-based restrictions if possible
   - Enable audit logging

4. **Regular Updates**
   - Keep Authentik updated
   - Watch for security advisories
   - Test updates in staging first

5. **Network Security**
   - Use HTTPS only
   - Configure firewall rules
   - Consider VPN for admin access

6. **Backup Strategy**
   - Daily automated backups
   - Test restore procedure
   - Off-site backup storage

---

## Additional Resources

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik Integration Docs](https://docs.goauthentik.io/docs/integrations/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [OIDC Specification](https://openid.net/connect/)

---

## Support

For issues specific to this HomeLab stack:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review container logs
3. Check GitHub issues for the homelab-stack repository
4. Consult Authentik community resources

---

*Last updated: 2025-01-08*
