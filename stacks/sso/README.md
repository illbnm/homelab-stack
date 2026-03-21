# SSO Stack - Authentik 统一身份认证

Authentik SSO 提供完整的单点登录解决方案，支持 OIDC、SAML 等现代认证协议，实现 HomeLab 所有服务的统一身份管理。

## 架构组件

- **Authentik Server**: 核心认证服务器
- **PostgreSQL**: 用户数据存储
- **Redis**: 会话缓存
- **Traefik Integration**: 自动 HTTPS 和负载均衡

## 快速开始

### 1. 环境配置

```bash
cd stacks/sso
cp .env.example .env
```

编辑 `.env` 文件：

```bash
# 域名配置 (必须修改)
AUTHENTIK_HOST=auth.yourdomain.com
AUTHENTIK_SECRET_KEY=your-secret-key-here-min-50-chars-long
AUTHENTIK_POSTGRES_PASSWORD=strong-postgres-password
AUTHENTIK_REDIS_PASSWORD=strong-redis-password

# 邮件配置 (可选，用于密码重置)
AUTHENTIK_EMAIL_HOST=smtp.gmail.com
AUTHENTIK_EMAIL_PORT=587
AUTHENTIK_EMAIL_USERNAME=your-email@gmail.com
AUTHENTIK_EMAIL_PASSWORD=your-app-password
AUTHENTIK_EMAIL_FROM=noreply@yourdomain.com
```

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 初始设置

访问 `https://auth.yourdomain.com/if/flow/initial-setup/`：

1. 创建管理员账户
2. 完成初始配置向导
3. 登录管理界面

## 服务集成

### Traefik 集成 (推荐)

使用 ForwardAuth 中间件保护所有服务：

```yaml
# 在其他服务的 docker-compose.yml 中添加
labels:
  - "traefik.http.middlewares.authentik.forwardauth.address=http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
  - "traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true"
  - "traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid"
  - "traefik.http.routers.yourservice.middlewares=authentik"
```

### OIDC 应用配置

#### Grafana 集成

1. 在 Authentik 中创建 Provider：
   - Type: OAuth2/OIDC
   - Client ID: `grafana`
   - Redirect URI: `https://grafana.yourdomain.com/login/generic_oauth`

2. Grafana 配置：

```ini
[auth.generic_oauth]
enabled = true
name = Authentik
allow_sign_up = true
client_id = grafana
client_secret = your-client-secret
scopes = openid profile email
auth_url = https://auth.yourdomain.com/application/o/authorize/
token_url = https://auth.yourdomain.com/application/o/token/
api_url = https://auth.yourdomain.com/application/o/userinfo/
```

#### Nextcloud 集成

1. 安装 OIDC 应用插件
2. 配置 Provider：
   - Client ID: `nextcloud`
   - Discovery URL: `https://auth.yourdomain.com/application/o/nextcloud/.well-known/openid_configuration`

#### Portainer 集成

1. 在 Authentik 创建 OAuth2 Provider
2. Portainer OAuth 设置：
   - Authorization URL: `https://auth.yourdomain.com/application/o/authorize/`
   - Access Token URL: `https://auth.yourdomain.com/application/o/token/`
   - Resource URL: `https://auth.yourdomain.com/application/o/userinfo/`

### SAML 应用配置

#### 示例：GitLab 集成

1. 在 Authentik 创建 SAML Provider
2. GitLab 配置：

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: 'saml',
    args: {
      assertion_consumer_service_url: 'https://gitlab.yourdomain.com/users/auth/saml/callback',
      idp_cert_fingerprint: 'your-cert-fingerprint',
      idp_sso_target_url: 'https://auth.yourdomain.com/application/saml/gitlab/sso/binding/redirect/',
      issuer: 'https://gitlab.yourdomain.com',
      attribute_statements: {
        email: ['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'],
        name: ['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'],
        username: ['http://schemas.goauthentik.io/2021/02/saml/username']
      }
    }
  }
]
```

## 高级配置

### LDAP Outpost

为传统服务提供 LDAP 认证：

```yaml
# 添加到 docker-compose.yml
authentik-ldap:
  image: ghcr.io/goauthentik/ldap:${AUTHENTIK_TAG:-2024.2.2}
  ports:
    - "389:3389"
    - "636:6636"
  environment:
    AUTHENTIK_HOST: https://auth.yourdomain.com
    AUTHENTIK_INSECURE: false
    AUTHENTIK_TOKEN: ldap-outpost-token
