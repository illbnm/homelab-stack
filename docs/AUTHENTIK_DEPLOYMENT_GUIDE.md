# Authentik SSO Stack — Complete Deployment Guide

This guide walks through deploying and configuring the Authentik SSO stack for your HomeLab.

## Overview

**What you'll get:**
- ✅ Authentik Server + Worker + PostgreSQL + Redis
- ✅ OIDC providers for: Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
- ✅ Traefik ForwardAuth middleware for services without OIDC
- ✅ User groups: homelab-admins, homelab-users, media-users
- ✅ Automatic OAuth credential generation

**Time required:** 30-45 minutes

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Docker and Docker Compose installed
- [ ] Base stack running (Traefik + proxy network)
- [ ] Domain name with DNS pointing to your server
- [ ] Ports 80 and 443 open
- [ ] Root .env file configured (copy from .env.example)
- [ ] `curl`, `jq`, `openssl` installed

Check dependencies:

```bash
./scripts/check-deps.sh
```

## Step-by-Step Deployment

### Step 1: Configure Root Environment

If you haven't already, create the root `.env` file:

```bash
cd /path/to/homelab-stack

# Copy example
cp .env.example .env

# Edit with your values
nano .env
```

**Required values:**

```bash
# General
DOMAIN=yourdomain.com
ACME_EMAIL=admin@yourdomain.com
TZ=Asia/Shanghai

# Databases (if not already set)
POSTGRES_PASSWORD=<strong-password>
REDIS_PASSWORD=<strong-password>
MARIADB_ROOT_PASSWORD=<strong-password>
```

Generate strong passwords:

```bash
# PostgreSQL password
export POSTGRES_PASSWORD=$(openssl rand -hex 16)
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env

# Redis password
export REDIS_PASSWORD=$(openssl rand -hex 16)
sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env

# MariaDB root password
export MARIADB_ROOT_PASSWORD=$(openssl rand -hex 16)
sed -i "s|^MARIADB_ROOT_PASSWORD=.*|MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD|" .env
```

### Step 2: Generate Authentik Secrets

Generate all required Authentik secrets:

```bash
# Generate secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed- i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env
```

### Step 3: Configure Admin Account

Set your initial admin credentials:

```bash
nano .env
```

Set these values:

```bash
AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com
AUTHENTIK_BOOTSTRAP_PASSWORD=<strong-admin-password>
```

⚠️ **Important:** Use a strong password! This is your initial admin account.

### Step 4: Deploy Authentik Stack

Start the SSO stack:

```bash
cd stacks/sso

# Start services
docker compose up -d

# Watch logs
docker compose logs -f
```

Wait for all services to be healthy (~60-90 seconds on first run):

```bash
docker compose ps
```

Expected output:

```
NAME                 STATUS              PORTS
authentik-server     healthy
authentik-worker     running
authentik-postgres   healthy
authentik-redis      healthy
```

### Step 5: Verify Authentik is Running

Check that Authentik is accessible:

```bash
# From host
curl -sf https://auth.${DOMAIN}/-/health/ready/ && echo "OK"

# From inside Docker
docker exec authentik-server curl -sf http://localhost:9000/-/health/ready/ && echo "OK"
```

### Step 6: Create OIDC Providers

Run the setup script to create OIDC providers for all services:

```bash
cd ../..

# Test in dry-run mode first
./scripts/authentik-setup.sh --dry-run

# If everything looks good, run for real
./scripts/authentik-setup.sh
```

This script will:
1. Wait for Authentik API to be ready
2. Create OIDC providers for each service
3. Generate client IDs and secrets
4. Update `.env` file with credentials
5. Create user groups
6. Create applications in Authentik

**Expected output:**

```
==> Waiting for Authentik API...
[INFO] Authentik is ready

==> Creating OIDC Providers and Applications
==> Creating OIDC provider: Grafana
  Provider PK: 1
  Client ID:   abc123...
  Client Secret: xyz789...
  Updated .env with credentials
  Application created: Grafana

==> Creating OIDC provider: Gitea
  ...

==> Creating User Groups
==> Creating user group: homelab-admins
  User group created: homelab-admins
...

==> Setup Complete
[INFO] Authentik OIDC issuer: https://auth.yourdomain.com/application/o/
[INFO] Authentik URL: https://auth.yourdomain.com
```

### Step 7: Verify OAuth Credentials

Check that OAuth credentials were generated:

