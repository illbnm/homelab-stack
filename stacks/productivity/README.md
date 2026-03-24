# 📋 Productivity Stack

> Self-hosted developer tools and knowledge management — Git, passwords, docs, PDFs, utilities.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Gitea** | `https://git.${DOMAIN}` | Lightweight Git hosting (GitHub alternative) |
| **Vaultwarden** | `https://vault.${DOMAIN}` | Password manager (Bitwarden compatible) |
| **Outline** | `https://docs.${DOMAIN}` | Team wiki / knowledge base |
| **BookStack** | `https://wiki.${DOMAIN}` | Documentation wiki (hierarchical) |
| **Stirling-PDF** | `https://pdf.${DOMAIN}` | PDF manipulation toolkit |
| **IT-Tools** | `https://tools.${DOMAIN}` | Developer utility collection |

## Quick Start

```bash
# 1. Copy and fill environment
cp stacks/productivity/.env.example .env
# Edit .env — set all REQUIRED variables

# 2. Ensure databases stack is running
docker compose -f stacks/databases/docker-compose.yml up -d

# 3. Start productivity stack
docker compose -f stacks/productivity/docker-compose.yml up -d
```

## Environment Variables

See [`.env.example`](.env.example) for all configurable options.

| Variable | Required | Description |
|----------|----------|-------------|
| `GITEA_DB_PASSWORD` | ✅ | PostgreSQL password for Gitea |
| `GITEA_OAUTH2_JWT_SECRET` | ✅ | 32-byte hex secret |
| `VAULTWARDEN_ADMIN_TOKEN` | ✅ | Admin panel access token |
| `VAULTWARDEN_DB_PASSWORD` | ✅ | PostgreSQL password |
| `OUTLINE_SECRET_KEY` | ✅ | 32-byte hex secret |
| `OUTLINE_UTILS_SECRET` | ✅ | 32-byte hex secret |
| `OUTLINE_DB_PASSWORD` | ✅ | PostgreSQL password |
| `BOOKSTACK_APP_KEY` | ✅ | Laravel app key |
| `BOOKSTACK_DB_PASSWORD` | ✅ | MariaDB password |
| `DOMAIN` | ✅ | Base domain (from root .env) |

### Generate Secrets

```bash
# Gitea JWT secret
openssl rand -hex 32

# Vaultwarden admin token
openssl rand -base64 48

# Outline secrets
openssl rand -hex 32  # SECRET_KEY
openssl rand -hex 32  # UTILS_SECRET

# BookStack app key (requires PHP)
php -r "echo 'base64:'.base64_encode(random_bytes(32));"
```

## Service Details

### Gitea

Lightweight Git platform with issues, PRs, packages, and CI/CD (Gitea Actions).

- **Database**: PostgreSQL (`gitea` database)
- **SSO**: Supports OAuth2 via Authentik (`GITEA_OAUTH_CLIENT_ID/SECRET`)
- **Storage**: `gitea-data` volume

### Vaultwarden

Bitwarden-compatible password manager with self-hosting.

- **Database**: PostgreSQL (`vaultwarden` database)
- **Admin Panel**: `https://vault.${DOMAIN}/admin` (uses `VAULTWARDEN_ADMIN_TOKEN`)
- **Signups**: Disabled by default (`SIGNUPS_ALLOWED=false`)

### Outline

Fast, collaborative wiki with real-time editing.

- **Database**: PostgreSQL + Redis
- **SSO**: OIDC via Authentik (required — no local auth)
- **Storage**: `outline-data` volume for file uploads

### BookStack

Hierarchical wiki: Shelves → Books → Chapters → Pages.

- **Database**: MariaDB (`bookstack` database)
- **SSO**: OIDC or SAML2 via Authentik
- **Auth**: Supports local, OIDC, SAML2 (`BOOKSTACK_AUTH_METHOD`)

### Stirling-PDF

All-in-one PDF toolkit: merge, split, convert, OCR, sign.

- **No database** — stateless
- **Storage**: OCR training data volume
- **URL**: `https://pdf.${DOMAIN}`

### IT-Tools

Collection of 100+ developer utilities (UUID, hash, base64, etc.).

- **No database** — stateless, zero config
- **URL**: `https://tools.${DOMAIN}`

## Database Requirements

These services require the databases stack running with initialized users:

| Service | Database | Engine | User |
|---------|----------|--------|------|
| Gitea | `gitea` | PostgreSQL | `gitea` |
| Vaultwarden | `vaultwarden` | PostgreSQL | `vaultwarden` |
| Outline | `outline` | PostgreSQL | `outline` |
| BookStack | `bookstack` | MariaDB | `bookstack` |

Run `stacks/databases/` first or use `./scripts/stack-manager.sh start databases`.

## SSO Integration (Authentik)

Gitea, Outline, and BookStack support OIDC login via Authentik:

```bash
# Auto-configure OIDC providers (if setup-authentik.sh exists)
./scripts/setup-authentik.sh --productivity
```

Or manually create OIDC applications in Authentik and fill in the `_OAUTH_CLIENT_*` / `_OIDC_CLIENT_*` env vars.

## Health Checks

```bash
# Check all productivity services
docker ps --filter "label=com.docker.compose.project=productivity" --format "table {{.Names}}\t{{.Status}}"
```
