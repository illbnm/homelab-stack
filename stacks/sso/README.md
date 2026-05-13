# SSO Stack - Authentik Unified Identity

This stack provides Authentik SSO for the homelab. Authentik is exposed at
`https://auth.${DOMAIN}` and is used in two ways:

- Native OIDC for Grafana, Gitea, Nextcloud, Outline, Open WebUI, and Portainer.
- Traefik ForwardAuth middleware for services that do not support OIDC.

## Services

| Service | Image | Purpose |
| --- | --- | --- |
| authentik-server | `ghcr.io/goauthentik/server:2024.8.3` | Web UI, API, OIDC endpoints |
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | Background tasks and outpost work |
| postgresql | `postgres:16.4-alpine` | Authentik database |
| redis | `redis:7.4.0-alpine` | Cache and task queue |

## Quick Start

```bash
cp ../../.env.example ../../.env
cp .env.example .env

# Fill the required values in both files, then:
docker network create proxy 2>/dev/null || true
docker compose up -d

# Preview the Authentik API changes:
../../scripts/authentik-setup.sh --dry-run

# Create/update Authentik groups, providers, and applications:
../../scripts/authentik-setup.sh
```

The setup script loads `../../.env` first and `stacks/sso/.env` second. It
updates only local `.env` files, which are ignored by git. It never writes
secrets to tracked examples or compose files.

## Required Variables

| Variable | Description |
| --- | --- |
| `DOMAIN` | Base domain, for example `home.example.com` |
| `AUTHENTIK_DOMAIN` | Authentik domain, normally `auth.${DOMAIN}` |
| `AUTHENTIK_SECRET_KEY` | Generate with `openssl rand -base64 32` |
| `AUTHENTIK_DB_PASSWORD` | Authentik PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | Authentik Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | Admin API token used by setup scripts |

## Created Authentik Objects

Groups:

- `homelab-admins`
- `homelab-users`
- `media-users`

OIDC providers and applications:

| Application | Slug | Redirect URI |
| --- | --- | --- |
| Grafana | `grafana` | `https://grafana.${DOMAIN}/login/generic_oauth` |
| Gitea | `gitea` | `https://git.${DOMAIN}/user/oauth2/authentik/callback` |
| Nextcloud | `nextcloud` | `https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik` |
| Outline | `outline` | `https://docs.${DOMAIN}/auth/oidc.callback` |
| Open WebUI | `open-webui` | `https://ai.${DOMAIN}/oauth/oidc/callback` |
| Portainer | `portainer` | `https://portainer.${DOMAIN}/` |

The OIDC discovery URL pattern is:

```text
https://${AUTHENTIK_DOMAIN}/application/o/<slug>/.well-known/openid-configuration
```

## Service-Specific Setup

Grafana reads `config/grafana/grafana.ini` and the OAuth client credentials
created by `scripts/authentik-setup.sh`.

Gitea stores external OAuth sources in its database. After the Authentik setup
script writes `GITEA_OAUTH_CLIENT_ID` and `GITEA_OAUTH_CLIENT_SECRET`, run:

```bash
../../scripts/gitea-oidc-setup.sh
```

Nextcloud uses the Social Login app. After the Authentik setup script writes
`NEXTCLOUD_OAUTH_CLIENT_ID` and `NEXTCLOUD_OAUTH_CLIENT_SECRET`, run:

```bash
../../scripts/nextcloud-oidc-setup.sh
```

Outline and Open WebUI read OIDC settings directly from their compose
environment variables.

Portainer stores OAuth settings in its own database. Use:

- Client ID: `PORTAINER_OAUTH_CLIENT_ID`
- Client secret: `PORTAINER_OAUTH_CLIENT_SECRET`
- Authorization URL: `https://${AUTHENTIK_DOMAIN}/application/o/authorize/`
- Access token URL: `https://${AUTHENTIK_DOMAIN}/application/o/token/`
- Resource URL: `https://${AUTHENTIK_DOMAIN}/application/o/userinfo/`
- Redirect URL: `https://portainer.${DOMAIN}/`
- User identifier: `preferred_username`
- Scopes: `openid profile email`

## ForwardAuth

The single Traefik ForwardAuth middleware is defined in:

```text
config/traefik/dynamic/middlewares.yml
```

Use it on any router:

```yaml
traefik.http.routers.<name>.middlewares=authentik@file,security-headers@file
```

## Verification

```bash
../../scripts/authentik-setup.sh --dry-run
../../scripts/test-authentik-sso.sh
```

The test script checks compose validity for `base`, `sso`, `monitoring`,
`productivity`, `storage`, and `ai`, shell syntax for the SSO scripts, Authentik
health, OIDC discovery endpoints, and API presence of required groups/providers
when `AUTHENTIK_BOOTSTRAP_TOKEN` is available.
