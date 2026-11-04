# 📊 Observability Stack — 全栈可观测性中心

本 Stack 提供企业级覆盖 **Metrics (指标)**、**Logs (日志)**、**Traces (链路追踪)** 与 **Uptime (可用性/SLA)** 的全景可观测性解决方案。

---

## 📦 服务清单与架构拓扑

| 服务 | 镜像版本 | 内部端口 | 反代入口 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **Prometheus** | `prom/prometheus:v2.54.1` | `9090` | `https://prometheus.${DOMAIN}` | 时序指标采集与告警规则引擎 |
| **Grafana** | `grafana/grafana:11.2.2` | `3000` | `https://grafana.${DOMAIN}` | 统一全景数据可视化看板 |
| **Loki** | `grafana/loki:3.2.0` | `3100` | 内部网络 | 高效无索引日志聚合分析引擎 |
| **Promtail** | `grafana/promtail:3.2.0` | `9080` | 内部网络 | Docker 容器与系统日志采集 Agent |
| **Tempo** | `grafana/tempo:2.6.0` | `3200` | 内部网络 | 分布式链路追踪后端 |
| **Alertmanager** | `prom/alertmanager:v0.27.0` | `9093` | `https://alertmanager.${DOMAIN}` | 告警去重、分组与分发中心 |
| **Node Exporter** | `prom/node-exporter:v1.8.2` | `9100` | 内部网络 | 宿主机 CPU、内存、磁盘与网络采集器 |
| **cAdvisor** | `gcr.io/cadvisor/cadvisor:v0.50.0` | `8080` | 内部网络 | 容器级别资源与性能分析工具 |
| **Uptime Kuma** | `louislam/uptime-kuma:1.23.15` | `3001` | `https://status.${DOMAIN}` | 服务可用性监控与公开 Status 页面 |

---

## 🚀 启动与部署

```bash
cd stacks/monitoring
docker compose up -d
docker compose ps
```

---

## 📈 预配置数据源 (Grafana Auto-Provisioning)

启动后 Grafana 会自动装配以下数据源，无需手动配置：
- **Prometheus** (`http://prometheus:9090`) - 默认时序数据源
- **Loki** (`http://loki:3100`) - 容器与系统日志数据源
- **Tempo** (`http://tempo:3200`) - 分布式 APM 追踪数据源
