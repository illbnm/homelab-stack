# SSO Stack — Authentik

Unified identity authentication with OIDC/SAML support.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Authentik | `https://auth.${DOMAIN}` | OIDC/SAML identity provider |
| Authentik Worker | internal | Background tasks |
| PostgreSQL | internal | Authentik database |
| Redis | internal | Authentik cache |

## Quick Start

```bash
cd stacks/sso
docker compose up -d
```

First login: `https://auth.${DOMAIN}` with credentials from `.env`.

## OIDC Integration

Run the setup script after Authentik is healthy:

```bash
export AUTHENTIK_TOKEN="your-api-token"
./scripts/setup-authentik.sh
```

This creates OIDC providers for all services and outputs Client ID/Secret.

### Service Configuration

| Service | Config Location | Redirect URI |
|---------|----------------|--------------|
| Grafana | `config/grafana/grafana.ini` | `/login/generic_oauth` |
| Gitea | `stacks/productivity/.env` | `/user/oauth2/authentik/callback` |
| Nextcloud | `scripts/nextcloud-oidc-setup.sh` | `/apps/sociallogin/custom_oidc/authentik` |
| Outline | `stacks/productivity/.env` | `/auth/oidc.callback` |
| Open WebUI | `stacks/ai/.env` | `/oauth/oidc/callback` |
| Portainer | `stacks/base/.env` | root URL |

### Grafana OIDC Config

Add to `config/grafana/grafana.ini`:
```ini
[auth.generic_oauth]
enabled = true
name = Authentik
client_id = <from setup script>
client_secret = <from setup script>
auth_url = https://auth.${DOMAIN}/application/o/authorize/
token_url = https://auth.${DOMAIN}/application/o/token/
api_url = https://auth.${DOMAIN}/application/o/userinfo/
scopes = openid profile email
```

## Environment Variables

```bash
AUTHENTIK_SECRET_KEY=<random-64-chars>
AUTHENTIK_DB_PASSWORD=<strong-password>
AUTHENTIK_ADMIN_EMAIL=admin@example.com
AUTHENTIK_ADMIN_PASSWORD=<admin-password>
AUTHENTIK_TOKEN=<api-token-for-setup-script>
```
