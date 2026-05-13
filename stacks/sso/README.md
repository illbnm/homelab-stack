# SSO Stack

This stack provides a single sign-on (SSO) solution using Authentik.

## Services

* Authentik Server: `ghcr.io/goauthentik/server:2024.8.3`
* Authentik Worker: `ghcr.io/goauthentik/server:2024.8.3`
* PostgreSQL: `postgres:16.4-alpine`
* Redis: `redis:7.4.0-alpine`

## Setup

Copy `.env.example` to `.env` and fill in the values, **or** run the setup script which generates credentials automatically:

```bash
bash scripts/authentik-setup.sh
```

Use `--dry-run` to preview without writing files.

## Configuration

* Authentik is accessible at `https://${AUTHENTIK_DOMAIN}`
* Credentials are set via `AUTHENTIK_BOOTSTRAP_EMAIL` / `AUTHENTIK_BOOTSTRAP_PASSWORD` in `.env`
* Never commit `.env`; commit only `.env.example`

## Integrations

* Grafana: OIDC integration
* Gitea: OIDC integration
* Nextcloud: OIDC integration
* Outline: OIDC integration
* Open WebUI: OIDC integration
* Portainer: OIDC integration

## Acceptance Evidence

* Screenshots of successful login and access to services
* Configuration files for each service
