# SSO Stack

Single Sign-On with Authentik - OIDC/SAML provider for all homelab services.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Authentik Server | `ghcr.io/goauthentik/server:2024.8.3` | 9000 | OIDC Provider |
| Authentik Worker | `ghcr.io/goauthentik/server:2024.8.3` | - | Background Tasks |
| PostgreSQL | `postgres:16.4-alpine` | 5432 | Authentik Database |
| Redis | `redis:7.4.0-alpine` | 6379 | Authentik Cache |

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

Generate secrets:
```bash
# Secret key
openssl rand -base64 60

# Database password
openssl rand -hex 32
```

### 2. Start Services

```bash
docker compose up -d
```

### 3. Initial Setup

1. Access https://auth.yourdomain.com/if/flow/initial-setup/
2. Create admin account
3. Login to Admin Dashboard

## OIDC Integration

### Supported Services

| Service | Redirect URI | Scopes |
|---------|--------------|--------|
| Grafana | `/login/generic_oauth` | openid profile email |
| Gitea | `/user/oauth2/authentik/callback` | openid profile email |
| Outline | `/auth/oidc.callback` | openid profile email |
| Vaultwarden | `/admin/oidc/callback` | openid profile email |
| Nextcloud | `/apps/oidclogin/redirect` | openid profile email |
| Jellyfin | `/sso/OIDC/rp` | openid profile email |

### Create OIDC Application

#### Via Script

```bash
# Create single application
./scripts/setup-oidc.sh create grafana

# Create all applications
./scripts/setup-oidc.sh create-all
```

#### Via Admin UI

1. Authentik Admin → Applications → Create
2. Select "OAuth2/OpenID Provider"
3. Configure:
   - Client Type: Confidential
   - Redirect URIs: See table above
   - Scopes: openid, profile, email
   - Signing Key: default-signing-key

### Service Configuration

#### Grafana

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=<client_id>
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=<client_secret>
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.yourdomain.com/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.yourdomain.com/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.yourdomain.com/application/o/userinfo/
```

#### Gitea

```yaml
environment:
  - GITEA__openid__ENABLE_OPENID_SIGNIN=true
  - GITEA__openid__WHITELISTED_URIS=auth.yourdomain.com
```

Configure in Gitea UI:
1. Site Administration → Authentication Sources
2. Add OAuth2 Application
3. Redirect URI: `https://git.yourdomain.com/user/oauth2/authentik/callback`

#### Outline

```yaml
environment:
  - OIDC_CLIENT_ID=<client_id>
  - OIDC_CLIENT_SECRET=<client_secret>
  - OIDC_AUTH_URI=https://auth.yourdomain.com/application/o/authorize/
  - OIDC_TOKEN_URI=https://auth.yourdomain.com/application/o/token/
  - OIDC_USERINFO_URI=https://auth.yourdomain.com/application/o/userinfo/
```

#### Nextcloud

Install OIDC Login app:
```bash
docker exec -it nextcloud php occ app:install oidc_login
```

Configure in `config.php`:
```php
'oidc_login_provider_url' => 'https://auth.yourdomain.com/application/o/',
'oidc_login_client_id' => '<client_id>',
'oidc_login_client_secret' => '<client_secret>',
```

## Forward Authentication

For services without OIDC support, use Traefik middleware:

```yaml
labels:
  - traefik.http.routers.<service>.middlewares=authentik
```

This redirects unauthenticated users to Authentik login.

## LDAP (Optional)

Authentik provides LDAP for legacy applications:

1. Create LDAP Provider
2. Configure bind DN and password
3. Point legacy apps to `authentik-server:3389`

## Health Checks

```bash
# Authentik Server
curl -sf http://localhost:9000/health/ready

# Authentik Worker
curl -sf http://localhost:9000/health/ready

# PostgreSQL
docker exec authentik-postgres pg_isready -U authentik

# Redis
docker exec authentik-redis redis-cli ping
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Authentik Server | 256 MB | 512 MB - 1 GB |
| Authentik Worker | 128 MB | 256 MB |
| PostgreSQL | 64 MB | 128 MB |
| Redis | 32 MB | 64 MB |
| **Total** | **480 MB** | **1 GB** |

## Security Notes

1. **Strong secrets** - Use 60+ char secret keys
2. **Bootstrap credentials** - Change after initial setup
3. **Email verification** - Enable for new users
4. **MFA** - Enable for admin accounts
5. **Rate limiting** - Configure in Authentik policies

## Troubleshooting

### Authentik Not Starting

```bash
# Check logs
docker logs authentik-server

# Check database connection
docker exec authentik-postgres pg_isready

# Check redis connection
docker exec authentik-redis redis-cli ping
```

### OIDC Login Failed

```bash
# Check client credentials
curl https://auth.yourdomain.com/application/o/<app>/.well-known/openid-configuration

# Verify redirect URI matches exactly
```

### Forward Auth Not Working

```bash
# Check middleware
curl http://localhost:8080/api/http/middlewares

# Verify outpost is running
docker logs authentik-server | grep outpost
```

## License

MIT
