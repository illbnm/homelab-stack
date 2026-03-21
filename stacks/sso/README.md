# SSO Stack - Authentik Identity Provider

Complete Single Sign-On (SSO) solution using Authentik with automated OIDC provider configuration for all HomeLab services.

## Overview

Authentik provides centralized authentication for:
- **Jellyfin** - Media server
- **Portainer** - Docker management
- **Grafana** - Monitoring dashboards
- **Nextcloud** - File sync & collaboration
- **Vaultwarden** - Password manager
- **Home Assistant** - Home automation
- **GitLab** - Code repository

## Quick Start

```bash
# 1. Setup environment
cd stacks/sso
cp .env.example .env
nano .env  # Configure your domains

# 2. Start Authentik
docker-compose up -d

# 3. Run automated setup
../../scripts/setup-authentik.sh

# 4. Access admin interface
open https://auth.yourdomain.com/if/admin/
```

## Configuration

### Environment Variables

```bash
# Core Settings
AUTHENTIK_SECRET_KEY=your-secret-key-min-32-chars
AUTHENTIK_DOMAIN=auth.yourdomain.com
POSTGRES_PASSWORD=secure-db-password

# Service Domains
JELLYFIN_DOMAIN=jellyfin.yourdomain.com
PORTAINER_DOMAIN=portainer.yourdomain.com
GRAFANA_DOMAIN=grafana.yourdomain.com
NEXTCLOUD_DOMAIN=nextcloud.yourdomain.com
VAULTWARDEN_DOMAIN=vault.yourdomain.com
HOMEASSISTANT_DOMAIN=ha.yourdomain.com
GITLAB_DOMAIN=git.yourdomain.com
```

### Initial Setup

1. **Generate Secret Key**:
   ```bash
   python -c "from secrets import token_urlsafe; print(token_urlsafe(32))"
   ```

2. **Start Services**:
   ```bash
   docker-compose up -d
   ```

3. **Create Admin User**:
   ```bash
   docker-compose exec authentik-server ak create_admin_group
   docker-compose exec authentik-server ak create_admin --username admin --email admin@yourdomain.com
   ```

## OIDC Provider Configuration

### Jellyfin Integration

1. **Create Application**:
   - Name: `Jellyfin`
   - Slug: `jellyfin`
   - Provider: OAuth2/OIDC
   - Redirect URIs: `https://jellyfin.yourdomain.com/sso/OID/redirect/authentik`

2. **Jellyfin Plugin Config**:
   ```json
   {
     "OidcPluginConfiguration": {
       "OidcClientId": "jellyfin-client-id",
       "OidcClientSecret": "client-secret-from-authentik",
       "OidcEndpoint": "https://auth.yourdomain.com/application/o/jellyfin/.well-known/openid_configuration",
       "OidcScopes": "openid profile email"
     }
   }
   ```

### Portainer Integration

1. **OAuth Settings**:
   - Client ID: `portainer-client-id`
   - Client Secret: From Authentik
   - Authorization URL: `https://auth.yourdomain.com/application/o/authorize/`
   - Access Token URL: `https://auth.yourdomain.com/application/o/token/`
   - Resource URL: `https://auth.yourdomain.com/application/o/userinfo/`

2. **Portainer Config**:
   ```bash
   # Via API or UI
   curl -X POST https://portainer.yourdomain.com/api/settings \
     -H "Content-Type: application/json" \
     -d '{
       "AuthenticationMethod": 3,
       "OAuthSettings": {
         "ClientID": "portainer-client-id",
         "ClientSecret": "client-secret",
         "AuthorizationURI": "https://auth.yourdomain.com/application/o/authorize/",
         "AccessTokenURI": "https://auth.yourdomain.com/application/o/token/",
         "ResourceURI": "https://auth.yourdomain.com/application/o/userinfo/",
         "RedirectURI": "https://portainer.yourdomain.com/",
         "Scopes": "openid profile email"
       }
     }'
   ```

### Grafana Integration