```

### 多因素认证 (MFA)

支持的 MFA 方法：
- TOTP (Google Authenticator, Authy)
- WebAuthn (YubiKey, TouchID)
- SMS (需要配置短信服务商)
- 静态令牌

配置示例：
1. 进入 Admin Interface → Flows & Stages
2. 创建 Authentication Stage
3. 选择 MFA 验证器类型
4. 绑定到登录流程

### 用户自助服务

启用功能：
- 密码重置
- 用户注册
- 个人资料编辑
- MFA 设备管理

```yaml
# 在 .env 中配置
AUTHENTIK_DEFAULT_USER_CHANGE_EMAIL=true
AUTHENTIK_DEFAULT_USER_CHANGE_NAME=true
AUTHENTIK_DEFAULT_USER_CHANGE_USERNAME=true
```

## 监控和日志

### Prometheus 指标

Authentik 内置 Prometheus 导出器：

```yaml
# 在 monitoring stack 中添加
- job_name: 'authentik'
  static_configs:
    - targets: ['authentik-server:9000']
  metrics_path: '/metrics'
```

### 日志收集

配置日志级别和输出：

```yaml
environment:
  AUTHENTIK_LOG_LEVEL: info
  AUTHENTIK_ERROR_REPORTING__ENABLED: false
```

## 备份和恢复

### 数据库备份

```bash
# 备份 PostgreSQL 数据
docker compose exec authentik-postgresql pg_dumpall -U authentik > authentik-backup.sql

# 恢复数据
docker compose exec -T authentik-postgresql psql -U authentik < authentik-backup.sql
```

### 配置备份

```bash
# 导出配置
docker compose exec authentik-server ak export > authentik-config.yaml

# 导入配置
docker compose exec -T authentik-server ak import < authentik-config.yaml
```

## 故障排除

### 常见问题

#### 1. 服务启动失败

```bash
# 检查容器状态
docker compose ps
docker compose logs authentik-server

# 常见原因：
# - SECRET_KEY 长度不足 (需要至少 50 字符)
# - 数据库连接失败
# - Redis 连接问题
```

#### 2. OIDC 回调失败

- 检查 Redirect URI 配置是否正确
- 验证客户端 ID 和密钥
- 确认防火墙设置

#### 3. SAML 证书问题

```bash
# 重新生成自签名证书
docker compose exec authentik-server ak create-certs
```

#### 4. 邮件发送失败

```bash
# 测试 SMTP 配置
docker compose exec authentik-server ak test-email your-email@domain.com
```

### 性能调优

#### Redis 优化

```yaml
authentik-redis:
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

#### PostgreSQL 优化

```yaml
authentik-postgresql:
  command: postgres -c shared_preload_libraries=pg_stat_statements -c max_connections=200
```

### 日志调试

启用详细日志：

```yaml
environment:
  AUTHENTIK_LOG_LEVEL: debug
  AUTHENTIK_LOG_FILE: /var/log/authentik.log
```

## 安全建议

1. **强密码策略**: 配置密码复杂度要求
2. **会话管理**: 设置合理的会话过期时间
3. **审计日志**: 启用用户活动日志记录
4. **网络隔离**: 使用 Docker 网络隔离
5. **SSL/TLS**: 确保所有连接使用 HTTPS
6. **定期更新**: 保持 Authentik 版本最新

## 集成示例

### 完整 HomeLab 集成

参考 `examples/` 目录下的配置文件：
- `traefik-forwardauth.yml`: Traefik 集成
- `grafana-oidc.yml`: Grafana OIDC 配置
- `nextcloud-saml.yml`: Nextcloud SAML 配置
- `portainer-oauth.yml`: Portainer OAuth2 配置

每个服务的详细集成步骤请参考对应 stack 的 README。
