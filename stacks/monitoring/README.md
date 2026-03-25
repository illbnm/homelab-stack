# Observability Stack

完整的可观测性解决方案，覆盖 Metrics / Logs / Traces / Alerting / Uptime。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                   Observability Stack                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Metrics                                                │
│   ├── Prometheus (指标采集)                             │
│   ├── cAdvisor (容器指标)                               │
│   └── Node Exporter (主机指标)                         │
│                                                          │
│   Logs                                                   │
│   ├── Loki (日志存储)                                   │
│   └── Promtail (日志采集)                               │
│                                                          │
│   Traces                                                │
│   └── Tempo (分布式追踪)                                │
│                                                          │
│   Visualization                                          │
│   └── Grafana (仪表板)                                  │
│                                                          │
│   Alerting                                               │
│   ├── Alertmanager (告警路由)                           │
│   └── ntfy (通知)                                       │
│                                                          │
│   Uptime                                                │
│   └── Uptime Kuma (服务可用性监控)                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 端口 | 说明 |
|------|------|------|
| Prometheus | 9090 | 指标数据库 |
| Grafana | 3000 | 可视化仪表板 |
| Loki | 3100 | 日志聚合 |
| Tempo | 16686 | 分布式追踪 |
| Alertmanager | 9093 | 告警管理 |
| cAdvisor | 8080 | 容器指标 |
| Node Exporter | 9100 | 主机指标 |
| Uptime Kuma | 3001 | 可用性监控 |

## 快速开始

### 1. 配置环境变量

```env
# Prometheus
PROMETHEUS_RETENTION=30d

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_secure_password
GRAFANA_OAUTH_CLIENT_ID=your_client_id
GRAFANA_OAUTH_CLIENT_SECRET=your_client_secret

# Authentik SSO
AUTHENTIK_DOMAIN=authentik.example.com

# Notification
NTFY_HOST=ntfy
```

### 2. 启动服务

```bash
docker compose -f stacks/monitoring/docker-compose.yml up -d
```

### 3. 访问服务

| 服务 | 地址 | 凭据 |
|------|------|------|
| Grafana | https://grafana.${DOMAIN} | GRAFANA_ADMIN_USER / GRAFANA_ADMIN_PASSWORD |
| Prometheus | https://prometheus.${DOMAIN} | 无认证 |
| Alertmanager | https://alertmanager.${DOMAIN} | 无认证 |
| Uptime Kuma | https://status.${DOMAIN} | 无认证（公开状态页） |

## Grafana 预置仪表板

| 仪表板 | 说明 |
|--------|------|
| Node Exporter | 主机资源（CPU、内存、磁盘、网络） |
| Docker Containers | 容器资源使用情况 |
| Logs | Loki 日志浏览器 |

## 告警规则

### 主机告警 (host.yml)

| 告警 | 条件 |
|------|------|
| HostHighCPU | CPU > 80% 持续 5 分钟 |
| HostHighMemory | 内存 < 10% 可用 |
| HostHighDisk | 磁盘 < 15% 可用 |
| HostHighDiskIO | 磁盘 I/O > 80% |

### 容器告警 (containers.yml)

| 告警 | 条件 |
|------|------|
| ContainerHighRestart | 重启 > 3次/小时 |
| ContainerOOMKilled | OOM 被杀 |
| ContainerUnhealthy | 健康检查失败 |

### 服务告警 (services.yml)

| 告警 | 条件 |
|------|------|
| TraefikHigh5xxErrorRate | 5xx 错误率 > 1% |
| ServiceHighResponseTime | P99 响应时间 > 2秒 |
| PrometheusTargetDown | 采集目标宕机 |

## 告警通知

所有告警通过 Alertmanager 路由到 ntfy 推送：

```yaml
# config/alertmanager/alertmanager.yml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

## Uptime Kuma 配置

```bash
# 自动创建所有服务的监控项
./scripts/uptime-kuma-setup.sh
```

### 监控的服务

- Traefik
- Portainer
- Grafana
- Prometheus
- Loki
- Alertmanager
- ntfy
- PostgreSQL
- Redis

## SSO 集成 (Authentik)

Grafana 通过 OIDC 与 Authentik 集成：

```yaml
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_NAME=Authentik
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
```

用户组映射：
- `homelab-admins` → Grafana Admin
- `homelab-users` → Grafana Viewer

## 数据保留

| 数据类型 | 保留时间 |
|----------|----------|
| Prometheus | 30天 |
| Loki | 7天 |
| Tempo | 3天 |

## 健康检查端点

| 服务 | 端点 |
|------|------|
| Prometheus | `/-/healthy` |
| Grafana | `/api/health` |
| Alertmanager | `/-/healthy` |
| Loki | `/ready` |
| Tempo | `:4318/ready` |
| cAdvisor | `/health` |
| Node Exporter | `/metrics` |

## 故障排除

### Prometheus 目标显示 DOWN

```bash
# 检查目标状态
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets'

# 检查服务是否可达
docker exec -it prometheus wget -qO- http://target:port/metrics
```

### Grafana 登录失败

1. 确认 Authentik 应用配置正确
2. 检查 GRAFANA_OAUTH_CLIENT_ID/SECRET
3. 确认 Authentik 域名可访问

### Loki 无日志

```bash
# 检查 Promtail 日志
docker logs promtail

# 检查 Loki 状态
curl http://localhost:3100/ready
```

## 相关文档

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [Loki 文档](https://grafana.com/docs/loki/)
- [Tempo 文档](https://grafana.com/docs/tempo/)
- [Alertmanager 文档](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Uptime Kuma 文档](https://github.com/louislam/uptime-kuma)
