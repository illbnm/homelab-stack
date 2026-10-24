# SSO Stack - Authentik Unified Identity Provider

> **Bounty:** illbnm/homelab-stack#9 - $300 USD

## Setup

```bash
cp .env.example .env
docker compose up -d
```

## Environment Variables

- `AUTHENTIK_DB_PASSWORD` - PostgreSQL password (required)
- `AUTHENTIK_SECRET_KEY` - Random 50+ char secret (required)

Generate key: `openssl rand -hex 32`

## Access
- Admin: http://localhost:9000/if/admin/
- User: http://localhost:9000/
