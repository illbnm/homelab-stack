# SSO Stack — Authentik Identity Provider

Full-featured SSO with OIDC, SAML, LDAP, and social login support.

## Deployment
1. Generate a secret key: `openssl rand -base64 64`
2. Replace `change-me-to-a-random-string` in docker-compose.yml with the generated key.
3. Start the stack: `docker compose up -d`
4. Access at `https://auth.yourdomain.com` (or configure Traefik labels).