1. **Environment Variables** (add to Grafana stack):
   ```yaml
   environment:
     GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
     GF_AUTH_GENERIC_OAUTH_NAME: "Authentik"
     GF_AUTH_GENERIC_OAUTH_CLIENT_ID: "grafana-client-id"
     GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: "client-secret"
     GF_AUTH_GENERIC_OAUTH_SCOPES: "openid profile email"
     GF_AUTH_GENERIC_OAUTH_AUTH_URL: "https://auth.yourdomain.com/application/o/authorize/"
     GF_AUTH_GENERIC_OAUTH_TOKEN_URL: "https://auth.yourdomain.com/application/o/token/"
     GF_AUTH_GENERIC_OAUTH_API_URL: "https://auth.yourdomain.com/application/o/userinfo/"
     GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP: "true"
   ```

### Nextcloud Integration

1. **Install OIDC App**:
   ```bash
   docker-compose exec nextcloud occ app:install oidc_login
   ```

2. **Configuration** (config/config.php):
   ```php
   'oidc_login' => [
     'provider-url' => 'https://auth.yourdomain.com/application/o/nextcloud/',
     'client-id' => 'nextcloud-client-id',
     'client-secret' => 'client-secret',
     'loginButtonName' => 'Authentik',
     'auto-provision' => [
       'enabled' => true,
       'email-claim' => 'email',
       'display-name-claim' => 'name',
       'group-claim' => 'groups'
     ]
   ]
   ```

### Vaultwarden Integration

1. **Environment Variables**:
   ```yaml
   environment:
     SSO_ENABLED: "true"
     SSO_CLIENT_ID: "vaultwarden-client-id"
     SSO_CLIENT_SECRET: "client-secret"
     SSO_AUTHORITY: "https://auth.yourdomain.com/application/o/vaultwarden/"
     SSO_SCOPES: "openid profile email"
   ```

### Home Assistant Integration

1. **Configuration.yaml**:
   ```yaml
   auth_providers:
     - type: homeassistant
     - type: command_line
       command: /config/authentik_auth.py

   http:
     use_x_forwarded_for: true
     trusted_proxies:
       - 172.18.0.0/16  # Docker network
   ```

2. **Auth Script** (/config/authentik_auth.py):
   ```python
   #!/usr/bin/env python3
   import requests
   import sys
   import json

   def authenticate(username, password):
       response = requests.post('https://auth.yourdomain.com/application/o/token/', {
           'grant_type': 'password',
           'username': username,
           'password': password,
           'client_id': 'homeassistant-client-id',
           'client_secret': 'client-secret'
       })
       return response.status_code == 200

   if __name__ == "__main__":
       username = sys.argv[1]
       password = sys.argv[2]
       if authenticate(username, password):
           print("SUCCESS")
       else:
           print("FAILURE")
   ```

### GitLab Integration

1. **Omnibus Config** (/etc/gitlab/gitlab.rb):
   ```ruby
   gitlab_rails['omniauth_enabled'] = true
   gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
   gitlab_rails['omniauth_block_auto_created_users'] = false

   gitlab_rails['omniauth_providers'] = [
     {
       'name' => 'openid_connect',
       'label' => 'Authentik',
       'args' => {
         'name' => 'openid_connect',
         'scope' => ['openid', 'profile', 'email'],
         'response_type' => 'code',
         'issuer' => 'https://auth.yourdomain.com/application/o/gitlab/',
         'client_auth_method' => 'basic',
         'discovery' => true,
         'uid_field' => 'sub',
         'client_options' => {
           'identifier' => 'gitlab-client-id',
           'secret' => 'client-secret',
           'redirect_uri' => 'https://git.yourdomain.com/users/auth/openid_connect/callback'
         }
       }
     }
   ]
   ```

## User Management

### Creating Users

1. **Via Admin Interface**:
   - Navigate to Directory → Users
   - Click "Create User"
   - Set username, email, password
   - Assign to groups

2. **Via API**:
   ```bash
   curl -X POST https://auth.yourdomain.com/api/v3/core/users/ \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "username": "newuser",
       "email": "user@example.com",
       "name": "New User",
       "is_active": true
     }'
   ```

### Group Management

1. **Default Groups**:
   - `authentik Admins` - Full system access
   - `Media Users` - Jellyfin access
   - `Homelab Users` - Standard services
   - `Power Users` - Portainer + monitoring

2. **Group Assignment**:
   ```bash
   # Add user to group
   curl -X POST https://auth.yourdomain.com/api/v3/core/groups/$GROUP_ID/add_user/ \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -d '{"pk": "$USER_ID"}'
   ```

## Security Configuration

### Password Policies

