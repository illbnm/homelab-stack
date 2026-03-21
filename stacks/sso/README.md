# SSO Stack - Authentik 统一身份认证

完整的单点登录解决方案，基于 Authentik 提供企业级身份认证和授权管理。

## 🌟 功能特性

- **统一身份认证**: 一次登录，访问所有服务
- **多协议支持**: OAuth2, OIDC, SAML, LDAP
- **企业级安全**: 2FA/MFA, 密码策略, 会话管理
- **用户自助**: 密码重置, 用户注册, 个人资料管理
- **审计日志**: 完整的登录和权限变更记录

## 📋 服务组件

| 服务 | 端口 | 描述 |
|------|------|------|
| Authentik Server | 9000 | 主认证服务器 |
| Authentik Worker | - | 后台任务处理 |
| PostgreSQL | 5432 | 用户数据存储 |
| Redis | 6379 | 会话缓存 |

## 🚀 快速部署

### 1. 环境准备

```bash
# 复制环境配置
cp stacks/sso/.env.example stacks/sso/.env

# 编辑配置文件
vim stacks/sso/.env
```

### 2. 必需配置项

```env
# 域名配置
AUTHENTIK_DOMAIN=auth.yourdomain.com

# 数据库配置
POSTGRES_PASSWORD=your_secure_password
AUTHENTIK_SECRET_KEY=your_secret_key_min_50_chars

# 邮件配置（可选）
AUTHENTIK_EMAIL__HOST=smtp.gmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=your-email@gmail.com
AUTHENTIK_EMAIL__PASSWORD=your-app-password
```

### 3. 启动服务

```bash
# 启动 SSO 栈
docker-compose -f stacks/sso/docker-compose.yml up -d

# 查看日志
docker-compose -f stacks/sso/docker-compose.yml logs -f
```

### 4. 初始化配置

```bash
# 运行自动化设置脚本
./scripts/setup-authentik.sh
```

## ⚙️ 集成配置

### 已集成的服务

| 服务 | 集成类型 | 访问地址 |
|------|----------|----------|
| **Portainer** | OAuth2 | portainer.yourdomain.com |
| **Grafana** | Generic OAuth | grafana.yourdomain.com |
| **Gitea** | OpenID Connect | git.yourdomain.com |
| **Outline** | OIDC | outline.yourdomain.com |
| **Open WebUI** | OIDC | chat.yourdomain.com |
| **Nextcloud** | OIDC | cloud.yourdomain.com |
| **Bookstack** | OIDC | books.yourdomain.com |

### Traefik ForwardAuth 保护

所有服务通过 Traefik 中间件自动获得 SSO 保护：

```yaml
middlewares:
  - "authentik@file"
```

## 🔧 管理操作

### 首次登录

1. 访问 `https://auth.yourdomain.com`
2. 使用初始管理员账户：
   - 用户名: `akadmin`
   - 密码: 检查 `./scripts/setup-authentik.sh` 输出

### 用户管理

```bash
# 查看所有用户
docker exec -it authentik-server ak manage user list

# 创建用户
docker exec -it authentik-server ak manage user create \
  --username newuser \
  --email user@domain.com \
  --first-name "First" \
  --last-name "Last"

# 重置密码
docker exec -it authentik-server ak manage user set_password \
  --user newuser \
  --password newpassword
```

### 备份恢复

```bash
# 数据库备份
docker exec authentik-postgres pg_dump -U authentik authentik > backup.sql

# 数据库恢复
cat backup.sql | docker exec -i authentik-postgres psql -U authentik authentik
```

## 🎛️ 高级配置

### 自定义主题

```bash
# 挂载自定义主题
volumes:
  - ./custom-themes:/web/dist/custom
```

### LDAP 集成

```yaml
# 添加 LDAP 环境变量
environment:
  AUTHENTIK_LDAP__ENABLED: "true"
  AUTHENTIK_LDAP__HOST: "ldap.company.com"
  AUTHENTIK_LDAP__BIND_DN: "cn=admin,dc=company,dc=com"
```

### 多因子认证

1. 登录 Authentik 管理界面
2. 进入 **Flows & Stages**
3. 编辑认证流程
4. 添加 **TOTP** 或 **WebAuthn** Stage

## 🔍 故障排除

### 常见问题

**问题**: 无法访问 Authentik 界面
```bash
# 检查容器状态
docker-compose -f stacks/sso/docker-compose.yml ps

# 检查 Traefik 路由
docker logs traefik | grep authentik
```

**问题**: OAuth2 重定向失败
```bash
# 检查 Provider 配置
docker exec -it authentik-server ak manage provider list

# 重新运行设置脚本
./scripts/setup-authentik.sh --reconfigure
```

**问题**: 数据库连接失败
```bash
# 检查数据库状态
docker exec authentik-postgres pg_isready -U authentik

# 查看数据库日志
docker logs authentik-postgres
```

### 调试模式

```env
# 启用调试日志
AUTHENTIK_LOG_LEVEL=debug
AUTHENTIK_ERROR_REPORTING__ENABLED=true
```

### 性能优化

```yaml
# Worker 数量调整
environment:
  AUTHENTIK_WORKER_CONCURRENCY: "4"

# Redis 优化
redis:
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

## 🔐 安全最佳实践

1. **强密码策略**: 启用密码复杂度要求
2. **会话管理**: 设置合理的会话超时时间
3. **审计日志**: 定期检查登录和权限变更记录
4. **证书管理**: 使用有效的 SSL 证书
5. **网络隔离**: 限制数据库和 Redis 的网络访问

## 📚 相关文档

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [OAuth2 配置指南](../docs/oauth2-setup.md)
- [Traefik ForwardAuth](../docs/traefik-forwardauth.md)
- [故障排除指南](../docs/troubleshooting-sso.md)

## 🤝 支持

遇到问题？

1. 查看 [Issues](https://github.com/illbnm/homelab-stack/issues)
2. 检查 [故障排除文档](../docs/troubleshooting.md)
3. 提交新的 Issue 或 PR
