# 📊 Observability Stack — Prometheus + Grafana + Loki + Tempo + Alerting

> 完整可观测性三支柱：Metrics + Logs + Traces + Alerting + Uptime 监控。

## 服务清单 (10 个)

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Prometheus** | `prom/prometheus:v2.54.1` | `prometheus.${DOMAIN}` | 指标采集 |
| **Grafana** | `grafana/grafana:11.2.2` | `grafana.${DOMAIN}` | 可视化面板 |
| **Loki** | `grafana/loki:3.2.0` | internal | 日志聚合 |
| **Promtail** | `grafana/promtail:3.2.0` | — | 日志采集 Agent |
| **Tempo** | `grafana/tempo:2.6.0` | internal | 分布式链路追踪 |
| **Alertmanager** | `prom/alertmanager:v0.27.0` | internal | 告警路由 |
| **cAdvisor** | `gcr.io/cadvisor/cadvisor:v0.50.0` | internal | 容器指标 |
| **Node Exporter** | `prom/node-exporter:v1.8.2` | internal | 主机指标 |
| **Uptime Kuma** | `louislam/uptime-kuma:1.23.15` | `status.${DOMAIN}` | 服务可用性 |

## 快速启动

```bash
docker compose -f stacks/observability/docker-compose.yml up -d
```

## Prometheus 采集目标

| Job | Target | 指标 |
|-----|--------|------|
| prometheus | localhost:9090 | 自监控 |
| cadvisor | cadvisor:8080 | 容器 CPU/内存/网络 |
| node-exporter | node-exporter:9100 | 主机 CPU/内存/磁盘 |
| traefik | traefik:8080 | 请求量/延迟/错误率 |
| loki | loki:3100 | 日志系统指标 |
| tempo | tempo:3200 | 追踪系统指标 |

## Grafana Dashboard (自动加载)

通过 provisioning 自动加载，无需手动导入：

| Dashboard | ID | 说明 |
|-----------|-----|------|
| Node Exporter Full | 1860 | 主机资源详情 |
| Docker Containers | 179 | 容器资源监控 |
| Traefik | 17346 | 反代流量分析 |
| Loki | 13639 | 日志查询面板 |

Dashboard JSON 文件放在 `config/grafana/dashboards/`。

下载方式：
```bash
# 从 Grafana.com 下载
curl -o config/grafana/dashboards/node-exporter.json \
  "https://grafana.com/api/dashboards/1860/revisions/latest/download"
```

## 告警规则

### 主机告警 (host.yml)
- CPU > 80% 持续 5 分钟
- 内存 > 90%
- 磁盘 > 85%
- IO Wait > 20% 持续 10 分钟

### 容器告警 (containers.yml)
- 重启次数 > 3 次/小时
- OOM 被杀
- 健康检查失败 5 分钟

### 服务告警 (services.yml)
- Traefik 5xx 错误率 > 1%
- 服务 P99 延迟 > 2s

告警路由: Prometheus → Alertmanager → ntfy 推送

## Loki 日志

Promtail 自动采集：
- 所有 Docker 容器日志 (docker_sd_configs)
- 系统日志 (/var/log/syslog)

Grafana 中查询: Explore → Loki → `{container="nginx"}`

## Grafana Authentik OIDC

已预配置 OIDC 环境变量：
- `homelab-admins` 组 → Grafana Admin
- `homelab-users` 组 → Grafana Viewer

## 数据保留

| 数据 | 保留时间 | 配置 |
|------|---------|------|
| Prometheus 指标 | 30 天 | `PROMETHEUS_RETENTION` |
| Loki 日志 | 7 天 | `config/loki/loki.yml` |
| Tempo 追踪 | 3 天 | `config/tempo/tempo.yml` |

## Uptime Kuma

访问 `https://status.${DOMAIN}` 查看服务状态页。

首次访问创建管理员账号，然后添加监控项。
