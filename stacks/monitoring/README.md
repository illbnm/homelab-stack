# Monitoring Stack - Observability Platform

完整的可观测性平台，提供指标监控、日志聚合、分布式追踪、告警管理和运维管理功能。

## 🎯 功能特性

### 核心监控
- **Prometheus** - 指标收集和告警
- **Grafana** - 可视化仪表板和数据分析
- **Alertmanager** - 告警路由和通知

### 日志管理
- **Loki** - 日志聚合系统
- **Promtail** - 日志收集代理

### 分布式追踪
- **Tempo** - 分布式追踪后端
- 支持 Jaeger、OTLP 协议

### 系统监控
- **Node Exporter** - 主机指标收集
- **cAdvisor** - 容器指标收集
- **Uptime Kuma** - 服务可用性监控

### 运维管理
- **Grafana OnCall** - 值班管理和告警升级
- 支持短信、电话、Slack、Telegram 等通知方式

## 📋 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- 至少 4GB 可用内存
- 至少 20GB 磁盘空间（用于数据存储）
- 已部署 Traefik 反向代理
- 已部署 Authentik SSO（可选但推荐）

## 🚀 快速开始

### 1. 环境配置

复制环境变量模板：

```bash
cp .env.example .env
```

编辑 `.env` 文件，配置必要的参数：

```bash
# 域名配置
DOMAIN=yourdomain.com

# Authentik SSO
AUTHENTIK_DOMAIN=auth.yourdomain.com

# Grafana 管理员
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_secure_password

# Grafana OAuth（从 Authentik 获取）
GRAFANA_OAUTH_CLIENT_ID=your_client_id
GRAFANA_OAUTH_CLIENT_SECRET=your_client_secret

# OnCall 配置
GRAFANA_ONCALL_TOKEN=your_grafana_service_account_token
ONCALL_SECRET_KEY=your_random_secret_key
POSTGRES_PASSWORD=your_postgres_password
```

### 2. 创建 Grafana Service Account Token

OnCall 需要一个 Grafana Service Account Token：

1. 访问 Grafana > Configuration > Service accounts
2. 创建新的 Service Account
3. 添加 "Admin" 角色
4. 生成 Service Account Token
5. 将 Token 添加到 `.env` 文件中的 `GRAFANA_ONCALL_TOKEN`

### 3. 启动服务

```bash
cd stacks/monitoring
docker-compose up -d
```

### 4. 验证服务状态

```bash
# 检查所有服务是否运行
docker-compose ps

# 查看服务日志
docker-compose logs -f [service_name]
```

## 🌐 访问服务

所有服务通过 Traefik 反向代理访问，使用 HTTPS 加密：

| 服务 | URL | 说明 |
|------|-----|------|
| Grafana | https://grafana.yourdomain.com | 主要监控界面 |
| Prometheus | https://prometheus.yourdomain.com | 指标查询（需要认证）|
| Alertmanager | https://alertmanager.yourdomain.com | 告警管理（需要认证）|
| Uptime Kuma | https://uptime.yourdomain.com | 可用性监控 |
| Grafana OnCall | https://oncall.yourdomain.com | 值班管理 |

### 默认凭证

- **Grafana**: admin / (您设置的密码)
- **Uptime Kuma**: 首次访问时创建管理员账号

## 🔧 配置说明

### Prometheus 告警规则

告警规则位于 `../../config/prometheus/rules/homelab.yml`：

- **ContainerDown** - 容器停止超过 2 分钟
- **HighCPU** - CPU 使用率 > 85% 持续 5 分钟
- **HighMemory** - 内存使用率 > 90% 持续 5 分钟
- **DiskSpaceLow** - 磁盘剩余空间 < 10%

### Grafana 数据源

自动配置的数据源：

- **Prometheus** - 指标数据
- **Loki** - 日志数据
- **Tempo** - 追踪数据

### 自定义仪表板

推荐导入以下社区仪表板：

1. **Node Exporter Full** (ID: 1860)
   - 主机监控仪表板

2. **Docker Container** (ID: 11600)
   - 容器监控仪表板

3. **Loki Kubernetes** (ID: 14055)
   - 日志浏览仪表板

### 日志收集配置

Promtail 自动收集：
- `/var/log` - 系统日志
- `/var/lib/docker/containers` - 容器日志

### 分布式追踪配置

应用程序需要配置发送追踪数据到 Tempo：

**OTLP HTTP:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4318
```

**OTLP gRPC:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317
```

**Jaeger:**
```bash
JAEGER_AGENT_HOST=tempo
JAEGER_AGENT_PORT=6831
```

## 📊 监控最佳实践