```bash
grep OAUTH .env
```

Expected output:

```
GRAFANA_OAUTH_CLIENT_ID=abc123...
GRAFANA_OAUTH_CLIENT_SECRET=xyz789...
GITEA_OAUTH_CLIENT_ID=def456...
GITEA_OAUTH_CLIENT_SECRET=uvw123...
...
```

### Step 8: Restart Services with OIDC

Restart services that need the new OAuth credentials:

```bash
# Grafana
docker compose -f stacks/monitoring/docker-compose.yml restart grafana

# Gitea
docker compose -f stacks/productivity/docker-compose.yml restart gitea

# Outline
docker compose -f stacks/productivity/docker-compose.yml restart outline

# Open WebUI
docker compose -f stacks/ai/docker-compose.yml restart open-webui

# Nextcloud
docker compose -f stacks/storage/docker-compose.yml restart nextcloud
```

### Step 9: Configure Nextcloud Social Login

Nextcloud requires additional setup:

```bash
# Install Social Login app
docker exec -it nextcloud occ app:install sociallogin

# Enable auto-registration
docker exec -it nextcloud occ config:app:set sociallogin allow_create_user --value=1
docker exec -it nextcloud occ config:app:set sociallogin prevent_create_user --value=0
```

Then configure OIDC in Nextcloud admin UI:
1. Login as admin
2. Go to Settings → Administration → Social login
3. Add Custom OIDC provider with values from `.env`

### Step 10: Test Login Flows

Test each service:

#### Grafana
1. Visit `https://grafana.${DOMAIN}`
2. Click "Sign in with Authentik"
3. Login with admin credentials
4. Should redirect back to Grafana logged in

#### Gitea
1. Visit `https://git.${DOMAIN}`
2. Click "Sign in with OpenID"
3. Enter Authentik domain
4. Login and authorize
5. Should create Gitea account automatically

#### Outline
1. Visit `https://docs.${DOMAIN}`
2. Should automatically redirect to Authentik
3. Login
4. Should create Outline account and show dashboard

#### Open WebUI
1. Visit `https://ai.${DOMAIN}`
2. Click "Login with Authentik"
3. Login
4. Should create account and show chat interface

#### Portainer (CE)
1. Visit `https://portainer.${DOMAIN}`
2. Should redirect to Authentik (ForwardAuth)
3. Login
4. Should access Portainer

### Step 11: Configure User Groups

Login to Authentik admin UI:

1. Visit `https://auth.${DOMAIN}/if/admin/`
2. Go to **Directory → Users**
3. Create users and assign to groups:
   - `homelab-admins`: Full admin access
   - `homelab-users`: Standard access
   - `media-users`: Media services only

### Step 12: Run Health Check

Verify everything is working:

```bash
./scripts/check-sso-health.sh --verbose
```

Expected output:

```
=== Authentik SSO Health Check ===

[1/6] Checking Docker Services...
✓ authentik-server is running
✓ authentik-worker is running
✓ authentik-postgres is running
✓ authentik-redis is running
✓ authentik-server health: healthy
✓ authentik-postgres health: healthy
✓ authentik-redis health: healthy

[2/6] Checking Environment Variables...
✓ AUTHENTIK_SECRET_KEY is set
✓ AUTHENTIK_POSTGRES_PASSWORD is set
✓ AUTHENTIK_REDIS_PASSWORD is set
✓ AUTHENTIK_BOOTSTRAP_TOKEN is set
✓ GRAFANA_OAUTH_CLIENT_ID configured
✓ GITEA_OAUTH_CLIENT_ID configured
...

[3/6] Checking Network Connectivity...
✓ Authentik API is reachable
✓ OIDC discovery endpoint accessible
✓ Authentik internal health check OK

[4/6] Checking Database Connectivity...
✓ PostgreSQL is ready
✓ Redis is responding

[5/6] Checking OIDC Providers...
✓ 6 OIDC providers configured
✓ 6 applications configured
✓ 3 user groups configured

[6/6] Checking Service Integrations...
✓ Grafana OIDC configured
✓ Gitea OIDC configured
✓ Outline OIDC configured
✓ Open WebUI OIDC configured
✓ Nextcloud OIDC configured
✓ Portainer using ForwardAuth
✓ Traefik ForwardAuth middleware configured

=== Summary ===
Passed: 35
Failed: 0
Warnings: 0

✓ SSO stack is healthy
```

