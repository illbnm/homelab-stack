# Authentik SSO & Identity Stack

Unified authentication and authorization platform featuring Authentik Server, background worker, dedicated PostgreSQL database, and Redis cache.

## Services Included

| Service | Version | Web Endpoint | Description |
|---|---|---|---|
| **Authentik Server** | `2024.8.3` | `https://auth.${DOMAIN}` | OIDC, OAuth2, and SAML Identity Provider |
| **Authentik Worker** | `2024.8.3` | Background | Background task execution & user sync worker |
| **PostgreSQL** | `16.4-alpine` | Internal (5432) | Dedicated identity state database |
| **Redis** | `7.4.0-alpine` | Internal (6379) | High-speed authentication session cache |

## Automated Provisioning CLI

Use `scripts/authentik-setup.sh` to auto-provision all 6 core OIDC applications:

```bash
# Preview credentials and redirect URIs without modifying server
bash scripts/authentik-setup.sh --dry-run

# Run full configuration
bash scripts/authentik-setup.sh
```

## Traefik ForwardAuth Middleware

For applications lacking native OIDC support, protect them using the ForwardAuth middleware:

```yaml
# config/traefik/dynamic/middlewares.yml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
```

## Group Hierarchy

- `homelab-admins`: Global administrator privileges across all services.
- `homelab-users`: General homelab access to productivity and tools.
- `media-users`: Restricted entertainment group only granting Jellyfin/Jellyseerr access.

## Quick Start

```bash
cp stacks/sso/.env.example stacks/sso/.env
docker compose -f stacks/sso/docker-compose.yml up -d
```
