# 📊 HomeLab Observability Stack

完整的可观测性解决方案，包含 Metrics、Logs、Traces、Alerting 和 Uptime 监控。

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | 指标采集 |
| Grafana | `grafana/grafana:11.2.2` | 3000 | 可视化面板 |
| Loki | `grafana/loki:3.2.0` | 3100 | 日志聚合 |
| Promtail | `grafana/promtail:3.2.0` | - | 日志采集 |
| Tempo | `grafana/tempo:2.6.0` | 3200 | 链路追踪 |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | 告警路由 |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | 容器指标 |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | 主机指标 |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | 服务可用性 |

## 🚀 快速启动

### 1. 配置环境变量

```bash
cd stacks/observability
cp .env.example .env
```

编辑 `.env` 文件，配置：
- 域名
- Grafana 密码
- Authentik OAuth 凭证
- ntfy 推送主题

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 访问服务

| 服务 | URL |
|------|-----|
| Grafana | https://grafana.${DOMAIN} |
| Prometheus | https://prometheus.${DOMAIN} |
| Loki | https://loki.${DOMAIN} |
| Tempo | https://tempo.${DOMAIN} |
| Alertmanager | https://alertmanager.${DOMAIN} |
| cAdvisor | https://cadvisor.${DOMAIN} |
| Node Exporter | https://node.${DOMAIN} |
| Uptime Kuma | https://status.${DOMAIN} |

## 📊 Grafana Dashboard

预置 Dashboard 自动加载：

| Dashboard | 来源 | ID |
|-----------|------|-----|
| Node Exporter Full | grafana.com | 1860 |
| Docker Container & Host Metrics | grafana.com | 179 |
| Traefik Official | grafana.com | 17346 |
| Loki Dashboard | grafana.com | 13639 |
| Uptime Kuma | grafana.com | 18278 |

## 🚨 告警规则

### 主机告警
- CPU 使用率 > 80% 持续 5 分钟
- 内存使用率 > 90%
- 磁盘使用率 > 85%

### 容器告警
- 容器重启次数 > 3 次/小时
- 容器 OOM 被杀
- 容器健康检查失败

### 服务告警
- Traefik 5xx 错误率 > 1%
- 服务响应时间 P99 > 2s

## 🔔 告警推送

告警通过 ntfy 推送：

```bash
# 订阅告警
ntfy sub homelab-alerts
```

## 🔐 SSO 集成

Grafana 已配置 Authentik OIDC：
- `homelab-admins` 组 → Grafana Admin
- `homelab-users` 组 → Grafana Viewer

## 📈 Prometheus 采集目标

- cAdvisor - 容器资源指标
- Node Exporter - 主机资源指标
- Traefik - 反代指标
- Authentik - SSO 指标
- Nextcloud - 存储指标
- Gitea - 代码托管指标
- Prometheus - 自监控

## 🐛 故障排查

### 查看服务状态

```bash
docker compose ps
```

### 查看日志

```bash
docker compose logs prometheus
docker compose logs loki
docker compose logs promtail
```

### 验证告警

```bash
# 触发 CPU 告警
stress --cpu 4 --timeout 300
```

## 🔗 相关链接

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [Loki 文档](https://grafana.com/docs/loki/)

---

**赏金**: $280 USDT  
**Issue**: https://github.com/illbnm/homelab-stack/issues/10