```yaml
# Default policy
minimum_length: 12
require_uppercase: true
require_lowercase: true
require_numeric: true
require_symbols: true
check_common_passwords: true
check_breached_passwords: true
```

### MFA Setup

1. **TOTP (Recommended)**:
   - Auto-enroll for admin users
   - Optional for regular users
   - Backup codes generated

2. **WebAuthn**:
   - Hardware security keys
   - Biometric authentication
   - Platform authenticators

### Rate Limiting

```yaml
reputation_policy:
  check_ip: true
  check_username: true
  threshold: 5
  decrease_after_minutes: 60
```

## Backup & Recovery

### Database Backup

```bash
# Automated backup script
#!/bin/bash
BACKUP_DIR="/opt/backups/authentik"
DATE=$(date +%Y%m%d_%H%M%S)

docker-compose exec postgres pg_dump -U authentik authentik > \
  "$BACKUP_DIR/authentik_$DATE.sql"

# Retain last 7 days
find "$BACKUP_DIR" -name "authentik_*.sql" -mtime +7 -delete
```

### Configuration Export

```bash
# Export applications and providers
docker-compose exec authentik-server ak export \
  --output /authentik-export/config.json
```

### Disaster Recovery

1. **Fresh Installation**:
   ```bash
   cd stacks/sso
   docker-compose down -v  # Remove all data
   docker-compose up -d
   ```

2. **Restore Database**:
   ```bash
   docker-compose exec postgres psql -U authentik authentik < backup.sql
   ```

3. **Import Configuration**:
   ```bash
   docker-compose exec authentik-server ak import config.json
   ```

## Monitoring & Logs

### Prometheus Metrics

Authentik exposes metrics at: `https://auth.yourdomain.com/metrics`

Key metrics:
- `authentik_admin_messages_total`
- `authentik_flows_total`
- `authentik_policies_total`
- `authentik_events_total`

### Log Configuration

```yaml
# docker-compose.yml
environment:
  AUTHENTIK_LOG_LEVEL: info
  AUTHENTIK_LOG_JSON: true
```

### Common Log Locations

```bash
# Application logs
docker-compose logs authentik-server

# Worker logs
docker-compose logs authentik-worker

# PostgreSQL logs
docker-compose logs postgres

# Redis logs
docker-compose logs redis
```

## Troubleshooting

### Common Issues

1. **SSL/TLS Errors**:
   ```bash
   # Check certificate
   openssl s_client -connect auth.yourdomain.com:443 -servername auth.yourdomain.com
   ```

2. **Database Connection**:
   ```bash
   # Test connection
   docker-compose exec authentik-server ak test_db
   ```

3. **OIDC Discovery Failures**:
   ```bash
   # Verify endpoints
   curl https://auth.yourdomain.com/.well-known/openid_configuration
   ```

### Debug Mode

```yaml
# Temporary debugging
environment:
  AUTHENTIK_LOG_LEVEL: debug
  AUTHENTIK_DEBUG: true
```

### Reset Admin Password

```bash
docker-compose exec authentik-server ak reset_password admin
```

## Performance Tuning

### Redis Configuration

```yaml
redis:
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

### Worker Scaling

```yaml
authentik-worker:
  scale: 2  # Increase for high load
```

### Database Optimization

```yaml
postgres:
  environment:
    POSTGRES_SHARED_PRELOAD_LIBRARIES: pg_stat_statements
    POSTGRES_MAX_CONNECTIONS: 200
```

## API Usage

### Authentication

```bash
# Get admin token
TOKEN=$(curl -X POST https://auth.yourdomain.com/api/v3/core/tokens/ \
  -u "admin:password" | jq -r '.key')
```

### Common API Calls

```bash
# List users
curl -H "Authorization: Bearer $TOKEN" \
  https://auth.yourdomain.com/api/v3/core/users/

# List applications
curl -H "Authorization: Bearer $TOKEN" \
  https://auth.yourdomain.com/api/v3/core/applications/

# Get user info
curl -H "Authorization: Bearer $TOKEN" \
  https://auth.yourdomain.com/api/v3/core/users/me/
```

## Integration Testing

Run the complete test suite:

```bash
../../tests/sso-integration.test.sh
```

Tests include:
- Service health checks
- OIDC discovery validation
- Authentication flow testing
- API endpoint verification
- SSL certificate validation

For detailed testing documentation, see `tests/sso-integration.test.sh`.