## Troubleshooting

### Authentik won't start

**Check logs:**

```bash
docker compose -f stacks/sso/docker-compose.yml logs authentik-server
```

**Common issues:**
- Missing `AUTHENTIK_SECRET_KEY`: Generate and set in `.env`
- Database connection refused: Wait longer or check PostgreSQL password
- Permission errors: Ensure volumes are writable

### Setup script fails

**Check prerequisites:**

```bash
# Is Authentik running?
docker ps | grep authentik

# Is API accessible?
curl -sf https://auth.${DOMAIN}/-/health/ready/

# Is token correct?
grep AUTHENTIK_BOOTSTRAP_TOKEN .env
```

**Manual token creation:**

If you need to create a new token:

1. Login to Authentik admin UI
2. Go to **Directory → Tokens**
3. Create new token with these settings:
   - Identifier: `setup-token`
   - User: `akadmin`
   - Intent: `API`
4. Copy token to `.env`:

```bash
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=<your-token>|" .env
```

### Services can't connect to Authentik

**Check from inside container:**

```bash
# Grafana
docker exec grafana curl -sf http://authentik-server:9000/-/health/ready/

# Gitea
docker exec gitea curl -sf http://authentik-server:9000/-/health/ready/
```

**If connection fails:**
- Ensure all services are on `proxy` network
- Check Docker network: `docker network inspect proxy`
- Restart affected service

### OAuth redirect mismatch

**Symptoms:**
- "redirect_uri_mismatch" error
- Infinite redirects

**Fix:**

1. Check exact callback URL in service documentation
2. Update `scripts/authentik-setup.sh` with correct URL
3. Re-run setup script

**Common callback URLs:**

| Service | Callback URL |
|---------|-------------|
| Grafana | `https://grafana.DOMAIN/login/generic_oauth` |
| Gitea | `https://git.DOMAIN/user/oauth2/Authentik/callback` |
| Outline | `https://docs.DOMAIN/auth/oidc.callback` |
| Open WebUI | `https://ai.DOMAIN/oauth/oidc/callback` |
| Nextcloud | `https://nextcloud.DOMAIN/apps/social_login/oidc/callback` |

### ForwardAuth loop

**Symptoms:**
- Browser keeps redirecting between service and Authentik
- Never completes login

**Fix:**

Ensure ForwardAuth uses **internal hostname**:

```yaml
# CORRECT
forwardAuth:
  address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"

# WRONG (causes loop)
forwardAuth:
  address: "https://auth.DOMAIN/outpost.goauthentik.io/auth/traefik"
```

Check `config/traefik/dynamic/authentik.yml`.

## Advanced Configuration

### Enable MFA

1. Login to Authentik admin UI
2. Go to **Flows and Stages → Stages**
3. Create **Authenticator Validate Stage**
4. Add to default authentication flow

### Custom Branding

1. Admin UI → **Customization → Brands**
2. Edit default brand
3. Upload logo, set colors, customize login page

### Email Notifications

1. Admin UI → **System → Settings**
2. Configure SMTP settings
3. Test email sending

### Backup Schedule

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/homelab-stack/scripts/backup-databases.sh >> /var/log/homelab-backup.log 2>&1
```

## Security Recommendations

1. **Strong passwords**: Use `openssl rand -hex 16` or better
2. **Enable MFA**: For admin accounts at minimum
3. **Regular updates**: `docker compose pull && docker compose up -d`
4. **Monitor logs**: Check Authentik events regularly
5. **Restrict admin access**: Use `homelab-admins` group sparingly
6. **Enable rate limiting**: Configure in Authentik policies
7. **Regular backups**: Backup PostgreSQL volume weekly

## Next Steps

- [Add custom applications](SSO_INTEGRATION_GUIDE.md)
- [Configure MFA](https://docs.goauthentik.io/docs/flow/stages/authenticator_totp/)
- [Set up backup automation](../scripts/backup-databases.sh)
- [Monitor authentication events](https://docs.goauthentik.io/docs/events/)

## Support

- **Documentation:** `/homelab-stack/docs/SSO_INTEGRATION_GUIDE.md`
- **Authentik Docs:** https://docs.goauthentik.io/
- **Issues:** https://github.com/goauthentik/authentik/issues

---

**Congratulations!** Your SSO stack is now deployed and integrated with all services. Users can now login once and access all HomeLab services seamlessly.
