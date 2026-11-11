# SSO Unified Authentication Stack (Authentik)

Provides centralized Single Sign-On (OIDC / OAuth2) and Traefik ForwardAuth protection across all Homelab stacks.

## Architecture

```
Internet ──► Traefik (443) ──┬──► Authentik ForwardAuth (/outpost.goauthentik.io/auth/traefik)
                             │       └──► Non-OIDC Web UIs (Portainer, qBittorrent, Prowlarr)
                             └──► Native OIDC Providers (/application/o/<slug>/)
                                     └──► Grafana, Gitea, Nextcloud, Outline, Open WebUI
```

## Components & Pinned Versions

| Service | Image | Role |
|---------|-------|------|
| `authentik-server` | `ghcr.io/goauthentik/server:2024.8.3` | OIDC/OAuth2 IdP & Embedded ForwardAuth Outpost |
| `authentik-worker` | `ghcr.io/goauthentik/server:2024.8.3` | Background task & policy worker |
| `authentik-postgresql` | `postgres:16.4-alpine` | Primary identity database |
| `authentik-redis` | `redis:7.4.0-alpine` | Session & task queue store |

## Quick Start

```bash
cp stacks/sso/.env.example stacks/sso/.env
# Edit stacks/sso/.env with strong secrets
docker compose -f stacks/sso/docker-compose.yml up -d
bash scripts/authentik-setup.sh --dry-run
bash scripts/authentik-setup.sh
```
