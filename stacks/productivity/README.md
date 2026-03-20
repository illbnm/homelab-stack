# Productivity Stack

A comprehensive productivity stack featuring Gitea (Git hosting), Vaultwarden (password manager), Outline (team wiki), and BookStack (documentation platform) with Authentik OIDC authentication.

## Services Included

- **Gitea**: Self-hosted Git service with web interface
- **Vaultwarden**: Bitwarden-compatible password manager
- **Outline**: Modern team knowledge base and wiki
- **BookStack**: Self-hosted wiki and documentation platform
- **Authentik**: Identity provider with OIDC/SAML support

## Prerequisites

- Docker and Docker Compose installed
- Domain name with SSL certificates
- **HTTPS is required** - Vaultwarden and OIDC authentication will not work over HTTP

## Setup Instructions

### 1. Clone and Configure

```bash
git clone <repository-url>
cd homelab-stacks/stacks/productivity
cp .env.example .env
```

### 2. Environment Configuration

Edit `.env` file with your configuration:

```bash
# Domain Configuration
DOMAIN=yourdomain.com
GITEA_SUBDOMAIN=git
VAULTWARDEN_SUBDOMAIN=vault
OUTLINE_SUBDOMAIN=wiki
BOOKSTACK_SUBDOMAIN=docs
AUTHENTIK_SUBDOMAIN=auth

# Database Passwords (generate secure passwords)
GITEA_DB_PASSWORD=your_secure_password
OUTLINE_DB_PASSWORD=your_secure_password
BOOKSTACK_DB_PASSWORD=your_secure_password
AUTHENTIK_DB_PASSWORD=your_secure_password

# Authentik Configuration
AUTHENTIK_SECRET_KEY=your_50_character_secret_key
AUTHENTIK_BOOTSTRAP_PASSWORD=admin_password
AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com

# Vaultwarden Configuration
VAULTWARDEN_ADMIN_TOKEN=your_admin_token

# Outline Configuration
OUTLINE_SECRET_KEY=your_32_character_secret
OUTLINE_UTILS_SECRET=your_32_character_utils_secret
```

### 3. SSL Certificate Setup

Ensure you have valid SSL certificates for all subdomains. You can use:
- Let's Encrypt with Certbot
- Cloudflare certificates
- Other SSL providers

**Important**: HTTPS is mandatory for Vaultwarden and OIDC authentication to function properly.

### 4. Deploy the Stack

```bash
docker-compose up -d
```

### 5. Initial Setup

#### Authentik Configuration

1. Access Authentik at `https://auth.yourdomain.com`
2. Login with bootstrap credentials
3. Navigate to Applications → Providers
4. Create OIDC providers for each service:

**Gitea OIDC Provider:**
- Name: `gitea`
- Authorization flow: `implicit-consent`
- Redirect URIs: `https://git.yourdomain.com/user/oauth2/authentik/callback`
- Scopes: `openid email profile`

**Outline OIDC Provider:**
- Name: `outline`
- Authorization flow: `implicit-consent`  
- Redirect URIs: `https://wiki.yourdomain.com/auth/oidc.callback`
- Scopes: `openid email profile`

**BookStack OIDC Provider:**
- Name: `bookstack`
- Authorization flow: `implicit-consent`
- Redirect URIs: `https://docs.yourdomain.com/oidc/callback`
- Scopes: `openid email profile`

5. Create applications for each provider and note the Client IDs and Client Secrets

#### Service Configuration

**Gitea:**
1. Access admin panel at `https://git.yourdomain.com`
2. Go to Site Administration → Authentication Sources
3. Add OAuth2 source with Authentik details

**Outline:**
1. Update environment variables with Authentik OIDC details
2. Restart container: `docker-compose restart outline`

**BookStack:**
1. Access admin settings at `https://docs.yourdomain.com`
2. Configure OIDC authentication with Authentik details

**Vaultwarden:**
1. Access admin panel at `https://vault.yourdomain.com/admin`
2. Configure organization and user settings as needed

## Service Access URLs

- **Gitea**: `https://git.yourdomain.com`
- **Vaultwarden**: `https://vault.yourdomain.com`
- **Outline**: `https://wiki.yourdomain.com`
- **BookStack**: `https://docs.yourdomain.com`
- **Authentik**: `https://auth.yourdomain.com`

## Security Considerations

1. **HTTPS Only**: All services must be accessed via HTTPS
2. **Strong Passwords**: Use complex passwords for all database and admin accounts
3. **Regular Backups**: Implement backup strategy for databases and data volumes
4. **Updates**: Keep all containers updated regularly
5. **Firewall**: Ensure only necessary ports are exposed

## Backup

Important directories to backup:
- `./data/gitea/`
- `./data/vaultwarden/`
- `./data/outline/uploads/`
- `./data/bookstack/uploads/`
- Database volumes

## Troubleshooting

### Common Issues

1. **OIDC Authentication Fails**: Verify HTTPS is properly configured and redirect URIs match exactly
2. **Vaultwarden Admin Panel Inaccessible**: Check ADMIN_TOKEN is set and HTTPS is working
3. **Database Connection Errors**: Verify database passwords match in environment file
4. **Outline File Uploads Fail**: Check file permissions on uploads directory

### Logs

Check service logs:
```bash
docker-compose logs [service-name]
```

## Support

For issues specific to this stack configuration, please check the logs and ensure all prerequisites are met, especially HTTPS configuration.