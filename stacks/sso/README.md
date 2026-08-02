# SSO Stack (Authentik)

The identity provider layer for the Homelab. This stack manages users, groups, and Single Sign-On (SSO) through OIDC and OAuth2 for all deployed services.

## Included Services

- **Authentik Server**: The core OIDC/SAML provider and UI.
- **Authentik Worker**: Handles background tasks, token cleanup, and syncing.
- **PostgreSQL**: Dedicated Postgres instance isolated strictly for Authentik's sensitive identity data.
- **Redis**: Dedicated Redis cache instance.

## Setup & Configuration

1. Copy `.env.example` to `.env` and assign strong credentials.
   - Run `openssl rand -base64 36` to generate the `AUTHENTIK_SECRET_KEY`.
2. Start the stack:
   ```bash
   docker compose up -d
   ```
3. Wait at least 30 seconds for the initial database migrations to run. Log into `https://auth.yourdomain.com` with the bootstrap credentials you defined in `.env`.

## Integrating Services

### Automated Setup
We have provided an API script to automatically configure all required Providers and Applications in Authentik:
1. In the Authentik UI, go to **Admin Interface -> Directory -> Tokens** and generate an API token for the `akadmin` user.
2. Run the provisioning script:
   ```bash
   ./scripts/authentik-setup.sh "YOUR_API_TOKEN"
   ```
3. The script will output the specific `Client ID` and `Client Secret` you need to inject into the `.env` files of other stacks (e.g. `stacks/productivity/.env`, `stacks/observability/.env`).

### Nextcloud Specifics
Run the helper script on the host to configure the OCC app dynamically:
```bash
./scripts/nextcloud-oidc-setup.sh "client_id" "client_secret" "https://auth.yourdomain.com/application/o/nextcloud/.well-known/openid-configuration"
```

## Traefik ForwardAuth

For applications that lack native OIDC/OAuth2 support, they can be protected at the reverse proxy level.
Simply add the `authentik` middleware to the container's labels:
```yaml
labels:
  - "traefik.http.routers.yourapp.middlewares=authentik@file"
```

## User Groups

Create these groups in Authentik to map privileges natively:
- `homelab-admins`: Grants administrative rights in Grafana, Gitea, etc.
- `homelab-users`: Standard access.
- `media-users`: Segmented access for media applications.
