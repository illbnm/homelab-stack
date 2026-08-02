# Productivity Stack

This stack provides collaboration and productivity tools, integrated securely behind Traefik and centralized databases.

## Included Services

- **Gitea**: Git repository hosting.
- **Vaultwarden**: Bitwarden-compatible password manager.
- **Outline**: Team wiki and knowledge base.
- **Stirling PDF**: Comprehensive PDF manipulation tool.
- **Excalidraw**: Virtual whiteboard for sketching diagrams.

## Prerequisites

- **Shared Databases Stack**: Ensure the `databases` stack is running and initialized (`postgres`, `redis`).
- **Storage Stack** (Optional but recommended): Outline relies on an S3-compatible backend (like MinIO) for document attachments and avatars.

## Setup & Configuration

1. Copy `.env.example` to `.env` and configure all required secrets.
   - Use the same database passwords defined in `stacks/databases/.env`.
2. Start the stack:
   ```bash
   docker compose up -d
   ```

### Gitea

Gitea is configured to **disable public registration**. An admin account must be created via the CLI or you must integrate it with Authentik for OIDC SSO.

**To create the first admin user:**
```bash
docker exec -it gitea su git -c "gitea admin user create --username admin --password yourpassword --email admin@example.com --admin"
```

### Vaultwarden

Vaultwarden strictly requires HTTPS to function correctly (most browsers reject WebCrypto APIs over HTTP). Traefik automatically provisions TLS for it. 
- **Registration** is disabled by default.
- Access the admin panel at `https://vault.yourdomain.com/admin` using the `VAULTWARDEN_ADMIN_TOKEN`.
- Use the admin panel to invite users via email (requires SMTP configuration).

### Outline

Outline strictly requires both PostgreSQL and Redis, as well as an OIDC provider (like Authentik) and S3 storage.
- The default config sets `OIDC_DISPLAY_NAME=Authentik`.
- Make sure to create the `outline` bucket in MinIO before uploading files.