### 1. 指标收集

为您的应用程序添加 Prometheus metrics 端点：
- 使用 `/metrics` 路径
- 使用 Prometheus client libraries
- 标记重要指标

### 2. 日志规范

- 使用结构化日志（JSON 格式）
- 包含 trace ID 以关联追踪
- 设置合适的日志级别

### 3. 告警策略

- 设置合理的告警阈值
- 配置告警分级（warning, critical）
- 避免告警疲劳

### 4. 仪表板设计

- 创建服务级别的概览仪表板
- 使用变量实现动态过滤
- 添加文档和说明

## 🔔 告警通知配置

### Alertmanager 配置

编辑 `../../config/alertmanager/alertmanager.yml` 配置接收器：

```yaml
receivers:
  - name: 'team-email'
    email_configs:
      - to: 'team@yourdomain.com'
        from: 'alertmanager@yourdomain.com'
        smarthost: 'smtp.yourdomain.com:587'

  - name: 'webhook'
    webhook_configs:
      - url: 'https://your-webhook-url'
```

### Grafana OnCall 配置

OnCall 提供更灵活的告警管理：

1. 配置通知渠道（Slack、Telegram、短信等）
2. 设置值班轮换
3. 配置告警升级策略
4. 定义响应时间和流程

## 🐛 常见问题

### 1. 服务无法启动

**问题**: 容器启动失败或持续重启

**解决方案**:
```bash
# 查看容器日志
docker-compose logs [service_name]

# 检查配置文件语法
docker-compose config

# 验证网络是否存在
docker network ls | grep proxy
```

### 2. 无法访问服务

**问题**: 502 Bad Gateway 或连接超时

**解决方案**:
```bash
# 检查 Traefik 路由
docker logs traefik | grep [service_name]

# 验证服务健康状态
docker inspect [container_name] | grep Health

# 检查网络连接
docker network inspect monitoring_monitoring
```

### 3. Grafana 数据源连接失败

**问题**: 数据源测试失败

**解决方案**:
```bash
# 验证 Prometheus 可达性
docker exec grafana wget -qO- http://prometheus:9090/-/healthy

# 检查网络
docker network inspect monitoring_monitoring

# 重启 Grafana
docker-compose restart grafana
```

### 4. 日志不显示

**问题**: Loki 查询无结果

**解决方案**:
```bash
# 检查 Promtail 状态
docker-compose logs promtail

# 验证日志文件权限
ls -la /var/log /var/lib/docker/containers

# 检查 Loki 配置
docker exec loki cat /etc/loki/loki-config.yml
```

### 5. OnCall 无法启动

**问题**: OnCall 服务启动失败

**解决方案**:
```bash
# 检查数据库连接
docker-compose logs postgres-oncall

# 验证 Service Account Token
# 确保 Token 有效且有足够的权限

# 检查 Redis 连接
docker-compose logs redis-oncall
```

### 6. 追踪数据未显示

**问题**: Tempo 无追踪数据

**解决方案**:
- 确认应用程序配置了正确的追踪端点
- 检查 Tempo 日志是否有接收数据
- 验证网络连接和端口映射

## 📈 性能优化

### Prometheus 优化

```yaml
# 调整数据保留时间
command:
  - --storage.tsdb.retention.time=30d

# 增加内存限制
deploy:
  resources:
    limits:
      memory: 4G
```

### Loki 优化

```yaml
# 调整日志保留时间
table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
```

### Grafana 优化

```yaml
environment:
  # 启用缓存
  - GF_REMOTE_CACHE_CONNSTR=redis://redis:6379/1
  # 调整查询超时
  - GF_DATAPROXY_TIMEOUT=60
```

## 🔐 安全建议

1. **更改默认密码**: 立即更改所有默认密码
2. **启用 SSO**: 使用 Authentik 进行统一认证
3. **网络隔离**: 使用 Docker 网络隔离服务
4. **定期备份**: 备份 Grafana 仪表板和配置
5. **访问控制**: 限制管理界面的访问权限

## 📚 相关文档

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [Loki 文档](https://grafana.com/docs/loki/latest/)
- [Tempo 文档](https://grafana.com/docs/tempo/latest/)
- [Grafana OnCall 文档](https://grafana.com/docs/oncall/latest/)
- [Uptime Kuma 文档](https://github.com/louislam/uptime-kuma/wiki)

## 🆘 获取帮助

如果遇到问题：

1. 查看本 README 的常见问题部分
2. 检查服务日志
3. 参考官方文档
4. 在 GitHub Issues 中搜索或提交问题

## 📝 许可证

本监控栈配置遵循项目主许可证。
