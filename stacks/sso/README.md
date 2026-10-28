# 🔐 Authentik SSO Stack (OIDC, SAML, ForwardAuth)

Complete Single Sign-On and Identity Provider (IdP) for the entire HomeLab Stack.

## 📦 Services
- **Authentik Server (`2024.8.3`):** Web GUI, OAuth2 / OpenID Connect / SAML provider, directory sync.
- **Authentik Worker (`2024.8.3`):** Background asynchronous task queue and discovery runner.
- **PostgreSQL (`16.4-alpine`):** Dedicated transactional database for users, tokens, and scopes.
- **Redis (`7.4.0-alpine`):** In-memory cache and worker broker.

## 🚀 Getting Started
1. Copy `.env.example` to `.env` and fill in secrets:
   ```bash
   cp .env.example .env
   ```
2. Start the stack:
   ```bash
   docker compose up -d
   ```
3. Initialize OIDC clients across the fleet:
   ```bash
   ./scripts/authentik-setup.sh
   ```

## 🛡️ Traefik ForwardAuth
For legacy or lightweight services that do not natively support OIDC, Traefik ForwardAuth middleware is configured in `config/traefik/dynamic/middlewares.yml`.
Attach the middleware label to any service:
```yaml
labels:
  - "traefik.http.routers.myservice.middlewares=authentik@file"
```

## 👥 Predefined Groups
- `homelab-admins`: Grants administrative access across Portainer, Grafana, Traefik.
- `homelab-users`: General access to Nextcloud, Gitea, Outline.
- `media-users`: Restricted access only to Jellyfin and Jellyseerr.
