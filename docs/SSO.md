# SSO — Onboarding a New Service to Authentik

This homelab uses [Authentik](https://goauthentik.io) (`stacks/sso/`) as the unified
Identity Provider. All services authenticate via OIDC where supported, or via Traefik
ForwardAuth for services without native OIDC.

## First-time setup

1. `cd stacks/sso && cp .env.example .env` — fill all values (`openssl rand -hex 32` for
   `AUTHENTIK_SECRET_KEY`).
2. `docker compose up -d` and wait for the `/-/health/ready/` healthcheck to pass.
3. Log in at `https://auth.${BASE_DOMAIN}` with the `AUTHENTIK_BOOTSTRAP_*` credentials.
4. Export `AUTHENTIK_DOMAIN`, `AUTHENTIK_BOOTSTRAP_TOKEN`, `BASE_DOMAIN`, then run
   `../../scripts/authentik-setup.sh --dry-run` followed by
   `../../scripts/authentik-setup.sh`. The script is idempotent and creates:
   - groups: `homelab-admins`, `homelab-users`, `media-users`
   - OAuth2/OIDC Providers + Applications for Grafana, Gitea, Nextcloud, Outline,
     Open WebUI, and Portainer (with per-application group policy bindings)
   - client credentials written to `./.secrets/<slug>.env` (gitignored)

## Onboarding a new service

1. Add one line to the `SERVICES` heredoc in `scripts/authentik-setup.sh`:
   `Name|slug|https://svc.${BASE_DOMAIN}/<oidc-callback-path>|group-or-empty`.
2. Re-run `./scripts/authentik-setup.sh` (idempotent; only creates what is missing).
3. Copy the generated `.secrets/<slug>.env` pair into the service's `.env`.
4. If the service has **no native OIDC**, instead add the Traefik label
   `traefik.http.routers.<svc>.middlewares: authentik@file` and, in the Authentik UI,
   create a **Proxy Provider** (or reuse the embedded outpost application) so the
   ForwardAuth endpoint knows the app.
5. Group rules: `homelab-admins` → all admin UIs; `homelab-users` → general apps;
   `media-users` → Jellyfin/Jellyseerr only (enforced by the per-application policy
   bindings created in step 2).

## Per-service configuration blocks

Replace `auth.example.com` / `example.com` with your `AUTHENTIK_DOMAIN` / `BASE_DOMAIN`.

### Grafana — `config/grafana/grafana.ini`

See `config/grafana/grafana.ini` in this repo — the `[auth.generic_oauth]` section maps
Authentik groups to Grafana roles via `role_attribute_path`.

### Gitea — register once via CLI (idempotent; uses UPDATE if the source exists)

```bash
docker exec -u git gitea gitea admin auth add-oauth \
  --name authentik --provider openidConnect \
  --key "${GITEA_CLIENT_ID}" --secret "${GITEA_CLIENT_SECRET}" \
  --auto-discover-url "https://auth.example.com/application/o/gitea/.well-known/openid-configuration"
```

`.env` values:

```bash
GITEA_CLIENT_ID=__from_.secrets/gitea.env__
GITEA_CLIENT_SECRET=__from_.secrets/gitea.env__
```

### Nextcloud — `scripts/nextcloud-oidc-setup.sh`

Configures the Social Login app via `occ` (idempotent). Export `NEXTCLOUD_CLIENT_ID`,
`NEXTCLOUD_CLIENT_SECRET`, `AUTHENTIK_DOMAIN`, `BASE_DOMAIN` and run the script.

### Outline — `.env` block

```bash
OIDC_CLIENT_ID=__from_.secrets/outline.env__
OIDC_CLIENT_SECRET=__from_.secrets/outline.env__
OIDC_AUTH_URI=https://auth.example.com/application/o/authorize/
OIDC_TOKEN_URI=https://auth.example.com/application/o/token/
OIDC_USERINFO_URI=https://auth.example.com/application/o/userinfo/
OIDC_LOGOUT_URI=https://auth.example.com/application/o/outline/end-session/
OIDC_USERNAME_CLAIM=preferred_username
OIDC_DISPLAY_NAME=Authentik
OIDC_SCOPES=openid profile email
```

### Open WebUI — `.env` block

```bash
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
OAUTH_PROVIDER_NAME=Authentik
OPENID_CLIENT_ID=__from_.secrets/openwebui.env__
OPENID_CLIENT_SECRET=__from_.secrets/openwebui.env__
OPENID_PROVIDER_URL=https://auth.example.com/application/o/openwebui/.well-known/openid-configuration
OAUTH_SCOPES=openid profile email
OAUTH_ADMIN_ROLES=homelab-admins     # v0.5+: role mapping by claim
OAUTH_ROLES_CLAIM=groups
```

### Portainer — non-interactive bootstrap via API

```bash
curl -k -X PUT "https://portainer.${BASE_DOMAIN}/api/auth/oauth/settings" \
  -H "Authorization: Bearer ${PORTAINER_ADMIN_JWT}" -H "Content-Type: application/json" -d '{
  "ClientID": "'"${PORTAINER_CLIENT_ID}"'",
  "ClientSecret": "'"${PORTAINER_CLIENT_SECRET}"'",
  "AuthorizationURI": "https://auth.example.com/application/o/authorize/",
  "AccessTokenURI": "https://auth.example.com/application/o/token/",
  "ResourceURI": "https://auth.example.com/application/o/userinfo/",
  "RedirectURI": "https://portainer.'"${BASE_DOMAIN}"'/",
  "UserIdentifier": "preferred_username", "Scopes": "openid profile email",
  "SSO": true, "LogoutURI": "https://auth.example.com/application/o/portainer/end-session/"
}'
```

`.env` values:

```bash
PORTAINER_CLIENT_ID=__from_.secrets/portainer.env__
PORTAINER_CLIENT_SECRET=__from_.secrets/portainer.env__
```

## Traefik ForwardAuth (non-OIDC services)

`config/traefik/dynamic/middlewares.yml` defines the `authentik@file` middleware
pointing at the embedded outpost:

```yaml
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
          - X-authentik-name
          - X-authentik-uid
```

Usage on any router:

```yaml
traefik.http.routers.whoami.middlewares: authentik@file
```
