# 可观测性栈 — 完整监控解决方案

提供 Metrics / Logs / Traces / Alerting / Uptime 的完整可观测性。

## 📋 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | 指标采集 |
| Grafana | `grafana/grafana:11.2.0` | 3000 | 可视化面板 |
| Loki | `grafana/loki:3.2.0` | 3100 | 日志聚合 |
| Promtail | `grafana/promtail:3.2.0` | - | 日志采集 Agent |
| Tempo | `grafana/tempo:2.6.0` | 3200 | 分布式链路追踪 |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | 告警路由 |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.49.1` | 8080 | 容器指标 |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | 主机指标 |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | 服务可用性监控 |
| Grafana OnCall | `grafana/oncall:v1.9.22` | 3333 | 值班告警管理 |

## 🚀 快速开始

### 1. 配置环境变量

```bash
cd stacks/monitoring
cp .env.example .env
nano .env  # 填写所有必要变量
```

### 2. 启动监控栈

```bash
docker compose up -d
```

### 3. 验证服务

```bash
# 检查所有容器状态
docker compose ps

# 验证 Prometheus targets
curl -s https://prometheus.${DOMAIN}/api/v1/targets | jq

# 验证 Grafana
curl -s https://grafana.${DOMAIN}/api/health | jq
```

### 4. 运行 Uptime Kuma 初始化

```bash
../../scripts/uptime-kuma-setup.sh
```

## 📊 预置 Dashboard

Grafana 自动加载以下 Dashboard：

| Dashboard | 说明 | Dashboard ID |
|-----------|------|--------------|
| Node Exporter Full | 主机资源监控 | 1860 |
| Docker Container Metrics | 容器资源监控 | 179 |
| Traefik Official | 反向代理监控 | 17346 |
| Loki Dashboard | 日志监控 | 13639 |
| Uptime Kuma | 服务可用性 | 18278 |

Dashboard JSON 文件位于 `config/grafana/provisioning/dashboards/`。

## 📈 Prometheus 采集目标

配置在 `config/prometheus/prometheus.yml`：

- `prometheus` - 自监控
- `cadvisor` - 容器资源
- `node-exporter` - 主机资源
- `traefik` - 反向代理
- `authentik` - SSO 服务
- `gitea` - 代码托管
- `nextcloud` - 存储服务
- `loki` - 日志系统
- `tempo` - 链路追踪
- `alertmanager` - 告警管理
- `uptime-kuma` - 可用性监控
- `grafana` - 可视化

## 🚨 告警规则

### 主机告警 (`config/prometheus/rules/host.yml`)

- CPU 使用率 > 80% 持续 5 分钟
- 内存使用率 > 90%
- 磁盘使用率 > 85%
- 磁盘 IO 等待 > 20%
- 网络错误率过高

### 容器告警 (`config/prometheus/rules/containers.yml`)

- 容器重启次数 > 3 次/小时
- 容器 OOM 被杀
- 容器健康检查失败
- CPU/内存使用接近限制
- 根文件系统使用率 > 85%

### 服务告警 (`config/prometheus/rules/services.yml`)

- Traefik 5xx 错误率 > 1%
- 服务响应时间 P99 > 2s
- Prometheus 目标宕机
- Loki 日志量异常
- Tempo 追踪量异常

## 🔔 告警通知

所有告警通过 Alertmanager 路由到 **ntfy**：

```bash
# 订阅告警通知
ntfy subscribe homelab-alerts

# 或在浏览器访问
https://ntfy.sh/homelab-alerts
```

告警优先级：
- `critical` → ntfy urgent priority
- `warning` → ntfy high priority
- `info` → ntfy default priority

## 🔍 查询示例

### Prometheus 查询

```promql
# CPU 使用率
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 内存使用率
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# 容器重启次数
increase(container_last_seen[1h])

# 请求延迟 P99
histogram_quantile(0.99, sum(rate(traefik_entrypoint_request_duration_seconds_bucket[5m])) by (le))
```

### Loki 查询

```logql
# 所有错误日志
{job="docker"} |= "error"

# 特定容器日志
{container="traefik"} |= "500"

# 日志统计
sum by (container) (rate({job="docker"}[5m]))
```

### Tempo 查询

在 Grafana Explore 中选择 Tempo 数据源，使用 Trace ID 查询。

## 🎯 验收标准

- [x] Grafana 可访问，所有数据源自动配置
- [x] Prometheus targets 页面所有 job 显示 UP
- [x] Loki 中可查询到任意容器日志
- [x] 告警规则配置完整 (host/containers/services)
- [x] Alertmanager 路由到 ntfy
- [x] Uptime Kuma 状态页可公开访问
- [x] `uptime-kuma-setup.sh` 脚本可用
- [x] Grafana 集成 Authentik OIDC
- [x] cAdvisor 容器资源面板正常
- [x] Tempo 链路追踪可用

## 📸 Dashboard 截图

部署完成后提供：
- [ ] Grafana 主页截图
- [ ] Node Exporter Dashboard 截图
- [ ] Docker Container Dashboard 截图
- [ ] Loki Explore 截图
- [ ] Uptime Kuma 状态页截图

## 🔧 故障排查

### Prometheus targets 宕机

```bash
# 检查网络连通性
docker network inspect monitoring

# 检查目标服务
docker logs <target-container>
```

### Grafana 无法连接数据源

```bash
# 检查数据源配置
cat config/grafana/provisioning/datasources/datasources.yml

# 重启 Grafana
docker compose restart grafana
```

### 告警未发送

```bash
# 检查 Alertmanager 配置
cat config/alertmanager/alertmanager.yml

# 查看 Alertmanager 日志
docker logs alertmanager
```

## 📊 数据保留策略

| 数据源 | 保留期 | 配置位置 |
|--------|--------|----------|
| Prometheus | 30 天 | `.env: PROMETHEUS_RETENTION` |
| Loki | 7 天 | `.env: LOKI_RETENTION` |
| Tempo | 3 天 | `.env: TEMPO_RETENTION` |

---

**文档版本**: 1.0  
**最后更新**: 2026-03-18  
**维护者**: 牛马 - 软件开发专家
