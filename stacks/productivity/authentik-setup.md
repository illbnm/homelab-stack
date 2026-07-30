# Authentik Application Setup Guide for Productivity Stack

This guide covers configuring Authentik OIDC for Gitea, Outline, and Vaultwarden.

## Prerequisites

- Authentik running from the SSO stack (`stacks/sso/`)
- Domain configured with Traefik and HTTPS working

## 1. Gitea OIDC Setup

### In Authentik:
1. Go to **Admin Interface → Applications → Providers**
2. Create new **OAuth2/OpenID Provider**:
   - Name: `Gitea`
   - Authorization flow: default
   - Client type: Confidential
   - Redirect URIs: `https://gitea.${DOMAIN}/user/oauth2/auth/callback`
   - Scopes: `openid profile email`
3. Note the **Client ID** and **Client Secret**

### In Gitea:
1. Login as admin (first registered user or via CLI)
2. Go to **Site Administration → Authentication Sources → Add OAuth2**
3. Configure:
   - Provider name: `Authentik`
   - OAuth2 provider: `OpenID Connect`
   - Client ID: (from Authentik)
   - Client Secret: (from Authentik)
   - OpenID Connect Auto Discovery URL: `https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration`
4. Enable for existing users and new registrations

## 2. Outline OIDC Setup

### In Authentik:
1. Create new **OAuth2/OpenID Provider**:
   - Name: `Outline`
   - Redirect URIs:
     - `https://docs.${DOMAIN}/auth/oidc.callback`
     - `https://docs.${DOMAIN}/auth/oidc`
   - Scopes: `openid profile email`
2. Note the **Client ID** and **Client Secret**
3. Set the following in your `.env`:
   - `OUTLINE_OIDC_CLIENT_ID` = Client ID
   - `OUTLINE_OIDC_CLIENT_SECRET` = Client Secret

### In Authentik Application:
1. Create an Application bound to the Outline provider
2. Ensure the OIDC endpoints match:
   - Issuer: `https://auth.${DOMAIN}/application/o/outline/`

## 3. Vaultwarden

Vaultwarden does not use OIDC directly. It has its own auth system.
- Users are invited by admin via the admin panel at `https://vault.${DOMAIN}/admin`
- Access admin panel with `ADMIN_TOKEN` from `.env`
- Invite users via email (requires SMTP configured)

## MinIO Bucket for Outline

After starting the storage stack with MinIO:
```bash
# Create bucket for Outline
docker exec -it minio mc mb minio/outline
docker exec -it minio mc anonymous set download minio/outline
```