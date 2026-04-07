# Authentik SSO Integration — Verification Checklist

> Complete verification checklist for Bounty Task #9: [BOUNTY $300] SSO — Authentik 统一身份认证

## 🎯 Bounty Requirements Checklist

### Core Infrastructure (MUST HAVE)

- [ ] **Authentik Web UI accessible at `https://auth.DOMAIN`**
  - [ ] DNS configured and pointing to server
  - [ ] Traefik proxy running and configured
  - [ ] Authentik containers healthy
  - [ ] HTTPS certificate valid (Let's Encrypt or self-signed)
  - [ ] Admin login works with bootstrap credentials

**Verification Commands:**
```bash
# Check containers
docker compose -f stacks/sso/docker-compose.yml ps

# Check health
curl -k https://auth.DOMAIN/-/health/ready/

# Access UI
curl -k https://auth.DOMAIN/if/admin/
```

**Screenshot Required:**
- [ ] Authentik admin login page
- [ ] Successful admin dashboard access

---

### Automated Setup Script (MUST HAVE)

- [ ] **`setup-authentik.sh` creates all providers automatically**
  - [ ] Script executes without errors
  - [ ] Creates OIDC providers for: Grafana, Gitea, Outline, Portainer, Nextcloud
  - [ ] Outputs Client ID and Client Secret for each service
  - [ ] Updates `.env` file with credentials
  - [ ] Creates corresponding Applications in Authentik

**Verification Commands:**
```bash
# Run setup script
./scripts/setup-authentik-enhanced.sh

# Verify providers created
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  https://auth.DOMAIN/api/v3/providers/oauth2/ | jq '.results | length'

# Check .env updated
grep OAUTH .env
```

**Output Required:**
- [ ] Full script execution log showing all providers created
- [ ] `.env` file with populated OAuth credentials

---

### OIDC Integration — Grafana (MUST HAVE)

- [ ] **Grafana login via Authentik works**
  - [ ] Grafana service running
  - [ ] OAuth environment variables configured
  - [ ] "Sign in with Authentik" button visible
  - [ ] Login redirects to Authentik
  - [ ] Successful redirect back to Grafana
  - [ ] User logged in with correct identity

**Configuration:**
```yaml
# stacks/monitoring/.env or grafana.ini
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.DOMAIN/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.DOMAIN/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.DOMAIN/application/o/userinfo/
```

**Screenshot Required:**
- [ ] Grafana login page with OAuth button
- [ ] Authentik authorization page
- [ ] Successful Grafana dashboard after login
- [ ] User profile showing Authentik identity

**Config File Required:**
- [ ] `grafana.ini` or environment variables showing OAuth config

---

### OIDC Integration — Gitea (MUST HAVE)

- [ ] **Gitea login via Authentik works**
  - [ ] Gitea service running
  - [ ] OAuth configured in Gitea settings
  - [ ] Login redirects to Authentik
  - [ ] Successful redirect back to Gitea
  - [ ] User logged in with correct identity

**Configuration:**
```yaml
# stacks/productivity/.env
GITEA__oauth2__ENABLE=true
GITEA__oauth2__OPENID__CLIENT_ID=${GITEA_OAUTH_CLIENT_ID}
GITEA__oauth2__OPENID__CLIENT_SECRET=${GITEA_OAUTH_CLIENT_SECRET}
GITEA__oauth2__OPENID__AUTH_URL=https://auth.DOMAIN/login/oauth/authorize
GITEA__oauth2__OPENID__TOKEN_URL=https://auth.DOMAIN/login/oauth/access_token
```

**Screenshot Required:**
- [ ] Gitea login page with OAuth option
- [ ] Authentik authorization page
- [ ] Successful Gitea dashboard after login

**Config File Required:**
- [ ] Gitea app.ini or environment variables showing OAuth config

---

### OIDC Integration — Outline (MUST HAVE)

- [ ] **Outline login via Authentik works**
  - [ ] Outline service running
  - [ ] OIDC environment variables configured
  - [ ] "Continue with Authentik" option visible
  - [ ] Login redirects to Authentik
  - [ ] Successful redirect back to Outline
  - [ ] User logged in with correct identity

**Configuration:**
```yaml
# stacks/productivity/.env
OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://auth.DOMAIN/application/o/authorize/
OIDC_TOKEN_URI=https://auth.DOMAIN/application/o/token/
OIDC_USERINFO_URI=https://auth.DOMAIN/application/o/userinfo/
```

**Screenshot Required:**
- [ ] Outline login page with OIDC option
- [ ] Authentik authorization page
- [ ] Successful Outline dashboard after login

**Config File Required:**
- [ ] Outline docker-compose.yml or .env showing OIDC config

---

### OIDC Integration — Nextcloud (MUST HAVE)

- [ ] **Nextcloud login via Authentik works**
  - [ ] Nextcloud service running
  - [ ] Social Login app installed
  - [ ] OAuth provider configured in Nextcloud
  - [ ] Login redirects to Authentik
  - [ ] Successful redirect back to Nextcloud
  - [ ] User logged in with correct identity

**Configuration Steps:**
1. Install Social Login app in Nextcloud
2. Configure OAuth2 provider in Nextcloud admin
3. Set redirect URI: `https://nextcloud.DOMAIN/apps/sociallogin/custom_oidc/Authentik`

**Screenshot Required:**
- [ ] Nextcloud login page with OAuth option
- [ ] Social Login app configuration in Nextcloud
- [ ] Authentik authorization page
- [ ] Successful Nextcloud dashboard after login

**Config File Required:**
- [ ] Nextcloud config.php or Social Login app settings

---

### ForwardAuth Middleware (MUST HAVE)

- [ ] **ForwardAuth protects at least one service without native OIDC**
  - [ ] Traefik middleware configured (`authentik@file`)
  - [ ] Service configured with middleware
  - [ ] Unauthenticated access redirects to Authentik
  - [ ] Successful authentication grants access

**Configuration:**
```yaml
# In service's docker-compose.yml labels
labels:
  - "traefik.http.routers.<service>.middlewares=authentik@file"
```

**Verification Commands:**
```bash
# Access protected service without auth (should redirect)
curl -I https://service.DOMAIN

# Check middleware configuration
cat config/traefik/dynamic/authentik.yml

# Check Traefik logs
docker logs traefik | grep authentik
```

**Screenshot Required:**
- [ ] Protected service showing redirect to Authentik
- [ ] Successful access after authentication

**Config File Required:**
- [ ] Service docker-compose.yml with middleware label
- [ ] Traefik authentik.yml middleware file

---

### User Group Permissions (MUST HAVE)

- [ ] **Groups isolate permissions correctly**
  - [ ] `homelab-admins` group created
  - [ ] `homelab-users` group created
  - [ ] `media-users` group created
  - [ ] Group membership controls service access
  - [ ] media-users cannot access Grafana admin
  - [ ] homelab-admins have admin access to all services

**Verification Commands:**
```bash
# List groups in Authentik
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  https://auth.DOMAIN/api/v3/core/groups/ | jq '.results[].name'

# Test with different user accounts
# 1. Create test users in each group
# 2. Attempt login to various services
# 3. Verify permission isolation
```

**Screenshot Required:**
- [ ] Authentik groups page showing all three groups
- [ ] Test showing permission isolation (media-user denied admin access)

---

### Documentation (MUST HAVE)

- [ ] **README includes integration guide for adding new services**
  - [ ] How to create OIDC provider in Authentik
  - [ ] Environment variables needed
  - [ ] Service configuration examples
  - [ ] ForwardAuth setup instructions
  - [ ] Testing procedures

**Documentation Files:**
- [ ] `docs/sso-integration.md` — Complete integration guide
- [ ] `stacks/sso/README.md` — Deployment guide
- [ ] `README.md` — Main project README with SSO section

**Content Requirements:**
- [ ] Step-by-step integration instructions
- [ ] Configuration examples for each service type
- [ ] Troubleshooting section
- [ ] Security best practices

---

## 📋 Additional Verification

### Health Monitoring

```bash
# Run comprehensive health check
./scripts/monitor-sso.sh check

# All containers should show healthy
docker compose -f stacks/sso/docker-compose.yml ps
```

### Test Suite

```bash
# Run full test suite
./scripts/test-sso.sh all

# All tests should pass
# Expected output:
# [✓] test_setup passed
# [✓] test_oidc_providers passed
# [✓] test_forwardauth passed
# [✓] test_service_integrations passed
# [✓] test_security passed
```

### Backup Verification

```bash
# Create test backup
./scripts/backup-sso.sh backup

# Verify backup created
./scripts/backup-sso.sh list

# Test restore procedure (optional, requires downtime)
# ./scripts/backup-sso.sh restore <backup-file>
```

---

## 📸 Required Screenshots List

1. **Infrastructure**
   - [ ] Authentik admin login page
   - [ ] Authentik admin dashboard
   - [ ] All containers healthy (`docker ps` output)

2. **OIDC Integrations**
   - [ ] Grafana login with OAuth button
   - [ ] Grafana post-login dashboard
   - [ ] Gitea login with OAuth option
   - [ ] Gitea post-login page
   - [ ] Outline login with OIDC option
   - [ ] Outline post-login dashboard
   - [ ] Nextcloud login with Social Login
   - [ ] Nextcloud post-login dashboard

3. **ForwardAuth**
   - [ ] Protected service redirect to Authentik
   - [ ] Successful access after auth

4. **Groups & Permissions**
   - [ ] Authentik groups list
   - [ ] Permission test results

5. **Setup Script Output**
   - [ ] Full script execution log
   - [ ] `.env` file with credentials (with secrets masked)

---

## 📝 Required Configuration Files

1. **docker-compose.yml** — SSO stack
   ```bash
   stacks/sso/docker-compose.yml
   ```

2. **Environment Configuration**
   ```bash
   .env  # Root environment
   stacks/sso/.env  # SSO-specific (if used)
   ```

3. **Traefik Middleware**
   ```bash
   config/traefik/dynamic/authentik.yml
   ```

4. **Service Integrations**
   ```bash
   # One config file per service showing OAuth/OIDC config
   stacks/monitoring/docker-compose.yml  # Grafana
   stacks/productivity/docker-compose.yml  # Gitea, Outline
   # etc.
   ```

---

## ✅ Acceptance Criteria Summary

### All of the following MUST be provided:

1. **Working Authentik Instance**
   - [ ] Web UI accessible
   - [ ] Admin login functional
   - [ ] Health checks passing

2. **Automated Setup**
   - [ ] Script creates all providers
   - [ ] Credentials output and saved
   - [ ] Applications created in Authentik

3. **Service Integrations (at least 4)**
   - [ ] Grafana OIDC working
   - [ ] Gitea OIDC working
   - [ ] Outline OIDC working
   - [ ] Nextcloud OIDC working
   - [ ] Portainer OAuth working

4. **ForwardAuth**
   - [ ] Middleware configured
   - [ ] At least one service protected

5. **User Groups**
   - [ ] Three groups created
   - [ ] Permission isolation verified

6. **Documentation**
   - [ ] Integration guide complete
   - [ ] Screenshots provided
   - [ ] Config files shared

7. **Testing**
   - [ ] Test suite passes
   - [ ] Health checks pass
   - [ ] Manual testing documented

---

## 🚫 Rejection Criteria

The submission will be **REJECTED** if any of the following:

- ❌ Codex核查发现 **3个以上** 未解决问题
- ❌ 测试脚本失败或未提供测试输出
- ❌ 使用 `latest` 镜像 tag
- ❌ 硬编码密码或敏感信息
- ❌ 未提供 claude-opus-4-6 使用证据
- ❌ Authentik无法访问或登录
- ❌ 自动化脚本无法创建Provider
- ❌ 少于4个服务的OIDC集成
- ❌ ForwardAuth未配置或未测试
- ❌ 用户组未创建或未测试权限隔离
- ❌ 缺少集成文档或截图

---

## 📊 Submission Checklist

Before submitting, ensure:

- [ ] All containers healthy
- [ ] All OIDC integrations tested and working
- [ ] ForwardAuth tested and working
- [ ] User groups created and tested
- [ ] Test suite passes (`./scripts/test-sso.sh all`)
- [ ] Health monitoring passes (`./scripts/monitor-sso.sh check`)
- [ ] Screenshots captured for all requirements
- [ ] Configuration files documented
- [ ] Integration guide complete
- [ ] No hardcoded secrets
- [ ] All images use specific version tags
- [ ] Setup script execution log provided
- [ ] `.env` file with credentials (secrets masked)

---

**Verification Date**: _______________  
**Verified By**: _______________  
**Status**: _______________
