# SSO Stack

Authentik unified identity provider.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Authentik | 2024.10 | `auth.${DOMAIN}` | Identity provider |
| Authentik Worker | 2024.10 | — | Background tasks |

## Quick Start

```bash
# Generate secret key first
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -hex 32)" >> .env
docker compose -f stacks/sso/docker-compose.yml up -d
```
