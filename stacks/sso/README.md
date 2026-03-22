# 🔐 SSO Stack

> Unified authentication system based on Authentik with OIDC/SAML support.

## 🎯 Bounty: [#9](../../issues/9) - $300 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **Authentik Server** | `ghcr.io/goauthentik/server:2024.8.3` | 9000 | Identity Provider (OIDC/SAML) |
| **Authentik Worker** | `ghcr.io/goauthentik/server:2024.8.3` | - | Background tasks |
| **PostgreSQL** | `postgres:16-alpine` | 5432 | Authentik database |
| **Redis** | `redis:7-alpine` | 6379 | Cache and queue |

## 🚀 Quick Start

```bash
# 1. Copy environment example
cp .env.example .env

# 2. Generate secure secret keys
openssl rand -base64 64  # For AUTHENTIK_SECRET_KEY
openssl rand -base64 32  # For passwords

# 3. Edit environment variables
nano .env

# 4. Start the stack
cd /home/zhaog/.openclaw/workspace/data/bounty-projects/homelab-stack
docker compose -f stacks/sso/docker-compose.yml up -d

# 5. Wait for initialization (~60 seconds)
docker compose -f stacks/sso/docker-compose.yml logs -f authentik-server

# 6. Run setup script
./scripts/authentik-setup.sh --token YOUR_API_TOKEN
```

## ⚙️ Configuration

### Environment Variables

```bash
# Domain
DOMAIN=example.com
AUTHENTIK_DOMAIN=auth.example.com

# Authentik secret key (generate with: openssl rand -base64 64)
AUTHENTIK_SECRET_KEY=your-secret-key-here

# Bootstrap credentials (first admin login)
AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
AUTHENTIK_BOOTSTRAP_PASSWORD=your-admin-password

# Database passwords
AUTHENTIK_POSTGRES_PASSWORD=your-db-password
AUTHENTIK_REDIS_PASSWORD=your-redis-password
```

### Access URLs

After deployment:

- **Authentik Admin**: `https://auth.${DOMAIN}/if/admin/`
- **Authentik User Interface**: `https://auth.${DOMAIN}/if/flow/default-brand-flow/`

### Default Admin

On first boot, Authentik creates admin user:
- **Username**: `akadmin`
- **Password**: Displayed in logs (`docker logs authentik-server`)

**⚠️ Change the password immediately after first login!**

## 📝 Service Details

### Authentik Server

**Features:**
- OIDC/OAuth2 Provider
- SAML2 Provider
- LDAP Provider
- Proxy Provider (for apps without SSO)
- MFA support (TOTP, WebAuthn)
- User groups and roles
- Custom authentication flows

**Ports:**
- 9000: Web UI + API + Outpost

### Authentik Worker

**Purpose:** Background task processor

**Tasks:**
- Email sending
- Policy evaluation
- Outpost synchronization
- Cleanup jobs

### PostgreSQL

**Configuration:**
- Database: `authentik`
- User: `authentik`
- Port: 5432 (internal only)

### Redis

**Configuration:**
- Password protected
- Persistence enabled (RDB)
- Port: 6379 (internal only)

## 🔧 Integration Guide

### 1. Generate API Token

Before running setup script:

1. Login to `https://auth.${DOMAIN}/if/admin/`
2. Go to **Admin → Users**
3. Click on your user
4. Click **"Create Token"**
5. Select **"Service Token"**
6. Copy the token

### 2. Run Setup Script

```bash
./scripts/authentik-setup.sh --token YOUR_API_TOKEN
```

This will:
- Create OAuth2 Provider for each service
- Create corresponding Applications
- Output Client ID and Client Secret

### 3. Configure Services

Each service needs specific configuration. See individual stack READMEs:

| Stack | Configuration File |
|-------|-------------------|
| **Grafana** | `config/grafana/grafana.ini` |
| **Gitea** | `stacks/productivity/.env` |
| **Nextcloud** | `scripts/nextcloud-oidc-setup.sh` |
| **Outline** | `stacks/productivity/.env` |
| **Open WebUI** | `stacks/ai/.env` |
| **Portainer** | `stacks/base/.env` |

## 🔒 Traefik ForwardAuth

For services that don't support OIDC natively, use Traefik ForwardAuth middleware.

### Configuration

Create `config/traefik/dynamic/middlewares.yml`:

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
```

### Usage in Services

Add labels to your service:

```yaml
labels:
  - traefik.enable=true
  - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"
  - traefik.http.routers.myservice.middlewares=authentik@file
```

## 👥 User Groups

Recommended group structure:

| Group | Access Level |
|-------|-------------|
| `authentik-admins` | Full admin access to all services |
| `homelab-users` | Standard user access |
| `media-users` | Access to Jellyfin, Jellyseerr only |
| `dev-users` | Access to Gitea, Portainer, monitoring |

### Creating Groups

In Admin panel:
1. Go to **Groups**
2. Click **Create**
3. Add users to groups
4. Assign group-based policies to applications

## ✅ Verification Checklist

- [ ] Authentik admin panel accessible
- [ ] Can login with admin credentials
- [ ] PostgreSQL healthy
- [ ] Redis healthy
- [ ] Setup script runs successfully
- [ ] OAuth2 providers created for all services
- [ ] Applications visible in admin panel
- [ ] Traefik ForwardAuth working
- [ ] Test login via one integrated service

## 🐛 Troubleshooting

### Authentik Won't Start

```bash
# Check logs
docker logs authentik-server

# Common issues:
# 1. Invalid secret key (must be base64)
# 2. Database connection failed
# 3. Redis connection failed
```

### Setup Script Fails

```bash
# Verify token is valid
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://auth.${DOMAIN}/api/v3/admin/config/

# Check Authentik is healthy
docker compose -f stacks/sso/docker-compose.yml ps
```

### OIDC Login Fails

1. Verify redirect URI matches exactly
2. Check Client ID and Secret are correct
3. Ensure service can reach Authentik (network connectivity)
4. Check Authentik logs for errors

### ForwardAuth Returns 403

```bash
# Check outpost is running
docker logs authentik-server | grep outpost

# Verify middleware configuration
cat config/traefik/dynamic/middlewares.yml

# Reload Traefik
docker exec traefik traefik healthcheck
```

## 📚 Related Stacks

- [Base Infrastructure](../base/) - Traefik configuration
- [Productivity](../productivity/) - Gitea, Outline integration
- [AI](../ai/) - Open WebUI integration
- [Media](../media/) - Group-based access control

## 🔐 Security Best Practices

1. **Change default admin password** immediately
2. **Enable MFA** for all admin accounts
3. **Use strong secret keys** (64+ characters)
4. **Regular backups** of PostgreSQL database
5. **Monitor failed login attempts**
6. **Rate limit** authentication endpoints
7. **Use HTTPS only** (no HTTP fallback)

## 📖 Resources

- [Authentik Documentation](https://docs.goauthentik.io/)
- [OIDC Specification](https://openid.net/connect/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)

---

*Bounty: $300 USDT | Status: In Progress*
