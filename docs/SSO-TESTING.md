# SSO Testing Guide

This document provides step-by-step testing procedures for the SSO implementation.

## Prerequisites

1. All stacks are running
2. `.env` is fully configured
3. Authentik is accessible at `https://auth.${DOMAIN}`

## Test Matrix

### 1. Authentik Setup

```bash
# Start SSO stack
cd stacks/sso
docker compose up -d

# Check logs
docker logs -f authentik-server
docker logs -f authentik-worker

# Verify health
curl -k https://auth.${DOMAIN}/-/health/ready/
```

**Expected**: HTTP 200 OK

### 2. OIDC Provider Creation

```bash
# Run setup script
./scripts/setup-authentik.sh --dry-run  # Preview
./scripts/setup-authentik.sh            # Execute

# Check .env for credentials
grep OAUTH_CLIENT .env
```

**Expected**: All `*_OAUTH_CLIENT_ID` and `*_OAUTH_CLIENT_SECRET` variables populated

### 3. Service Login Tests

#### Grafana

```bash
# Navigate to https://grafana.${DOMAIN}
# Click "Sign in with Authentik"
# Enter Authentik credentials
# Expected: Redirected to Grafana dashboard
```

**Screenshots Required**:
- Login button showing "Sign in with Authentik"
- Successful login dashboard

#### Gitea

```bash
# Navigate to https://git.${DOMAIN}
# Click "Sign In" → "Authentik"
# Enter Authentik credentials
# Expected: Redirected to Gitea with logged-in user
```

**Screenshots Required**:
- OAuth login button
- Successful profile page

#### Outline

```bash
# Navigate to https://docs.${DOMAIN}
# Click "Continue with Authentik"
# Enter Authentik credentials
# Expected: Outline workspace loads
```

**Screenshots Required**:
- Login page with Authentik option
- Document list view

#### Nextcloud

```bash
# Run OIDC setup
./scripts/nextcloud-oidc-setup.sh

# Navigate to https://cloud.${DOMAIN}
# Click "Login with Authentik"
# Enter Authentik credentials
# Expected: Nextcloud files view
```

**Screenshots Required**:
- Login page with OIDC option
- Files view after login

#### Open WebUI

```bash
# Navigate to https://ai.${DOMAIN}
# Click "Sign in with Authentik"
# Enter Authentik credentials
# Expected: Open WebUI chat interface
```

**Screenshots Required**:
- Login page with OAuth option
- Chat interface

#### Portainer

```bash
# Navigate to https://portainer.${DOMAIN}
# Go to Settings → Authentication
# Select OAuth
# Fill in credentials from .env
# Test login with Authentik user
```

**Screenshots Required**:
- OAuth configuration page
- Successful login

### 4. ForwardAuth Test

```bash
# Prometheus doesn't have native OIDC
# Uses ForwardAuth middleware
# Navigate to https://prometheus.${DOMAIN}
# Expected: Redirect to Authentik login, then to Prometheus
```

**Screenshots Required**:
- Authentik login page
- Prometheus UI after authentication

### 5. User Group Tests

#### Create Test Users

```bash
# Via Authentik UI or API:
# Create user in homelab-admins group
# Create user in homelab-users group
# Create user in media-users group
```

#### Test Access

| User Group | Grafana Admin | Nextcloud | Jellyfin |
|------------|--------------|-----------|----------|
| homelab-admins | ✅ | ✅ | ✅ |
| homelab-users | ❌ | ✅ | ✅ |
| media-users | ❌ | ❌ | ✅ |

## Acceptance Checklist

- [ ] Authentik Web UI accessible at `https://auth.${DOMAIN}`
- [ ] Admin login works
- [ ] `setup-authentik.sh` creates all providers
- [ ] Grafana SSO login works
- [ ] Gitea SSO login works
- [ ] Outline SSO login works
- [ ] Nextcloud SSO login works (after running setup script)
- [ ] Open WebUI SSO login works
- [ ] Portainer OAuth configured
- [ ] ForwardAuth protects Prometheus
- [ ] User groups created
- [ ] Group permissions enforced
- [ ] Screenshots provided for all services
- [ ] README includes SSO tutorial

## Troubleshooting

### Provider Creation Fails

```bash
# Check Authentik API
curl -H "Authorization: Bearer $TOKEN" \
  https://auth.${DOMAIN}/api/v3/providers/oauth2/

# Check logs
docker logs authentik-server | grep ERROR
```

### Login Fails

```bash
# Check service logs
docker logs grafana | grep oauth
docker logs nextcloud | grep oidc

# Check redirect URI matches
# Compare in Authentik UI and service config
```

### Token Issues

```bash
# Verify signing key
curl -H "Authorization: Bearer $TOKEN" \
  https://auth.${DOMAIN}/api/v3/crypto/certificatekeypairs/

# Check token validity
# Use jwt.io to decode tokens
```

## Screenshots Location

All verification screenshots should be placed in:

```
docs/screenshots/sso/
├── authentik-admin-dashboard.png
├── grafana-login.png
├── grafana-dashboard.png
├── gitea-login.png
├── gitea-profile.png
├── outline-login.png
├── outline-workspace.png
├── nextcloud-login.png
├── nextcloud-files.png
├── openwebui-login.png
├── openwebui-chat.png
├── portainer-oauth-config.png
├── prometheus-forwardauth.png
└── user-groups.png
```