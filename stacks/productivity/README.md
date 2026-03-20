# Productivity Stack

The Productivity Stack provides essential tools for software development, password management, documentation, and creative work. All services are integrated with SSO authentication and configured for secure production use.

## Services Overview

### Core Services

- **Gitea** - Lightweight Git service with web interface
- **Vaultwarden** - Bitwarden-compatible password manager
- **Outline** - Team knowledge base and wiki
- **Stirling PDF** - PDF manipulation and processing tools
- **Excalidraw** - Collaborative whiteboarding and diagramming

### Supporting Infrastructure

- **PostgreSQL** - Shared database for Gitea and Outline
- **Redis** - Caching and session storage for Outline
- **Traefik** - Reverse proxy with automatic HTTPS

## Quick Start

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure domains and secrets:**
   ```bash
   # Edit .env with your domain names
   DOMAIN=yourdomain.com

   # Generate secure secrets
   openssl rand -hex 32  # For POSTGRES_PASSWORD
   openssl rand -hex 32  # For REDIS_PASSWORD
   openssl rand -hex 32  # For OUTLINE_SECRET_KEY
   ```

3. **Deploy the stack:**
   ```bash
   docker-compose up -d
   ```

4. **Access services:**
   - Gitea: `https://git.yourdomain.com`
   - Vaultwarden: `https://vault.yourdomain.com`
   - Outline: `https://docs.yourdomain.com`
   - Stirling PDF: `https://pdf.yourdomain.com`
   - Excalidraw: `https://draw.yourdomain.com`

## Configuration Details

### OIDC Integration

All services support OIDC authentication through Authentik (from SSO stack):

#### Gitea OIDC Setup
1. Access Gitea admin panel: Site Administration → Authentication Sources
2. Add new OAuth2 source:
   - Provider: OpenID Connect
   - Client ID: `gitea`
   - Client Secret: (from Authentik application)
   - Auto Discovery URL: `https://sso.yourdomain.com/application/o/gitea/.well-known/openid_configuration`

#### Outline OIDC Configuration
Environment variables automatically configure OIDC:
```env
OIDC_CLIENT_ID=outline
OIDC_CLIENT_SECRET=your-secret
OIDC_AUTH_URI=https://sso.yourdomain.com/application/o/authorize/
OIDC_TOKEN_URI=https://sso.yourdomain.com/application/o/token/
OIDC_USERINFO_URI=https://sso.yourdomain.com/application/o/userinfo/
```

### Database Configuration

PostgreSQL is shared between Gitea and Outline with separate databases:

```yaml
databases:
  - gitea_db (for Gitea)
  - outline_db (for Outline)
```

Connection details are automatically configured through environment variables.

### Storage Persistence

All critical data is persisted in named volumes:

- `gitea_data`: Git repositories and Gitea configuration
- `vaultwarden_data`: Password vault database and attachments
- `outline_data`: Document storage and uploads
- `postgres_data`: Database files
- `redis_data`: Cache and session data

## Security Considerations

### HTTPS Configuration

All services are configured with:
- Automatic HTTPS via Let's Encrypt
- HTTP to HTTPS redirects
- Secure headers via Traefik middleware

### Network Security

- Services communicate on isolated `productivity_network`
- Database and Redis are not exposed externally
- All external access goes through Traefik reverse proxy

### Secret Management

Critical secrets to configure:
```env
POSTGRES_PASSWORD=        # Strong database password
REDIS_PASSWORD=          # Redis authentication
OUTLINE_SECRET_KEY=      # Outline encryption key
OIDC_CLIENT_SECRET=      # OIDC application secret
```

### Vaultwarden Security

Additional security features enabled:
- Admin panel disabled in production
- Email verification required for new accounts
- HTTPS enforcement for all operations
- Secure password policy enforcement

## Usage Examples

### Setting Up Git Repositories

1. **Create new repository in Gitea:**
   ```bash
   # Via web interface or API
   curl -X POST https://git.yourdomain.com/api/v1/user/repos \
     -H "Authorization: token YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name": "my-project", "private": true}'
   ```

2. **Clone and push:**
   ```bash
   git clone https://git.yourdomain.com/username/my-project.git
   cd my-project
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

### Managing Passwords with Vaultwarden

1. **Install Bitwarden client:**
   ```bash
   # Desktop app or browser extension
   # Configure server URL: https://vault.yourdomain.com
   ```

2. **API access:**
   ```bash
   # Using Bitwarden CLI
   bw config server https://vault.yourdomain.com
   bw login
   bw sync
   ```

### Creating Documentation in Outline

1. **Access team workspace:** `https://docs.yourdomain.com`
2. **Create collections** for different projects or teams
3. **Use markdown syntax** for rich document formatting
4. **Share documents** with team members via links

### Processing PDFs with Stirling

Common operations available at `https://pdf.yourdomain.com`:
- Merge multiple PDFs
- Split PDF into pages
- Convert between formats
- Add/remove passwords
- OCR text recognition

### Collaborative Drawing with Excalidraw

1. **Create diagrams:** Access `https://draw.yourdomain.com`
2. **Real-time collaboration:** Share room links with team
3. **Export formats:** PNG, SVG, or JSON for version control
4. **Libraries:** Save common shapes and templates

## Monitoring and Maintenance

### Health Checks

All services include health check endpoints:
```bash
# Check service status
docker-compose ps
curl -f https://git.yourdomain.com/api/healthz
curl -f https://vault.yourdomain.com/alive
```

### Backup Procedures

Critical data to backup regularly:
```bash
# Database backup
docker-compose exec postgres pg_dumpall -U postgres > backup.sql

# Vaultwarden data
docker cp productivity_vaultwarden:/data ./vaultwarden-backup

# Gitea repositories
docker cp productivity_gitea:/data/git ./gitea-backup
```

### Log Management

View service logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f gitea
docker-compose logs -f vaultwarden
```

## Troubleshooting

### Common Issues

**OIDC authentication failures:**
- Verify Authentik application configuration
- Check client ID and secret match
- Confirm redirect URLs are correct

**Database connection errors:**
- Ensure PostgreSQL is fully started before dependent services
- Check network connectivity within Docker
- Verify database credentials

**File upload issues:**
- Check volume mounts are correct
- Verify disk space availability
- Review file size limits in service configs

### Resource Requirements

Minimum system requirements:
- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 50GB available space
- **Network:** 1Gbps recommended

### Performance Tuning

For high-load environments:
```env
# PostgreSQL
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB

# Redis
REDIS_MAXMEMORY=512mb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

## Integration with Other Stacks

### Monitoring Stack
- Prometheus metrics enabled for all services
- Grafana dashboards available
- Log aggregation via Loki

### Backup Stack
- Automated daily backups configured
- Retention policies applied
- Cross-region replication available

### Network Stack
- VPN access for remote development
- Secure internal DNS resolution
- Network policies for isolation
